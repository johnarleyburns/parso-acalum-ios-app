import Foundation

enum SeenHistoryStore {
    private static let key = "acalum_seen_history"
    static let minRotation = 50
    static var capacity = max(minRotation, 300)

    static var recentIDs: [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }

    static func record(_ trackID: String) {
        var ids = recentIDs
        ids.removeAll { $0 == trackID }
        ids.insert(trackID, at: 0)
        if ids.count > capacity { ids = Array(ids.prefix(capacity)) }
        UserDefaults.standard.set(ids, forKey: key)
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
