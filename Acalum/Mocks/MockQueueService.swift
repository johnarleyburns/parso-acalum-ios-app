import Foundation

protocol QueueServiceProtocol {
    func generateQueue(context: DiscoveryContext) async -> [Track]
}

final class MockQueueService: QueueServiceProtocol {
    func generateQueue(context: DiscoveryContext) async -> [Track] {
        try? await Task.sleep(nanoseconds: 500_000_000)
        return MockData.tracks.shuffled()
    }
}
