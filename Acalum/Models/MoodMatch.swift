import Foundation

struct MoodComponent: Codable, Equatable, Identifiable {
    var id: String { label }
    let label: String
    let detail: String
    let share: Int
    let matched: Bool
}

struct MoodMatch: Codable, Equatable {
    let index: Int
    let summary: String
    let components: [MoodComponent]
    let context: [String]
    var matchedPhraseTerms: [String] = []
    var phraseMatchedVerbatim: Bool = false
}
