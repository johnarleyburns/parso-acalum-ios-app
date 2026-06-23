import Foundation

struct ScoredTrack {
    let record: TrackVectorRecord
    let moodMatch: MoodMatch
    var id: String { record.id }
}

struct MoodMatchScorer {
    var clapWeight: Float = 0.62
    var tagWeight: Float = 0.38
    let calibrator: MoodIndexCalibrator

    private let stop: Set<String> = ["", ",", "and", "the", "of", "in", "for", "a", "an", "to", "with", "or", "is", "it", "on", "at", "by", "as", "be", "no", "not", "but"]

    init(calibrator: MoodIndexCalibrator = MoodIndexCalibrator()) {
        self.calibrator = calibrator
    }

    func score(record: TrackVectorRecord, clap: Float, recentIDs: Set<String>, pills: [Pill]) -> ScoredTrack {
        let text = searchable(record)
        var components: [MoodComponent] = []
        var matched = 0

        for pill in pills {
            let hit = pillMatched(pill, in: text)
            if hit { matched += 1 }
            components.append(MoodComponent(
                label: "\(pill.category.rawValue.capitalized): \(pill.label)",
                detail: hit ? "tag present" : "not tagged",
                share: hit ? 100 : 0,
                matched: hit))
        }

        let raw: Float
        if pills.isEmpty {
            raw = clamp01(clap)
        } else {
            let tagRatio = Float(matched) / Float(pills.count)
            raw = clamp01(clapWeight * clamp01(clap) * max(tagRatio, 0.15) + tagWeight * tagRatio)
        }
        let index = calibrator.index(raw)

        let acoustic = MoodComponent(
            label: "Acoustic character",
            detail: String(format: "cosine %.2f", clap),
            share: Int((clamp01(clap) * 100).rounded()),
            matched: clap >= 0.3)
        components.insert(acoustic, at: 0)

        var context: [String] = []
        if !recentIDs.contains(record.id) {
            context.append("Fresh — not played in your last \(SeenHistoryStore.capacity)")
        }
        if pills.isEmpty {
            context.append("No mood selected — picks are catalog-fresh")
        }

        return ScoredTrack(
            record: record,
            moodMatch: MoodMatch(index: index, summary: summary(index), components: components, context: context))
    }

    private func searchable(_ r: TrackVectorRecord) -> String {
        [r.title, r.composer ?? "", (r.tags ?? []).joined(separator: " "),
         r.albumTitle ?? "", r.albumSubjects ?? "", r.albumGenres ?? ""]
            .joined(separator: " ").lowercased()
    }

    private func pillMatched(_ pill: Pill, in text: String) -> Bool {
        let phrase = pill.semanticPhrase.isEmpty ? pill.label : pill.semanticPhrase
        let words = phrase.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: " ,;"))
            .filter { !$0.isEmpty && !stop.contains($0) }
        guard !words.isEmpty else { return false }
        return words.contains { text.contains($0) }
    }

    private func summary(_ i: Int) -> String {
        switch i {
        case 80...:  return "Strong acoustic + mood match"
        case 55..<80: return "Good acoustic match, partial mood"
        case 40..<55: return "Related feeling, looser fit"
        case 20..<40: return "Loosely related — fresh pick"
        default:      return "Fresh — outside the current mood"
        }
    }

    private func clamp01(_ x: Float) -> Float { min(1, max(0, x)) }
}
