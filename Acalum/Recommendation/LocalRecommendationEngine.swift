import Foundation
import os

final class LocalRecommendationEngine: QueueServiceProtocol {
    private let catalog: [TrackVectorRecord]
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
        self.searchService = searchService
        self.tasteBuilder = tasteBuilder
        self.scorer = scorer
        self.planner = planner
        self.textEmbedding = textEmbedding
    }

    func generateQueue(context: DiscoveryContext) async -> [Track] {
        let query = await buildQueryVector(from: context)
        let favorites = Set(context.favoriteTrackIDs)
        let disliked = Set(context.dislikedTrackIDs)
        let seen = Set(context.recentlyPlayedTrackIDs)

        let k = SeenHistoryStore.capacity + planner.window + 50
        let hardExclude = disliked.union(favorites)

        let raw: [SearchResult]
        do {
            let searchResults = try await searchService.search(query: query, limit: k, excluding: hardExclude)
            if let offlineIDs = context.offlineTrackIDs {
                raw = searchResults.filter { offlineIDs.contains($0.track.id) }
            } else {
                raw = searchResults
            }
        } catch {
            return []
        }

        let scored = raw
            .map { scorer.score(record: $0.track, clap: $0.score, recentIDs: seen, pills: context.selectedPills) }
            .sorted { $0.moodMatch.index > $1.moodMatch.index }

        let planned = planner.plan(
            ranked: scored, seen: seen, disliked: disliked,
            refill: { [weak self] in self?.catalogFiller(query: query, exclude: hardExclude, pills: context.selectedPills) ?? [] })

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

    private func catalogFiller(query: Embedding512, exclude: Set<String>, pills: [Pill]) -> [ScoredTrack] {
        let q = query.normalized()
        return catalog.lazy
            .filter { !exclude.contains($0.id) }
            .prefix(SeenHistoryStore.capacity + planner.window)
            .map { scorer.score(record: $0, clap: q.dot($0.clapVector), recentIDs: [], pills: pills) }
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
                matchedPills: s.moodMatch.components.filter(\.matched).map(\.label),
                similarityScore: Double(s.moodMatch.index) / 100, userTasteScore: nil),
            moodMatch: s.moodMatch)
    }

    func buildQueryVector(from context: DiscoveryContext) async -> Embedding512 {
        if let prompt = context.prompt, !prompt.isEmpty,
           let embedding = try? await textEmbedding?.embed(prompt: prompt, pills: context.selectedPills) {
            return embedding
        }

        let profileFavorites = TasteProfileStore.favoriteTrackIDs
        let profileCompleted = TasteProfileStore.completedTrackIDs
        let profileSkipped = TasteProfileStore.skippedTrackIDs

        if !profileFavorites.isEmpty || !profileCompleted.isEmpty || !profileSkipped.isEmpty {
            let tasteVector = tasteBuilder.buildTasteVector(
                favoriteTrackIDs: profileFavorites,
                completedTrackIDs: profileCompleted,
                skippedTrackIDs: profileSkipped
            )
            if let tasteVector {
                TasteProfileStore.cacheTasteVector(tasteVector.values)
                return tasteVector
            }
        }

        if let cached = TasteProfileStore.cachedTasteVector(),
           let tasteVector = try? Embedding512(values: cached) {
            return tasteVector
        }

        if !context.selectedPills.isEmpty {
            let pillLabels = context.selectedPills.map { $0.label.lowercased() }
            let matched = catalog.filter { record in
                let title = record.title.lowercased()
                return pillLabels.contains(where: { title.contains($0) })
            }
            if let seed = matched.randomElement() {
                return seed.clapVector.normalized()
            }
        }

        if let seed = catalog.randomElement() {
            return seed.clapVector.normalized()
        }

        return .zero
    }
}
