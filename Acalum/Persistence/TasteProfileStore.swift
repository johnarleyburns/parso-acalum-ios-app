import Foundation

final class TasteProfileStore {
    private static let favoritesKey = "acalum_taste_favorites"
    private static let completedKey = "acalum_taste_completed"
    private static let skippedKey = "acalum_taste_skipped"
    private static let tasteVectorKey = "acalum_cached_taste_vector"
    private static let maxTrackIDs = 500

    static var favoriteTrackIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: favoritesKey) ?? [] }
        set { UserDefaults.standard.set(Array(newValue.suffix(maxTrackIDs)), forKey: favoritesKey) }
    }

    static var completedTrackIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: completedKey) ?? [] }
        set { UserDefaults.standard.set(Array(newValue.suffix(maxTrackIDs)), forKey: completedKey) }
    }

    static var skippedTrackIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: skippedKey) ?? [] }
        set { UserDefaults.standard.set(Array(newValue.suffix(maxTrackIDs)), forKey: skippedKey) }
    }

    static func recordFavorite(_ trackID: String) {
        var ids = favoriteTrackIDs
        ids.removeAll { $0 == trackID }
        ids.insert(trackID, at: 0)
        favoriteTrackIDs = Array(ids.suffix(maxTrackIDs))
    }

    static func removeFavorite(_ trackID: String) {
        var ids = favoriteTrackIDs
        ids.removeAll { $0 == trackID }
        favoriteTrackIDs = ids
    }

    static func recordCompleted(_ trackID: String) {
        var ids = completedTrackIDs
        ids.removeAll { $0 == trackID }
        ids.insert(trackID, at: 0)
        completedTrackIDs = Array(ids.suffix(maxTrackIDs))
    }

    static func recordSkipped(_ trackID: String, listenSeconds: Double? = nil) {
        var ids = skippedTrackIDs
        ids.removeAll { $0 == trackID }
        ids.insert(trackID, at: 0)
        skippedTrackIDs = Array(ids.suffix(maxTrackIDs))
    }

    static func cachedTasteVector() -> [Float]? {
        guard let data = UserDefaults.standard.data(forKey: tasteVectorKey),
              let vector = try? JSONDecoder().decode([Float].self, from: data) else {
            return nil
        }
        return vector
    }

    static func cacheTasteVector(_ values: [Float]) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(data, forKey: tasteVectorKey)
    }

    static func clearTasteVectorCache() {
        UserDefaults.standard.removeObject(forKey: tasteVectorKey)
    }
}
