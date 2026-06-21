import Foundation

final class TasteVectorBuilder {
    private let catalog: [TrackVectorRecord]

    init(catalog: [TrackVectorRecord]) {
        self.catalog = catalog
    }

    func buildTasteVector(
        favoriteTrackIDs: [String],
        completedTrackIDs: [String],
        skippedTrackIDs: [String]
    ) -> Embedding512? {
        let favoritedVectors = vectors(for: favoriteTrackIDs)
        let completedVectors = vectors(for: completedTrackIDs)
        let skippedVectors = vectors(for: skippedTrackIDs)

        guard !favoritedVectors.isEmpty || !completedVectors.isEmpty || !skippedVectors.isEmpty else {
            return nil
        }

        let favoritedAvg = average(favoritedVectors)
        let completedAvg = average(completedVectors)
        let skippedAvg = average(skippedVectors)

        var components: [Float] = []
        for i in 0..<Embedding512.dimension {
            let value = 3.0 * favoritedAvg[i] + 1.5 * completedAvg[i] - 1.5 * skippedAvg[i]
            components.append(value)
        }

        return (try? Embedding512(values: components))?.normalized()
    }

    private func vectors(for trackIDs: [String]) -> [[Float]] {
        let idSet = Set(trackIDs)
        return catalog
            .filter { idSet.contains($0.id) }
            .map { $0.clapVector.values }
    }

    private func average(_ vectors: [[Float]]) -> [Float] {
        guard !vectors.isEmpty else {
            return [Float](repeating: 0, count: Embedding512.dimension)
        }
        var sum = [Float](repeating: 0, count: Embedding512.dimension)
        for vec in vectors {
            for i in 0..<Embedding512.dimension {
                sum[i] += vec[i]
            }
        }
        let count = Float(vectors.count)
        return sum.map { $0 / count }
    }
}
