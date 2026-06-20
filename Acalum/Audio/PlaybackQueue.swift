import Foundation

struct PlaybackQueue {
    var current: Track?
    var upcoming: [Track]
    var history: [Track]

    init(tracks: [Track] = []) {
        if tracks.isEmpty {
            current = nil
            upcoming = []
        } else {
            current = tracks.first
            upcoming = Array(tracks.dropFirst())
        }
        history = []
    }

    mutating func skipToNext() -> Track? {
        if let current = current {
            history.append(current)
        }
        if upcoming.isEmpty {
            current = nil
            return nil
        }
        current = upcoming.removeFirst()
        return current
    }

    mutating func appendTracks(_ tracks: [Track]) {
        let existingIDs = Set(upcoming.map(\.id) + [current?.id].compactMap { $0 })
        let newTracks = tracks.filter { !existingIDs.contains($0.id) }
        upcoming.append(contentsOf: newTracks)
    }

    var isEmpty: Bool {
        current == nil && upcoming.isEmpty
    }

    var upcomingCount: Int {
        upcoming.count
    }
}
