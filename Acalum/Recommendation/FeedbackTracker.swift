import Foundation

final class FeedbackTracker {
    private let sessionID: String

    init(sessionID: String = SessionStore.sessionID) {
        self.sessionID = sessionID
    }

    func log(
        type: FeedbackEventType,
        trackID: String? = nil,
        listenSeconds: Double? = nil,
        prompt: String? = nil,
        selectedPillIDs: [String] = []
    ) {
        let event = FeedbackEvent(
            id: UUID(),
            sessionID: sessionID,
            trackID: trackID,
            type: type,
            timestamp: Date(),
            listenSeconds: listenSeconds,
            prompt: prompt,
            selectedPillIDs: selectedPillIDs
        )
        FeedbackEventStore.appendEvent(event)
    }
}
