import Foundation

protocol QueueServiceProtocol {
    func generateQueue(context: DiscoveryContext) async -> [Track]
}

final class MockQueueService: QueueServiceProtocol {
    func generateQueue(context: DiscoveryContext) async -> [Track] {
        try? await Task.sleep(nanoseconds: 500_000_000)
        let tracks = MockData.tracks.shuffled()
        return tracks.map { track in
            var t = track
            if t.moodMatch == nil {
                t.moodMatch = MoodMatch(
                    index: Int.random(in: 20...85),
                    summary: "Mock recommendation",
                    components: [
                        MoodComponent(label: "Acoustic character", detail: "cosine 0.50", share: 50, matched: true)
                    ],
                    context: ["Fresh — not played in your last 300"]
                )
            }
            return t
        }
    }
}
