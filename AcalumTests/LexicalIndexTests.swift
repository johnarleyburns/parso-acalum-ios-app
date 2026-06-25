@testable import Acalum
import XCTest

final class LexicalIndexTests: XCTestCase {
    private func rec(_ id: String, title: String, tags: [String]?,
                     albumGenres: String? = nil, albumSubjects: String? = nil) -> TrackVectorRecord {
        TrackVectorRecord(
            id: id, title: title, composer: nil, performer: nil,
            clapVector: .zero, tags: tags, albumTitle: nil,
            albumSubjects: albumSubjects, albumGenres: albumGenres,
            durationSeconds: 180, sourceURL: nil, audioURL: nil, artURL: nil)
    }

    private func topID(_ scores: [String: Float]) -> String? {
        scores.max { $0.value < $1.value }?.key
    }

    func testGregorianChantSurfacesChantTrack() {
        let catalog = [
            rec("chant", title: "Gregorian Chant Kyrie", tags: ["gregorian", "chant", "sacred"]),
            rec("guitar", title: "Spanish Guitar Suite", tags: ["spanish", "guitar"]),
            rec("jazz", title: "Jazz Piano Trio", tags: ["jazz", "piano"]),
        ]
        let index = LexicalIndex(catalog: catalog)
        let scores = index.scores(queryTerms: LexicalIndex.terms("gregorian chant"),
                                  phrase: "gregorian chant")
        XCTAssertEqual(topID(scores), "chant")
        XCTAssertNil(scores["jazz"])
    }

    func testSpanishGuitarSurfacesGuitarTrack() {
        let catalog = [
            rec("chant", title: "Gregorian Chant Kyrie", tags: ["gregorian", "chant"]),
            rec("guitar", title: "Spanish Guitar Suite", tags: ["spanish", "guitar", "flamenco"]),
            rec("jazz", title: "Jazz Piano Trio", tags: ["jazz", "piano"]),
        ]
        let index = LexicalIndex(catalog: catalog)
        let scores = index.scores(queryTerms: LexicalIndex.terms("spanish guitar"),
                                  phrase: "spanish guitar")
        XCTAssertEqual(topID(scores), "guitar")
        XCTAssertNil(scores["jazz"])
    }

    func testBareGuitarTermReturnsAllGuitarTracks() {
        let catalog = [
            rec("chant", title: "Gregorian Chant Kyrie", tags: ["gregorian", "chant"]),
            rec("g1", title: "Spanish Guitar Suite", tags: ["spanish", "guitar"]),
            rec("g2", title: "Classical Guitar Etude", tags: ["guitar", "classical"]),
            rec("jazz", title: "Jazz Piano Trio", tags: ["jazz", "piano"]),
        ]
        let index = LexicalIndex(catalog: catalog)
        let scores = index.scores(queryTerms: LexicalIndex.terms("guitar"), phrase: "guitar")
        XCTAssertNotNil(scores["g1"])
        XCTAssertNotNil(scores["g2"])
        XCTAssertNil(scores["chant"])
        XCTAssertNil(scores["jazz"])
    }

    func testPhraseBonusBoostsExactPhraseDoc() {
        // No matching tags so the score stays below the cap and the phrase bonus is visible.
        let catalog = [
            rec("phrase", title: "Spanish Guitar Concerto", tags: nil),
            rec("scattered", title: "Guitar in the Spanish style", tags: nil),
        ]
        let index = LexicalIndex(catalog: catalog)
        let scores = index.scores(queryTerms: LexicalIndex.terms("spanish guitar"),
                                  phrase: "spanish guitar")
        let phraseScore = try! XCTUnwrap(scores["phrase"])
        let scatteredScore = try! XCTUnwrap(scores["scattered"])
        XCTAssertGreaterThan(phraseScore, scatteredScore)
    }

    func testEmptyQueryReturnsNothing() {
        let catalog = [rec("a", title: "Anything", tags: ["x"])]
        let index = LexicalIndex(catalog: catalog)
        XCTAssertTrue(index.scores(queryTerms: [], phrase: "").isEmpty)
    }
}
