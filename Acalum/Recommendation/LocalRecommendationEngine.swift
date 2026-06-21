import Foundation

final class LocalRecommendationEngine: QueueServiceProtocol {
    private let catalog: [TrackVectorRecord]
    private let searchService: LocalVectorSearchService
    private let tasteBuilder: TasteVectorBuilder
    private let reranker: SearchReranker
    private let textEmbedding: TextEmbeddingService?

    private let searchLimit = 50

    init(
        catalog: [TrackVectorRecord],
        searchService: LocalVectorSearchService,
        tasteBuilder: TasteVectorBuilder,
        reranker: SearchReranker = SearchReranker(),
        textEmbedding: TextEmbeddingService? = nil
    ) {
        self.catalog = catalog
        self.searchService = searchService
        self.tasteBuilder = tasteBuilder
        self.reranker = reranker
        self.textEmbedding = textEmbedding
    }

    func generateQueue(context: DiscoveryContext) async -> [Track] {
        let queryVector = await buildQueryVector(from: context)

        let excludedIDs = Set(context.recentlyPlayedTrackIDs + context.dislikedTrackIDs)

        let results: [SearchResult]
        do {
            results = try await searchService.search(
                query: queryVector,
                limit: searchLimit,
                excluding: excludedIDs
            )
        } catch {
            return []
        }

        let reranked = reranker.rerank(
            results: results,
            selectedPills: context.selectedPills,
            recentTrackIDs: Set(context.recentlyPlayedTrackIDs),
            favoriteTrackIDs: Set(context.favoriteTrackIDs)
        )

        return reranked.map(mapToTrack)
    }

    private func buildQueryVector(from context: DiscoveryContext) async -> Embedding512 {
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

    private func mapToTrack(_ result: SearchResult) -> Track {
        let record = result.track
        return Track(
            id: record.id,
            title: record.title,
            composer: record.composer,
            performer: record.performer,
            sourceName: "Internet Archive",
            sourceURL: record.sourceURL,
            audioURL: record.audioURL ?? URL(string: "https://archive.org")!,
            durationSeconds: record.durationSeconds ?? 0,
            artworkURL: record.artURL,
            license: "Public Domain",
            year: nil,
            explanation: TrackExplanation(
                reasons: result.explanation,
                matchedPills: [],
                similarityScore: Double(result.score),
                userTasteScore: nil
            )
        )
    }
}
