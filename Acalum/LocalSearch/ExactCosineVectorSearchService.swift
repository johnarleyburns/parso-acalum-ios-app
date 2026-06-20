import Foundation

final class ExactCosineVectorSearchService: LocalVectorSearchService {
    private let catalog: [TrackVectorRecord]

    init(catalog: [TrackVectorRecord]) {
        self.catalog = catalog
    }

    func search(
        query: Embedding512,
        limit: Int,
        excluding excludedTrackIDs: Set<String>
    ) async throws -> [SearchResult] {
        let normalizedQuery = query.normalized()

        var scored: [(record: TrackVectorRecord, score: Float)] = []
        scored.reserveCapacity(catalog.count)

        for record in catalog {
            guard !excludedTrackIDs.contains(record.id) else { continue }
            let score = normalizedQuery.dot(record.clapVector)
            scored.append((record, score))
        }

        scored.sort { $0.score > $1.score }

        let topN = scored.prefix(limit)
        return topN.map { item in
            SearchResult(
                track: item.record,
                score: item.score,
                explanation: buildExplanation(score: item.score, record: item.record)
            )
        }
    }

    private func buildExplanation(score: Float, record: TrackVectorRecord) -> [String] {
        var reasons: [String] = []
        if score >= 0.5 {
            reasons.append("Strong CLAP similarity (\(String(format: "%.2f", score)))")
        } else if score >= 0.3 {
            reasons.append("Moderate CLAP similarity (\(String(format: "%.2f", score)))")
        } else {
            reasons.append("CLAP similarity \(String(format: "%.2f", score))")
        }
        if let composer = record.composer, !composer.isEmpty {
            reasons.append("Composer: \(composer)")
        }
        return reasons
    }
}
