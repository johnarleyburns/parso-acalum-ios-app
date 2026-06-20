import Foundation

final class SessionStore {
    private static let sessionIDKey = "acalum_session_id"

    static var sessionID: String {
        if let existing = UserDefaults.standard.string(forKey: sessionIDKey) {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: sessionIDKey)
        return id
    }
}
