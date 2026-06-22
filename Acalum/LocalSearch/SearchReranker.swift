import Foundation

struct SearchReranker {
    struct Weights {
        var clapSimilarity: Float = 0.50
        var metadataPillScore: Float = 0.35
        var noveltyScore: Float = 0.10
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
        favoriteTrackIDs: Set<String> = [],
        tasteVector: Embedding512? = nil,
        shuffleTopN: Int = 0
    ) -> [SearchResult] {
        var reranked = results.compactMap { result -> SearchResult? in
            guard !recentTrackIDs.contains(result.track.id) else { return nil }

            let clapScore = result.score
            let pillScore = computePillScore(record: result.track, pills: selectedPills)
            let novelty = computeNoveltyScore(record: result.track, recentIDs: recentTrackIDs)
            let taste = computeTasteScore(record: result.track, tasteVector: tasteVector)

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

        if shuffleTopN > 1, reranked.count > shuffleTopN {
            let topN = reranked.prefix(shuffleTopN).shuffled()
            let rest = reranked.suffix(from: shuffleTopN)
            reranked = Array(topN) + Array(rest)
        }

        return reranked
    }

    private func computePillScore(record: TrackVectorRecord, pills: [DiscoveryPill]) -> Float {
        guard !pills.isEmpty else { return 0 }

        let titleLower = record.title.lowercased()
        let composerLower = (record.composer ?? "").lowercased()
        let tags = (record.tags ?? []).map { $0.lowercased() }
        let albumTitleLower = (record.albumTitle ?? "").lowercased()
        let albumSubjectsLower = (record.albumSubjects ?? "").lowercased()
        let albumGenresLower = (record.albumGenres ?? "").lowercased()
        let searchableText = "\(titleLower) \(composerLower) \(tags.joined(separator: " ")) \(albumTitleLower) \(albumSubjectsLower) \(albumGenresLower)"

        let stopWords: Set<String> = ["", ",", "and", "the", "of", "in", "for", "a", "an", "to", "with", "or", "is", "it", "on", "at", "by", "as", "be", "no", "not", "but"]

        var wordHits = 0
        var wordCount = 0

        for pill in pills {
            let phrase = pill.semanticPhrase.isEmpty ? pill.label : pill.semanticPhrase
            let words = phrase.lowercased()
                .components(separatedBy: CharacterSet(charactersIn: " ,;"))
                .filter { !stopWords.contains($0) }

            for word in words {
                wordCount += 1
                if searchableText.contains(word) {
                    wordHits += 1
                }
            }
        }

        guard wordCount > 0 else { return 0 }
        return Float(wordHits) / Float(wordCount)
    }

    private func computeNoveltyScore(record: TrackVectorRecord, recentIDs: Set<String>) -> Float {
        // TODO: Implement richer novelty scoring (penalize same composer, canonical title, etc.)
        recentIDs.contains(record.id) ? 0.0 : 1.0
    }

    private func computeTasteScore(record: TrackVectorRecord, tasteVector: Embedding512?) -> Float {
        guard let tasteVector else { return 0 }
        let similarity = record.clapVector.cosineSimilarity(to: tasteVector)
        let clamped = max(-1, min(1, similarity))
        return (clamped + 1.0) / 2.0
    }
}
