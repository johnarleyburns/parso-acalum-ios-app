@testable import Acalum
import XCTest

final class RotationPlannerTests: XCTestCase {
    private func makeScored(id: String, index: Int) -> ScoredTrack {
        var values = [Float](repeating: 0, count: 512)
        values[0] = 1.0
        let record = TrackVectorRecord(
            id: id, title: "Track \(id)", composer: nil, performer: nil,
            clapVector: try! Embedding512(values: values).normalized(),
            tags: nil, albumTitle: nil, albumSubjects: nil, albumGenres: nil,
            durationSeconds: 180, sourceURL: nil, audioURL: nil, artURL: nil
        )
        let mm = MoodMatch(index: index, summary: "Test", components: [], context: [])
        return ScoredTrack(record: record, moodMatch: mm)
    }

    func testWindowAlwaysFullWhenEnoughEligible() {
        let planner = RotationPlanner(window: 5)
        let ranked = (0..<10).map { makeScored(id: "\($0)", index: 100 - $0) }
        let result = planner.plan(ranked: ranked, seen: [], disliked: []) { [] }
        XCTAssertEqual(result.count, 5)
    }

    func testNeverIncludesSeen() {
        let planner = RotationPlanner(window: 5)
        let ranked = (0..<10).map { makeScored(id: "\($0)", index: 100 - $0) }
        let result = planner.plan(ranked: ranked, seen: ["0", "1"], disliked: []) { [] }
        XCTAssertFalse(result.contains(where: { $0.id == "0" }))
        XCTAssertFalse(result.contains(where: { $0.id == "1" }))
    }

    func testNeverIncludesDisliked() {
        let planner = RotationPlanner(window: 5)
        let ranked = (0..<10).map { makeScored(id: "\($0)", index: 100 - $0) }
        let result = planner.plan(ranked: ranked, seen: [], disliked: ["0", "1"]) { [] }
        XCTAssertFalse(result.contains(where: { $0.id == "0" }))
        XCTAssertFalse(result.contains(where: { $0.id == "1" }))
    }

    func testRefillWhenStarved() {
        let planner = RotationPlanner(window: 5)
        let ranked = [
            makeScored(id: "a", index: 90),
            makeScored(id: "b", index: 80),
        ]
        var refillCalled = false
        let result = planner.plan(ranked: ranked, seen: [], disliked: []) {
            refillCalled = true
            return [
                makeScored(id: "c", index: 70),
                makeScored(id: "d", index: 60),
                makeScored(id: "e", index: 50),
                makeScored(id: "f", index: 40),
            ]
        }
        XCTAssertTrue(refillCalled)
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result[0].id, "a")
        XCTAssertEqual(result[1].id, "b")
        XCTAssertEqual(result[2].id, "c")
        XCTAssertEqual(result[3].id, "d")
        XCTAssertEqual(result[4].id, "e")
    }

    func testRefillSkipsDuplicatesAndDisliked() {
        let planner = RotationPlanner(window: 5)
        let ranked = [
            makeScored(id: "a", index: 90),
        ]
        let result = planner.plan(ranked: ranked, seen: [], disliked: ["d"]) {
            [
                makeScored(id: "a", index: 85), // duplicate
                makeScored(id: "b", index: 80),
                makeScored(id: "c", index: 75),
                makeScored(id: "d", index: 70), // disliked
                makeScored(id: "e", index: 65),
                makeScored(id: "f", index: 60),
            ]
        }
        let ids = result.map(\.id)
        XCTAssertEqual(ids, ["a", "b", "c", "e", "f"])
    }

    func testMaintainsScoreOrder() {
        let planner = RotationPlanner(window: 5)
        let ranked = (0..<10).map { makeScored(id: "\($0)", index: 100 - $0 * 5) }
        let result = planner.plan(ranked: ranked, seen: [], disliked: []) { [] }
        let indices = result.map(\.moodMatch.index)
        XCTAssertEqual(indices, indices.sorted(by: >))
    }

    func testZeroMatchReturnsNonEmpty() {
        let planner = RotationPlanner(window: 5)
        let result = planner.plan(ranked: [], seen: ["a", "b", "c"], disliked: []) {
            (0..<5).map { makeScored(id: "filler_\($0)", index: 10) }
        }
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result.count, 5)
    }
}
