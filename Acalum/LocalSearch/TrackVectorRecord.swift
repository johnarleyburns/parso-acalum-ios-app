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

    // Listenability (indexer listenability-v1). Optional so old DBs without the
    // columns still load. See LocalDatabase for the schema-detection fallback.
    let listenabilityScore: Double?
    let listenabilityTier: String?
    let listenabilityDecision: String?
    let listenabilityStream: String?
    let listenabilityReasons: [String]
    let listenabilityComponents: [String: Double]

    init(
        id: String,
        title: String,
        composer: String?,
        performer: String?,
        clapVector: Embedding512,
        tags: [String]?,
        albumTitle: String?,
        albumSubjects: String?,
        albumGenres: String?,
        durationSeconds: Double?,
        sourceURL: URL?,
        audioURL: URL?,
        artURL: URL?,
        listenabilityScore: Double? = nil,
        listenabilityTier: String? = nil,
        listenabilityDecision: String? = nil,
        listenabilityStream: String? = nil,
        listenabilityReasons: [String] = [],
        listenabilityComponents: [String: Double] = [:]
    ) {
        self.id = id
        self.title = title
        self.composer = composer
        self.performer = performer
        self.clapVector = clapVector
        self.tags = tags
        self.albumTitle = albumTitle
        self.albumSubjects = albumSubjects
        self.albumGenres = albumGenres
        self.durationSeconds = durationSeconds
        self.sourceURL = sourceURL
        self.audioURL = audioURL
        self.artURL = artURL
        self.listenabilityScore = listenabilityScore
        self.listenabilityTier = listenabilityTier
        self.listenabilityDecision = listenabilityDecision
        self.listenabilityStream = listenabilityStream
        self.listenabilityReasons = listenabilityReasons
        self.listenabilityComponents = listenabilityComponents
    }
}
