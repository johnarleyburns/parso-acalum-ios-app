import Foundation

struct ScoredTrack {
    let record: TrackVectorRecord
    let moodMatch: MoodMatch
    var id: String { record.id }
}

struct MoodMatchScorer {
    static let acousticLabel = "Acoustic character"

    var clapWeight: Float = 0.62
    var tagWeight: Float = 0.38
    let calibrator: MoodIndexCalibrator

    private let stop: Set<String> = ["", ",", "and", "the", "of", "in", "for", "a", "an", "to", "with", "or", "is", "it", "on", "at", "by", "as", "be", "no", "not", "but"]

    init(calibrator: MoodIndexCalibrator = MoodIndexCalibrator()) {
        self.calibrator = calibrator
    }

    func score(record: TrackVectorRecord, clap: Float, recentIDs: Set<String>, pills: [Pill], prompt: String = "") -> ScoredTrack {
        let text = searchable(record)
        var components: [MoodComponent] = []

        // Only metadata-capable pills can assert a literal "tag present" match and
        // contribute to the tag ratio. Listening-mode pills shape direction via CLAP
        // but never claim a metadata match.
        let metadataPills = pills.filter(\.hasMetadataTerms)
        var matchedMetadata = 0

        for pill in pills {
            let detail: String
            let hit: Bool
            if pill.hasMetadataTerms {
                hit = pillMatched(pill, in: text)
                if hit { matchedMetadata += 1 }
                detail = hit ? "tag present" : "not tagged"
            } else {
                hit = false
                detail = "shapes direction"
            }
            components.append(MoodComponent(
                label: "\(pill.category.displayName): \(pill.label)",
                detail: detail,
                share: hit ? 100 : 0,
                matched: hit))
        }

        let raw: Float
        if metadataPills.isEmpty {
            raw = clamp01(clap)
        } else {
            let tagRatio = Float(matchedMetadata) / Float(metadataPills.count)
            raw = clamp01(clapWeight * clamp01(clap) * max(tagRatio, 0.15) + tagWeight * tagRatio)
        }
        let index = calibrator.index(raw)

        let acoustic = MoodComponent(
            label: Self.acousticLabel,
            detail: String(format: "cosine %.2f", clap),
            share: Int((clamp01(clap) * 100).rounded()),
            matched: clap >= 0.3)
        components.insert(acoustic, at: 0)

        let (phraseTerms, phraseVerbatim) = phraseMatches(prompt: prompt, in: text)

        var context: [String] = []
        if !recentIDs.contains(record.id) {
            context.append("Fresh — not played in your last \(SeenHistoryStore.capacity)")
        }
        if pills.isEmpty {
            context.append("No direction set — picks are catalog-fresh")
        }

        return ScoredTrack(
            record: record,
            moodMatch: MoodMatch(index: index, summary: summary(index), components: components, context: context,
                                 matchedPhraseTerms: phraseTerms, phraseMatchedVerbatim: phraseVerbatim))
    }

    private func searchable(_ r: TrackVectorRecord) -> String {
        [r.title, r.composer ?? "", (r.tags ?? []).joined(separator: " "),
         r.albumTitle ?? "", r.albumSubjects ?? "", r.albumGenres ?? ""]
            .joined(separator: " ").lowercased()
    }

    private func pillMatched(_ pill: Pill, in text: String) -> Bool {
        let terms = pill.metadataTerms.map { $0.lowercased() }.filter { !$0.isEmpty }
        guard !terms.isEmpty else { return false }
        let negatives = pill.negativeTerms.map { $0.lowercased() }.filter { !$0.isEmpty }
        if negatives.contains(where: { text.contains($0) }) { return false }
        return terms.contains { text.contains($0) }
    }

    private func phraseMatches(prompt: String, in text: String) -> (terms: [String], verbatim: Bool) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return ([], false) }
        var seen = Set<String>()
        let matched = trimmed
            .components(separatedBy: CharacterSet(charactersIn: " ,;"))
            .filter { !$0.isEmpty && !stop.contains($0) }
            .filter { word in
                guard !seen.contains(word) else { return false }
                seen.insert(word)
                return text.contains(word)
            }
        return (matched, text.contains(trimmed))
    }

    private func summary(_ i: Int) -> String {
        switch i {
        case 80...:  return "Strong fit"
        case 55..<80: return "Good fit, partial match"
        case 40..<55: return "Related direction, looser fit"
        case 20..<40: return "Loosely related — fresh pick"
        default:      return "Fresh — outside the current direction"
        }
    }

    private func clamp01(_ x: Float) -> Float { min(1, max(0, x)) }
}
