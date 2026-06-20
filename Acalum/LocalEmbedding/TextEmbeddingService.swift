import Foundation

protocol TextEmbeddingService {
    func embed(prompt: String, pills: [DiscoveryPill]) async throws -> Embedding512
}
