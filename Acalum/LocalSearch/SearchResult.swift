import Foundation

struct SearchResult: Identifiable {
    let track: TrackVectorRecord
    let score: Float
    let explanation: [String]

    var id: String { track.id }
}
