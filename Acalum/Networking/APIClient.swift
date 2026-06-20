import Foundation

protocol APIClientProtocol {
    func generateQueue(request: GenerateQueueRequest) async throws -> [Track]
}

final class APIClient: APIClientProtocol {
    private let baseURL: URL

    init(baseURL: URL = URL(string: "https://api.example.com/v1")!) {
        self.baseURL = baseURL
    }

    func generateQueue(request: GenerateQueueRequest) async throws -> [Track] {
        // Stub: will be implemented in Phase 2
        return MockData.tracks.shuffled()
    }
}
