import Foundation

enum FeedbackEventType: String, Codable {
    case playStarted
    case playCompleted
    case skipped
    case favorited
    case unfavorited
    case replayed
    case promptChanged
    case pillSelected
    case pillRemoved
}

struct FeedbackEvent: Codable, Identifiable {
    let id: UUID
    let sessionID: String
    let trackID: String?
    let type: FeedbackEventType
    let timestamp: Date
    let listenSeconds: Double?
    let prompt: String?
    let selectedPillIDs: [String]
}
