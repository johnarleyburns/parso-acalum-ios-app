import Foundation

protocol LocalVectorSearchService {
    func search(
        query: Embedding512,
        limit: Int,
        excluding excludedTrackIDs: Set<String>
    ) async throws -> [SearchResult]
}
