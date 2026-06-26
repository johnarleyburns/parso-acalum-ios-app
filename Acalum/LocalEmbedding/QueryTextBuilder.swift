import Foundation

enum QueryTextBuilder {
    static func buildQuery(prompt: String, pills: [DiscoveryPill]) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        let phrases = pills.compactMap { pill -> String? in
            let phrase = pill.embeddingPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
            return phrase.isEmpty ? pill.label.lowercased() : phrase
        }
        let qualities = phrases.joined(separator: ", ")

        if trimmed.isEmpty && qualities.isEmpty {
            return "public domain music"
        }

        if trimmed.isEmpty {
            return "public domain music. Music qualities: \(qualities)."
        }

        if qualities.isEmpty {
            return trimmed
        }

        let base = trimmed.hasSuffix(".") ? String(trimmed.dropLast()) : trimmed
        return "\(base). Music qualities: \(qualities)."
    }
}
