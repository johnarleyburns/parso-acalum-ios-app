import Foundation

struct Track: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let composer: String?
    let performer: String?
    let sourceName: String
    let sourceURL: URL?
    let audioURL: URL
    let durationSeconds: Double
    let artworkURL: URL?
    let license: String?
    let year: Int?
    let explanation: TrackExplanation?
    var moodMatch: MoodMatch? = nil
}

struct TrackExplanation: Codable, Equatable {
    let reasons: [String]
    let matchedPills: [String]
    let similarityScore: Double?
    let userTasteScore: Double?
    var matchedPhraseTerms: [String] = []
    var phraseMatchedVerbatim: Bool = false
}
