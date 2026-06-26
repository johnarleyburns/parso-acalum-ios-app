import Foundation
import os

final class LocalRecommendationEngine: QueueServiceProtocol {
    private let catalog: [TrackVectorRecord]
    private let catalogByID: [String: TrackVectorRecord]
    private let lexicalIndex: LexicalIndex
    private let searchService: LocalVectorSearchService
    private let tasteBuilder: TasteVectorBuilder
    private let scorer: MoodMatchScorer
    private let planner: RotationPlanner
    private let textEmbedding: TextEmbeddingService?

    init(
        catalog: [TrackVectorRecord],
        searchService: LocalVectorSearchService,
        tasteBuilder: TasteVectorBuilder,
        scorer: MoodMatchScorer = MoodMatchScorer(),
        planner: RotationPlanner = RotationPlanner(),
        textEmbedding: TextEmbeddingService? = nil
    ) {
        self.catalog = catalog
        var byID: [String: TrackVectorRecord] = [:]
        byID.reserveCapacity(catalog.count)
        for record in catalog { byID[record.id] = record }
        self.catalogByID = byID
        self.lexicalIndex = LexicalIndex(catalog: catalog)
        self.searchService = searchService
        self.tasteBuilder = tasteBuilder
        self.scorer = scorer
        self.planner = planner
        self.textEmbedding = textEmbedding
    }

    func generateQueue(context: DiscoveryContext) async -> [Track] {
        let query = await buildQueryVector(from: context)
        var normalizedQuery = query.normalized()
        let favorites = Set(context.favoriteTrackIDs)
        let disliked = Set(context.dislikedTrackIDs)
        let seen = Set(context.recentlyPlayedTrackIDs)

        let hasMood = !context.selectedPills.isEmpty || !(context.prompt ?? "").isEmpty

        if let seedID = context.similarToTrackID,
           let seedRecord = catalogByID[seedID] {
            let seedVector = seedRecord.clapVector.normalized()
            if hasMood {
                normalizedQuery = normalizedQuery.weightedAdding(seedVector, selfWeight: 0.65, otherWeight: 0.35).normalized()
            } else {
                normalizedQuery = seedVector
            }
        }

        let k = SeenHistoryStore.capacity + planner.window + 50
        let exclude = disliked

        // Query terms drawn from explicit intent (prompt + pills). Pills contribute
        // their strict metadata terms and label — not the generic embedding phrase —
        // so words like "music" or "background" don't pollute lexical retrieval.
        let phrase = (context.prompt ?? "").lowercased()
        let pillText = context.selectedPills
            .map { ($0.metadataTerms + [$0.label]).joined(separator: " ") }
            .joined(separator: " ")
        let queryTerms = LexicalIndex.terms("\(phrase) \(pillText)")
        let lexical = lexicalIndex.scores(queryTerms: queryTerms, phrase: phrase) // id -> [0,1]

        // CLAP top-k. Degrade to the lexical channel if the search throws.
        var clapByID: [String: Float] = [:]
        do {
            let vectorHits = try await searchService.search(query: query, limit: k, excluding: exclude)
            clapByID = Dictionary(vectorHits.map { ($0.track.id, $0.score) }, uniquingKeysWith: { a, _ in a })
        } catch {
            clapByID = [:]
        }

        // Candidate union: everything CLAP surfaced + everything lexically matched.
        let candidateIDs = Set(clapByID.keys).union(lexical.keys).subtracting(exclude)
        struct Cand { let rec: TrackVectorRecord; let clap: Float; let lex: Float; let fused: Float }
        var cands: [Cand] = candidateIDs.compactMap { id in
            guard let rec = catalogByID[id] else { return nil }
            let clap = clapByID[id] ?? normalizedQuery.dot(rec.clapVector) // compute for lexical-only hits
            let lex  = lexical[id] ?? 0
            let fused = lexical.isEmpty ? clap : 0.5 * clap + 0.5 * lex
            return Cand(rec: rec, clap: clap, lex: lex, fused: fused)
        }
        cands.sort { $0.fused > $1.fused }
        cands = Array(cands.prefix(k))

        if let offlineIDs = context.offlineTrackIDs {
            cands = cands.filter { offlineIDs.contains($0.rec.id) }
        }

        // Score with the TRUE clap cosine so the Fit index keeps its calibrated meaning,
        // then order the final queue by a blend of Fit, lexical match, and listenability.
        // Listenability is a ranking nudge only — it never enters the displayed Fit index.
        let hasExplicitIntent = hasMood || context.similarToTrackID != nil
        // Promptless/taste-only mode leans a little more on listenability as a tie-break.
        let wFit: Float = hasExplicitIntent ? 0.50 : 0.45
        let wLex: Float = hasExplicitIntent ? 0.30 : 0.25
        let wListen: Float = hasExplicitIntent ? 0.20 : 0.30
        let lexByID = Dictionary(cands.map { ($0.rec.id, $0.lex) }, uniquingKeysWith: { a, _ in a })
        func orderingScore(_ s: ScoredTrack) -> Float {
            let fit = Float(s.moodMatch.index) / 100
            let lex = lexByID[s.record.id] ?? 0
            let listen = Float(s.record.listenabilityScore ?? 0.50)
            return wFit * fit + wLex * lex + wListen * listen
        }
        let scored = cands
            .map { scorer.score(record: $0.rec, clap: $0.clap, recentIDs: seen, pills: context.selectedPills, prompt: context.prompt ?? "") }
            .sorted { orderingScore($0) > orderingScore($1) }

        let planned = planner.plan(
            ranked: scored, seen: seen, disliked: disliked,
            refill: { [weak self] in self?.catalogFiller(query: query, exclude: exclude, pills: context.selectedPills, prompt: context.prompt ?? "") ?? [] })

        var tracks = planned.map(mapToTrack)
        injectFavoriteRarely(&tracks, favorites: favorites)

        if !planned.isEmpty {
            let top = planned.prefix(3)
            for (i, st) in top.enumerated() {
                os_log(.info, "Recommendation: #%d \"%@\" by %@ index=%d summary=%@",
                       i + 1, st.record.title, st.record.composer ?? "?",
                       st.moodMatch.index, st.moodMatch.summary)
            }
        }

        return tracks
    }

