import Foundation

/// Persistent back-stack of previously listened tracks, powering the Previous
/// control. Survives app restarts. Most-recent track is at the front (index 0).
enum PlaybackHistoryStore {
    static let capacity = 50
    private static let key = "acalum_previous_history"

    static func loadPreviousTracks() -> [Track] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let tracks = try? JSONDecoder().decode([Track].self, from: data) else {
            return []
        }
        return tracks
    }

    static func savePreviousTracks(_ tracks: [Track]) {
        let trimmed = Array(tracks.prefix(capacity))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Pushes a track to the front of the history, de-duplicating and capping depth.
    static func push(_ track: Track) {
        var tracks = loadPreviousTracks()
        tracks.removeAll { $0.id == track.id }
        tracks.insert(track, at: 0)
        savePreviousTracks(tracks)
    }

    /// Removes and returns the most recent previous track, if any.
    static func pop() -> Track? {
        var tracks = loadPreviousTracks()
        guard !tracks.isEmpty else { return nil }
        let track = tracks.removeFirst()
        savePreviousTracks(tracks)
        return track
    }

    static func peek() -> Track? {
        loadPreviousTracks().first
    }

    static var isEmpty: Bool {
        loadPreviousTracks().isEmpty
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
