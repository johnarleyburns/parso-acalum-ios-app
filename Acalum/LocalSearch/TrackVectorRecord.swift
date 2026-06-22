import Foundation

struct TrackVectorRecord: Identifiable, Equatable {
    let id: String
    let title: String
    let composer: String?
    let performer: String?
    let clapVector: Embedding512
    let tags: [String]?
    let albumTitle: String?
    let albumSubjects: String?
    let albumGenres: String?
    let durationSeconds: Double?
    let sourceURL: URL?
    let audioURL: URL?
    let artURL: URL?
}
