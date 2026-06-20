import Foundation

struct SearchReranker {
    struct Weights {
        var clapSimilarity: Float = 0.80
        var metadataPillScore: Float = 0.10
        var noveltyScore: Float = 0.05
        var userTasteScore: Float = 0.05
    }

    let weights: Weights

    init(weights: Weights = Weights()) {
        self.weights = weights
    }

    func rerank(
        results: [SearchResult],
        selectedPills: [DiscoveryPill] = [],
        recentTrackIDs: Set<String> = [],
        favoriteTrackIDs: Set<String> = []
    ) -> [SearchResult] {
        var reranked = results.compactMap { result -> SearchResult? in
            guard !recentTrackIDs.contains(result.track.id) else { return nil }

            let clapScore = result.score
            let pillScore = computePillScore(record: result.track, pills: selectedPills)
            let novelty = computeNoveltyScore(record: result.track, recentIDs: recentTrackIDs)
            let taste = computeTasteScore(record: result.track, favoriteIDs: favoriteTrackIDs)

            let finalScore =
                weights.clapSimilarity * clapScore
                + weights.metadataPillScore * pillScore
                + weights.noveltyScore * novelty
                + weights.userTasteScore * taste

            var explanation = result.explanation
            if pillScore > 0 {
                explanation.append("Metadata matches selected pills")
            }
            if taste > 0 {
                explanation.append("Similar to your favorites")
            }

            return SearchResult(
                track: result.track,
                score: finalScore,
                explanation: explanation
            )
        }

        reranked.sort { $0.score > $1.score }
        return reranked
    }

    private func computePillScore(record: TrackVectorRecord, pills: [DiscoveryPill]) -> Float {
        guard !pills.isEmpty else { return 0 }
        let titleLower = record.title.lowercased()
        let composerLower = (record.composer ?? "").lowercased()
        let tags = record.tags ?? []

        var matches: Float = 0
        for pill in pills {
            let label = pill.label.lowercased()
            if titleLower.contains(label) || composerLower.contains(label) {
                matches += 1
                continue
            }
            if tags.contains(where: { $0.lowercased().contains(label) }) {
                matches += 1
            }
        }
        return min(matches / Float(pills.count), 1.0)
    }

    private func computeNoveltyScore(record: TrackVectorRecord, recentIDs: Set<String>) -> Float {
        // TODO: Implement richer novelty scoring (penalize same composer, canonical title, etc.)
        recentIDs.contains(record.id) ? 0.0 : 1.0
    }

    private func computeTasteScore(record: TrackVectorRecord, favoriteIDs: Set<String>) -> Float {
        // TODO: Compare track CLAP vector against taste vector built from favorites
        favoriteIDs.contains(record.id) ? 1.0 : 0.0
    }
}
