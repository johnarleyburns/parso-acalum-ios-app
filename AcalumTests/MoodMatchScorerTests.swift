@testable import Acalum
import XCTest

final class MoodMatchScorerTests: XCTestCase {
    private func makeRecord(id: String, title: String, composer: String? = nil, tags: [String]? = nil) -> TrackVectorRecord {
        var values = [Float](repeating: 0, count: 512)
        values[0] = 1.0
        return TrackVectorRecord(
            id: id, title: title, composer: composer, performer: nil,
            clapVector: try! Embedding512(values: values).normalized(),
            tags: tags, albumTitle: nil, albumSubjects: nil, albumGenres: nil,
            durationSeconds: 180, sourceURL: nil, audioURL: nil, artURL: nil
        )
    }

    func testMatchedPillProducesTrueComponent() {
        let scorer = MoodMatchScorer()
        let record = makeRecord(id: "t1", title: "Classical Guitar Sonata")
        let pills = [Pill(id: "instrument:guitar", label: "Guitar", category: .instrument, semanticPhrase: "solo classical guitar")]
        let result = scorer.score(record: record, clap: 0.5, recentIDs: [], pills: pills)
        let guitarComponent = result.moodMatch.components.first(where: { $0.label.contains("Guitar") })
        XCTAssertNotNil(guitarComponent)
        XCTAssertTrue(guitarComponent!.matched)
    }

    func testUnmatchedPillProducesFalseComponent() {
        let scorer = MoodMatchScorer()
        let record = makeRecord(id: "t1", title: "Trombone Concerto")
        let pills = [Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano")]
        let result = scorer.score(record: record, clap: 0.5, recentIDs: [], pills: pills)
        let pianoComponent = result.moodMatch.components.first(where: { $0.label.contains("Piano") })
        XCTAssertNotNil(pianoComponent)
        XCTAssertFalse(pianoComponent!.matched)
    }

    func testAcousticComponentAlwaysPresentAndFirst() {
        let scorer = MoodMatchScorer()
        let record = makeRecord(id: "t1", title: "Test Track")
        let result = scorer.score(record: record, clap: 0.5, recentIDs: [], pills: [])
        XCTAssertEqual(result.moodMatch.components.first?.label, "Acoustic character")
    }

    func testHigherIndexOrdersFirst() {
        let scorer = MoodMatchScorer()
        let rec1 = makeRecord(id: "high", title: "Guitar Concerto")
        let rec2 = makeRecord(id: "low", title: "Trombone Concerto")
        let pills = [Pill(id: "instrument:guitar", label: "Guitar", category: .instrument, semanticPhrase: "solo classical guitar")]

        let s1 = scorer.score(record: rec1, clap: 0.5, recentIDs: [], pills: pills)
        let s2 = scorer.score(record: rec2, clap: 0.5, recentIDs: [], pills: pills)

        XCTAssertGreaterThan(s1.moodMatch.index, s2.moodMatch.index)
    }

    func testNoPillsGivesBaselineScore() {
        let scorer = MoodMatchScorer()
        let record = makeRecord(id: "t1", title: "Test Track")
        let result = scorer.score(record: record, clap: 0.3, recentIDs: [], pills: [])
        XCTAssertTrue(result.moodMatch.context.contains(where: { $0.contains("No mood selected") }))
    }

    func testIndexIsAlwaysZeroToHundred() {
        let scorer = MoodMatchScorer()
        let record = makeRecord(id: "t1", title: "Test Track")
        for clap in stride(from: -0.5, through: 1.5, by: 0.2) {
            let result = scorer.score(record: record, clap: Float(clap), recentIDs: [], pills: [])
            XCTAssertTrue((0...100).contains(result.moodMatch.index))
        }
    }

    func testSummaryBands() {
        let scorer = MoodMatchScorer()
        let record = makeRecord(id: "t1", title: "Test Track")

        let high = scorer.score(record: record, clap: 0.9, recentIDs: [], pills: [])
        XCTAssertTrue(high.moodMatch.summary.contains("Strong"))

        let low = scorer.score(record: record, clap: 0.1, recentIDs: [], pills: [])
        XCTAssertTrue(low.moodMatch.summary.contains("Fresh"))
    }

    func testFreshContextWhenNotSeen() {
        let scorer = MoodMatchScorer()
        let record = makeRecord(id: "fresh_track", title: "Never Played")
        let result = scorer.score(record: record, clap: 0.5, recentIDs: ["other_track"], pills: [])
        XCTAssertTrue(result.moodMatch.context.contains(where: { $0.starts(with: "Fresh") }))
    }
}
