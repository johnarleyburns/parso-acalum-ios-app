import Foundation

extension Notification.Name {
    static let acalumFavoritesChanged = Notification.Name("acalumFavoritesChanged")
}

final class LocalStore {
    private static let favoritesKey = "acalum_favorites"
    private static let lastPromptKey = "acalum_last_prompt"
    private static let lastPillsKey = "acalum_last_pills"

    static func loadFavorites() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        return Set(array)
    }

    static func saveFavorites(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: favoritesKey)
        NotificationCenter.default.post(name: .acalumFavoritesChanged, object: nil)
    }

    static func loadLastPrompt() -> String? {
        UserDefaults.standard.string(forKey: lastPromptKey)
    }

    static func saveLastPrompt(_ prompt: String?) {
        UserDefaults.standard.set(prompt, forKey: lastPromptKey)
    }

    static func loadLastPillIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: lastPillsKey) ?? []
    }

    static func saveLastPillIDs(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: lastPillsKey)
    }
}
