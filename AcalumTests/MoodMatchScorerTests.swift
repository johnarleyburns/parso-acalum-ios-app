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
        let pills = [Pill(id: "sound:guitar", label: "Guitar", category: .sound,
                          embeddingPhrase: "classical guitar", metadataTerms: ["guitar"])]
        let result = scorer.score(record: record, clap: 0.5, recentIDs: [], pills: pills)
        let guitarComponent = result.moodMatch.components.first(where: { $0.label.contains("Guitar") })
        XCTAssertNotNil(guitarComponent)
        XCTAssertTrue(guitarComponent!.matched)
    }

    func testUnmatchedPillProducesFalseComponent() {
        let scorer = MoodMatchScorer()
        let record = makeRecord(id: "t1", title: "Trombone Concerto")
        let pills = [Pill(id: "sound:piano", label: "Piano", category: .sound,
                          embeddingPhrase: "solo piano", metadataTerms: ["piano"])]
        let result = scorer.score(record: record, clap: 0.5, recentIDs: [], pills: pills)
        let pianoComponent = result.moodMatch.components.first(where: { $0.label.contains("Piano") })
        XCTAssertNotNil(pianoComponent)
        XCTAssertFalse(pianoComponent!.matched)
    }

    func testGenericWordDoesNotProduceTagMatch() {
        let scorer = MoodMatchScorer()
        // Listening-mode pills are semantic-only and must never claim a tag match,
        // even when the row literally contains the word "music".
        let record = makeRecord(id: "t1", title: "Background Music for Study", tags: ["music"])
        let reading = Pill(id: "mode:reading", label: "Reading", category: .listeningMode,
                           embeddingPhrase: "reading music, unobtrusive background music", metadataTerms: [])
        let result = scorer.score(record: record, clap: 0.5, recentIDs: [], pills: [reading])
        let component = result.moodMatch.components.first(where: { $0.label.contains("Reading") })
        XCTAssertNotNil(component)
        XCTAssertFalse(component!.matched, "Semantic-only pill must not assert a metadata match")
    }

    func testRomanticEraDoesNotMatchOnGenericClassical() {
        let scorer = MoodMatchScorer()
        let record = makeRecord(id: "t1", title: "A Classical Overture", tags: ["classical"])
        let romantic = Pill(id: "tradition:romantic", label: "Romantic Era", category: .tradition,
                            embeddingPhrase: "romantic era classical music", metadataTerms: ["romantic"])
        let result = scorer.score(record: record, clap: 0.5, recentIDs: [], pills: [romantic])
        let component = result.moodMatch.components.first(where: { $0.label.contains("Romantic") })
        XCTAssertNotNil(component)
        XCTAssertFalse(component!.matched, "Romantic Era should not match merely because the row is 'classical'")
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
        let pills = [Pill(id: "sound:guitar", label: "Guitar", category: .sound,
                          embeddingPhrase: "classical guitar", metadataTerms: ["guitar"])]

        let s1 = scorer.score(record: rec1, clap: 0.5, recentIDs: [], pills: pills)
        let s2 = scorer.score(record: rec2, clap: 0.5, recentIDs: [], pills: pills)

        XCTAssertGreaterThan(s1.moodMatch.index, s2.moodMatch.index)
    }

    func testNoPillsGivesBaselineScore() {
        let scorer = MoodMatchScorer()
        let record = makeRecord(id: "t1", title: "Test Track")
        let result = scorer.score(record: record, clap: 0.3, recentIDs: [], pills: [])
        XCTAssertTrue(result.moodMatch.context.contains(where: { $0.contains("No direction set") }))
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

    func testMatchedPhraseTermsContainPresentWordsOnly() {
        let scorer = MoodMatchScorer()
        let record = makeRecord(id: "t1", title: "Quiet Spanish Guitar")
        let result = scorer.score(record: record, clap: 0.5, recentIDs: [], pills: [], prompt: "quiet trombone")
        XCTAssertEqual(result.moodMatch.matchedPhraseTerms, ["quiet"])
    }

    func testMatchedPhraseTermsFilterStopwords() {
        let scorer = MoodMatchScorer()
        let record = makeRecord(id: "t1", title: "Quiet Spanish Guitar")
        let result = scorer.score(record: record, clap: 0.5, recentIDs: [], pills: [], prompt: "the quiet guitar")
        XCTAssertFalse(result.moodMatch.matchedPhraseTerms.contains("the"))
        XCTAssertEqual(result.moodMatch.matchedPhraseTerms, ["quiet", "guitar"])
    }

    func testPhraseMatchedVerbatimWhenFullPhrasePresent() {
        let scorer = MoodMatchScorer()
        let record = makeRecord(id: "t1", title: "Quiet Spanish Guitar")
        let hit = scorer.score(record: record, clap: 0.5, recentIDs: [], pills: [], prompt: "spanish guitar")
        XCTAssertTrue(hit.moodMatch.phraseMatchedVerbatim)
        let miss = scorer.score(record: record, clap: 0.5, recentIDs: [], pills: [], prompt: "guitar spanish")
        XCTAssertFalse(miss.moodMatch.phraseMatchedVerbatim)
    }

    func testEmptyPromptProducesNoPhraseMatches() {
        let scorer = MoodMatchScorer()
        let record = makeRecord(id: "t1", title: "Quiet Spanish Guitar")
        let result = scorer.score(record: record, clap: 0.5, recentIDs: [], pills: [], prompt: "")
        XCTAssertTrue(result.moodMatch.matchedPhraseTerms.isEmpty)
        XCTAssertFalse(result.moodMatch.phraseMatchedVerbatim)
    }
}
