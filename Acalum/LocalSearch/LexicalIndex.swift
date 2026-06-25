import Foundation

/// Lexical retrieval over metadata already present on each TrackVectorRecord.
/// `tags` is the indexer's curated keyword bag (identifier+title+creator+subjects+genres).
final class LexicalIndex {
    private struct Doc { let id: String; let tagSet: Set<String>; let blob: String }
    private let docs: [Doc]

    init(catalog: [TrackVectorRecord]) {
        docs = catalog.map { r in
            let blob = [r.title, r.composer ?? "", r.albumTitle ?? "",
                        r.albumGenres ?? "", r.albumSubjects ?? "",
                        (r.tags ?? []).joined(separator: " ")]
                .joined(separator: " ").lowercased()
            return Doc(id: r.id,
                       tagSet: Set((r.tags ?? []).map { $0.lowercased() }),
                       blob: blob)
        }
    }

    static func terms(_ s: String) -> [String] {
        s.lowercased().split { !$0.isLetter && !$0.isNumber }
            .map(String.init).filter { $0.count > 1 }
    }

    /// Returns id -> lexical score in [0,1]. Only includes tracks with > 0 overlap.
    func scores(queryTerms: [String], phrase: String) -> [String: Float] {
        let q = Set(queryTerms)
        guard !q.isEmpty else { return [:] }
        var out: [String: Float] = [:]
        for d in docs {
            let tagOverlap  = Float(q.intersection(d.tagSet).count) / Float(q.count) // strongest
            let textOverlap = Float(q.filter { d.blob.contains($0) }.count) / Float(q.count)
            guard tagOverlap > 0 || textOverlap > 0 else { continue }
            let phraseBonus: Float = (!phrase.isEmpty && d.blob.contains(phrase)) ? 0.4 : 0
            out[d.id] = min(1, 0.7 * tagOverlap + 0.3 * textOverlap + phraseBonus)
        }
        return out
    }
}
