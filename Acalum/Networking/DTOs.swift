import Foundation

struct GenerateQueueRequest: Codable {
    let sessionID: String
    let prompt: String?
    let selectedPills: [String]
    let recentTrackIDs: [String]
    let favoriteTrackIDs: [String]
    let skipTrackIDs: [String]
    let limit: Int
}

struct GenerateQueueResponse: Codable {
    let tracks: [TrackDTO]
}

struct TrackDTO: Codable {
    let id: String
    let title: String
    let composer: String?
    let performer: String?
    let audioURL: URL
    let durationSeconds: Double
    let sourceName: String
    let sourceURL: URL?
    let license: String?
    let year: Int?
    let explanation: TrackExplanationDTO?

    enum CodingKeys: String, CodingKey {
        case id, title, composer, performer
        case audioURL = "audio_url"
        case durationSeconds = "duration_seconds"
        case sourceName = "source_name"
        case sourceURL = "source_url"
        case license, year, explanation
    }

    func toTrack() -> Track {
        Track(
            id: id,
            title: title,
            composer: composer,
            performer: performer,
            sourceName: sourceName,
            sourceURL: sourceURL,
            audioURL: audioURL,
            durationSeconds: durationSeconds,
            license: license,
            year: year,
            explanation: explanation?.toExplanation()
        )
    }
}

struct TrackExplanationDTO: Codable {
    let reasons: [String]
    let matchedPills: [String]
    let similarityScore: Double?
    let userTasteScore: Double?

    enum CodingKeys: String, CodingKey {
        case reasons
        case matchedPills = "matched_pills"
        case similarityScore = "similarity_score"
        case userTasteScore = "user_taste_score"
    }

    func toExplanation() -> TrackExplanation {
        TrackExplanation(
            reasons: reasons,
            matchedPills: matchedPills,
            similarityScore: similarityScore,
            userTasteScore: userTasteScore
        )
    }
}
