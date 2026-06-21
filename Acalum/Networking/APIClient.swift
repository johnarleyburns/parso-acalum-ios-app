import Foundation

protocol APIClientProtocol {
    func generateQueue(request: GenerateQueueRequest) async throws -> [Track]
    func sendEvents(request: EventsRequest) async throws -> EventsResponse
}

final class APIClient: APIClientProtocol {
    private let baseURL: URL

    init(baseURL: URL = URL(string: "https://api.example.com/v1")!) {
        self.baseURL = baseURL
    }

    func generateQueue(request: GenerateQueueRequest) async throws -> [Track] {
        // Stub: will be implemented when backend is available
        return MockData.tracks.shuffled()
    }

    func sendEvents(request: EventsRequest) async throws -> EventsResponse {
        let url = baseURL.appendingPathComponent("events")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(EventsResponse.self, from: data)
    }
}
