@testable import Acalum
import XCTest

final class SearchRerankerTests: XCTestCase {
    private func makeResult(id: String, score: Float, title: String = "Track") -> SearchResult {
        var values = [Float](repeating: 0, count: 512)
        values[0] = 1.0
        let record = TrackVectorRecord(
            id: id,
            title: title,
            composer: nil,
            performer: nil,
            clapVector: try! Embedding512(values: values).normalized(),
            tags: nil,
            durationSeconds: 180,
            sourceURL: nil,
            audioURL: nil
        )
        return SearchResult(track: record, score: score, explanation: ["CLAP match"])
    }

    func testPreservesCLAPScoreDominance() {
        let reranker = SearchReranker()
        let results = [
            makeResult(id: "high", score: 0.9),
            makeResult(id: "low", score: 0.3),
        ]
        let reranked = reranker.rerank(results: results)
        XCTAssertEqual(reranked.first?.track.id, "high")
        XCTAssertGreaterThan(reranked[0].score, reranked[1].score)
    }

    func testExcludesRecentTracks() {
        let reranker = SearchReranker()
        let results = [
            makeResult(id: "recent", score: 0.9),
            makeResult(id: "fresh", score: 0.5),
        ]
        let reranked = reranker.rerank(results: results, recentTrackIDs: ["recent"])
        XCTAssertFalse(reranked.contains(where: { $0.track.id == "recent" }))
        XCTAssertEqual(reranked.count, 1)
    }

    func testPillMetadataBoost() {
        let reranker = SearchReranker()
        let results = [
            makeResult(id: "no_match", score: 0.5, title: "Sonata"),
            makeResult(id: "match", score: 0.5, title: "Guitar Concerto"),
        ]
        let pills = [Pill(id: "instrument:guitar", label: "Guitar", category: .instrument, semanticPhrase: "solo classical guitar")]
        let reranked = reranker.rerank(results: results, selectedPills: pills)
        let matchResult = reranked.first(where: { $0.track.id == "match" })
        let noMatchResult = reranked.first(where: { $0.track.id == "no_match" })
        XCTAssertNotNil(matchResult)
        XCTAssertNotNil(noMatchResult)
        XCTAssertGreaterThan(matchResult!.score, noMatchResult!.score)
    }

    func testFavoriteTasteBoost() {
        let reranker = SearchReranker()
        let results = [
            makeResult(id: "fav", score: 0.5),
            makeResult(id: "other", score: 0.5),
        ]
        let reranked = reranker.rerank(results: results, favoriteTrackIDs: ["fav"])
        let favResult = reranked.first(where: { $0.track.id == "fav" })
        let otherResult = reranked.first(where: { $0.track.id == "other" })
        XCTAssertGreaterThan(favResult!.score, otherResult!.score)
    }

    func testEmptyResults() {
        let reranker = SearchReranker()
        let reranked = reranker.rerank(results: [])
        XCTAssertTrue(reranked.isEmpty)
    }
}
