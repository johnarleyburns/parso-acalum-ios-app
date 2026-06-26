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
    var listenability: Listenability? = nil
}

/// Listenability answers "is this playable music for the default stream?" — kept
/// separate from `MoodMatch`/Fit, which answers "does this match the requested sound?".
struct Listenability: Codable, Equatable {
    let score: Double
    let tier: String
    let decision: String
    let stream: String
    var reasons: [String] = []
    var components: [String: Double] = [:]

    /// User-safe one-line summary, e.g. "Stream quality: excellent (0.88)".
    var qualitySummary: String {
        String(format: "Stream quality: %@ (%.2f)", tier, score)
    }
}

struct TrackExplanation: Codable, Equatable {
    let reasons: [String]
    let matchedPills: [String]
    let similarityScore: Double?
    let userTasteScore: Double?
    var matchedPhraseTerms: [String] = []
    var phraseMatchedVerbatim: Bool = false
}
