import Foundation

struct RotationPlanner {
    var window = 50

    func plan(ranked: [ScoredTrack],
              seen: Set<String>,
              disliked: Set<String>,
              refill: () -> [ScoredTrack]) -> [ScoredTrack] {
        let eligible = ranked.filter { !disliked.contains($0.id) && !seen.contains($0.id) }
        if eligible.count >= window { return Array(eligible.prefix(window)) }

        var chosen = Set(eligible.map(\.id))
        var out = eligible
        for t in refill() where !chosen.contains(t.id) && !disliked.contains(t.id) && !seen.contains(t.id) {
            out.append(t); chosen.insert(t.id)
            if out.count >= window { break }
        }
        return out
    }
}
