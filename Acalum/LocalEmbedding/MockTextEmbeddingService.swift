import Foundation

final class MockTextEmbeddingService: TextEmbeddingService {
    func embed(prompt: String, pills: [DiscoveryPill]) async throws -> Embedding512 {
        let queryText = QueryTextBuilder.buildQuery(prompt: prompt, pills: pills)
        let hash = Self.stableHash(queryText)
        var values = [Float](repeating: 0, count: Embedding512.dimension)
        var state = hash
        for i in 0..<Embedding512.dimension {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            values[i] = Float(Int32(truncatingIfNeeded: state >> 33)) / Float(Int32.max)
        }
        return try Embedding512(values: values).normalized()
    }

    private static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return hash
    }
}