    private let favoriteInjectChance = 0.04

    private func injectFavoriteRarely(_ tracks: inout [Track], favorites: Set<String>) {
        guard !favorites.isEmpty, Double.random(in: 0..<1) < favoriteInjectChance,
              let rec = catalog.filter({ favorites.contains($0.id) }).randomElement() else { return }
        let mm = MoodMatch(index: 0, summary: "Resurfaced from your favorites",
                           components: [], context: ["From your favorites"])
        let st = ScoredTrack(record: rec, moodMatch: mm)
        tracks.insert(mapToTrack(st), at: min(2, tracks.count))
    }

    private func catalogFiller(query: Embedding512, exclude: Set<String>, pills: [Pill], prompt: String) -> [ScoredTrack] {
        let q = query.normalized()
        return catalog.lazy
            .filter { !exclude.contains($0.id) }
            .prefix(SeenHistoryStore.capacity + planner.window)
            .map { scorer.score(record: $0, clap: q.dot($0.clapVector), recentIDs: [], pills: pills, prompt: prompt) }
    }

    private func mapToTrack(_ s: ScoredTrack) -> Track {
        let r = s.record
        return Track(
            id: r.id, title: r.title, composer: r.composer, performer: r.performer,
            sourceName: "Internet Archive", sourceURL: r.sourceURL,
            audioURL: r.audioURL ?? URL(string: "https://archive.org")!,
            durationSeconds: r.durationSeconds ?? 0, artworkURL: r.artURL,
            license: "Public Domain", year: nil,
            explanation: TrackExplanation(
                reasons: s.moodMatch.components.map(\.label),
                matchedPills: s.moodMatch.components
                    .filter { $0.matched && $0.label != MoodMatchScorer.acousticLabel }
                    .map(\.label),
                similarityScore: Double(s.moodMatch.index) / 100, userTasteScore: nil,
                matchedPhraseTerms: s.moodMatch.matchedPhraseTerms,
                phraseMatchedVerbatim: s.moodMatch.phraseMatchedVerbatim),
            moodMatch: s.moodMatch,
            listenability: Self.listenability(from: r))
    }

    private static func listenability(from r: TrackVectorRecord) -> Listenability? {
        guard let score = r.listenabilityScore else { return nil }
        return Listenability(
            score: score,
            tier: r.listenabilityTier ?? "unknown",
            decision: r.listenabilityDecision ?? "include",
            stream: r.listenabilityStream ?? "default",
            reasons: r.listenabilityReasons,
            components: r.listenabilityComponents)
    }

    func buildQueryVector(from context: DiscoveryContext) async -> Embedding512 {
        let hasPrompt = !(context.prompt ?? "").isEmpty
        let hasPills  = !context.selectedPills.isEmpty

        // 1. Any explicit intent → embed it. QueryTextBuilder already turns pills into text
        //    even when the prompt is empty, so pill-only selections get a real query vector.
        if hasPrompt || hasPills,
           let embedding = try? await textEmbedding?.embed(prompt: context.prompt ?? "", pills: context.selectedPills) {
            return embedding
        }
        // 2. Only fall back to taste when the user expressed NO explicit intent.
        if !hasPrompt && !hasPills {
            if let taste = currentTasteVector() { return taste }
        }
        // 3. Neutral seed. With the hybrid lexical channel, the explicit query is still
        //    carried even when this vector is weak, so a missing model is never random.
        return catalog.randomElement()?.clapVector.normalized() ?? .zero
    }

    private func currentTasteVector() -> Embedding512? {
        let profileFavorites = TasteProfileStore.favoriteTrackIDs
        let profileCompleted = TasteProfileStore.completedTrackIDs
        let profileSkipped = TasteProfileStore.skippedTrackIDs

        if !profileFavorites.isEmpty || !profileCompleted.isEmpty || !profileSkipped.isEmpty {
            if let tasteVector = tasteBuilder.buildTasteVector(
                favoriteTrackIDs: profileFavorites,
                completedTrackIDs: profileCompleted,
                skippedTrackIDs: profileSkipped
            ) {
                TasteProfileStore.cacheTasteVector(tasteVector.values)
                return tasteVector
            }
        }

        if let cached = TasteProfileStore.cachedTasteVector(),
           let tasteVector = try? Embedding512(values: cached) {
            return tasteVector
        }

        return nil
    }
}
