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

    mutating func jumpTo(index: Int) -> Track? {
        guard upcoming.indices.contains(index) else { return nil }
        if let current = current {
            history.append(current)
        }
        history.append(contentsOf: upcoming[0..<index])
        current = upcoming[index]
        upcoming.removeSubrange(0...index)
        return current
    }

    mutating func appendTracks(_ tracks: [Track]) {
        let existingIDs = Set(upcoming.map(\.id) + [current?.id].compactMap { $0 })
        let newTracks = tracks.filter { !existingIDs.contains($0.id) }
        upcoming.append(contentsOf: newTracks)
    }

    mutating func replaceUpcoming(_ tracks: [Track]) {
        upcoming = tracks
    }

    mutating func trimUpcoming(to count: Int) {
        upcoming = Array(upcoming.prefix(count))
    }

    func containsTrack(id: String) -> Bool {
        current?.id == id || upcoming.contains(where: { $0.id == id })
    }

    var isEmpty: Bool {
        current == nil && upcoming.isEmpty
    }

    var upcomingCount: Int {
        upcoming.count
    }
}
