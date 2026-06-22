@testable import Acalum
import XCTest

final class SearchRerankerTests: XCTestCase {
    private func makeResult(id: String, score: Float, title: String = "Track", composer: String? = nil, tags: [String]? = nil, albumTitle: String? = nil, albumSubjects: String? = nil, albumGenres: String? = nil) -> SearchResult {
        var values = [Float](repeating: 0, count: 512)
        values[0] = 1.0
        let record = TrackVectorRecord(
            id: id,
            title: title,
            composer: composer,
            performer: nil,
            clapVector: try! Embedding512(values: values).normalized(),
            tags: tags,
            albumTitle: albumTitle,
            albumSubjects: albumSubjects,
            albumGenres: albumGenres,
            durationSeconds: 180,
            sourceURL: nil,
            audioURL: nil,
            artURL: nil
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
        let favVector = try! Embedding512(values: [Float](repeating: 0, count: 512).enumerated().map { $0.offset == 0 ? 1.0 : 0 }).normalized()
        let otherVector = try! Embedding512(values: [Float](repeating: 0, count: 512).enumerated().map { $0.offset == 0 ? 0 : ($0.offset == 1 ? 1.0 : 0) }).normalized()

        var favValues = [Float](repeating: 0, count: 512)
        favValues[0] = 1.0
        var otherValues = [Float](repeating: 0, count: 512)
        otherValues[1] = 1.0

        let favRecord = TrackVectorRecord(
            id: "fav", title: "Favorite Track", composer: nil, performer: nil,
            clapVector: favVector, tags: nil, albumTitle: nil, albumSubjects: nil, albumGenres: nil,
            durationSeconds: 180, sourceURL: nil, audioURL: nil, artURL: nil
        )
        let otherRecord = TrackVectorRecord(
            id: "other", title: "Other Track", composer: nil, performer: nil,
            clapVector: otherVector, tags: nil, albumTitle: nil, albumSubjects: nil, albumGenres: nil,
            durationSeconds: 180, sourceURL: nil, audioURL: nil, artURL: nil
        )

        let results = [
            SearchResult(track: favRecord, score: 0.5, explanation: []),
            SearchResult(track: otherRecord, score: 0.5, explanation: []),
        ]

        let tasteVec = favVector
        let reranked = reranker.rerank(results: results, favoriteTrackIDs: ["fav"], tasteVector: tasteVec)
        let favResult = reranked.first(where: { $0.track.id == "fav" })
        let otherResult = reranked.first(where: { $0.track.id == "other" })
        XCTAssertGreaterThan(favResult!.score, otherResult!.score)
    }

    func testEmptyResults() {
        let reranker = SearchReranker()
        let reranked = reranker.rerank(results: [])
        XCTAssertTrue(reranked.isEmpty)
    }

    // MARK: - SemanticPhrase matching

    func testSemanticPhraseWordMatchInTitle() {
        let reranker = SearchReranker()
        let results = [
            makeResult(id: "piano_piece", score: 0.5, title: "Keyboard Sonata in G minor"),
            makeResult(id: "orchestral", score: 0.5, title: "Symphony No. 5"),
        ]
        let pills = [Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano")]
        let reranked = reranker.rerank(results: results, selectedPills: pills)
        let pianoResult = reranked.first(where: { $0.track.id == "piano_piece" })
        let orchResult = reranked.first(where: { $0.track.id == "orchestral" })
        // "Keyboard" contains no semanticPhrase words; "Piano" in semanticPhrase "solo piano" matches nothing
        // Both should have similar pill scores (0), but let's verify they're still present
        XCTAssertNotNil(pianoResult)
        XCTAssertNotNil(orchResult)
    }

    func testSemanticPhraseWordMatchInComposer() {
        let reranker = SearchReranker()
        let results = [
            makeResult(id: "bach", score: 0.5, title: "Fugue", composer: "J.S. Bach"),
            makeResult(id: "mozart", score: 0.5, title: "Rondo", composer: "W.A. Mozart"),
        ]
        let pills = [Pill(id: "era:baroque", label: "Baroque", category: .era, semanticPhrase: "baroque, harpsichord, counterpoint, 1600s 1700s")]
        let reranked = reranker.rerank(results: results, selectedPills: pills)
        let bachResult = reranked.first(where: { $0.track.id == "bach" })
        let mozartResult = reranked.first(where: { $0.track.id == "mozart" })
        // Neither "Bach" nor "Mozart" contains words from the semanticPhrase
        XCTAssertNotNil(bachResult)
        XCTAssertNotNil(mozartResult)
        // Both get zero pill score, so scores should be driven by CLAP similarity
    }

    func testSemanticPhraseFallsBackToLabelWhenEmpty() {
        let reranker = SearchReranker()
        let results = [
            makeResult(id: "match", score: 0.5, title: "Violin Concerto"),
            makeResult(id: "nomatch", score: 0.5, title: "Trombone Solo"),
        ]
        let pills = [Pill(id: "instrument:violin", label: "Violin", category: .instrument, semanticPhrase: "")]
        let reranked = reranker.rerank(results: results, selectedPills: pills)
        let matchResult = reranked.first(where: { $0.track.id == "match" })
        let noMatchResult = reranked.first(where: { $0.track.id == "nomatch" })
        XCTAssertNotNil(matchResult)
        XCTAssertNotNil(noMatchResult)
        XCTAssertGreaterThan(matchResult!.score, noMatchResult!.score)
    }

    func testSemanticPhraseTagsMatching() {
        let reranker = SearchReranker()
        let results = [
            makeResult(id: "tagged", score: 0.5, title: "Unknown Track", tags: ["piano", "classical"]),
            makeResult(id: "untagged", score: 0.5, title: "Unknown Track 2", tags: ["drums", "rock"]),
        ]
        let pills = [Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano")]
        let reranked = reranker.rerank(results: results, selectedPills: pills)
        let taggedResult = reranked.first(where: { $0.track.id == "tagged" })
        let untaggedResult = reranked.first(where: { $0.track.id == "untagged" })
        // "piano" tag should match "piano" in semanticPhrase
        XCTAssertTrue(taggedResult!.score > untaggedResult!.score)
    }

    func testSemanticPhraseStopWordsIgnored() {
        let reranker = SearchReranker()
        let results = [
            makeResult(id: "match", score: 0.5, title: "Cello Suite"),
            makeResult(id: "nomatch", score: 0.5, title: "Flute Sonata"),
        ]
        // semanticPhrase has "for" and "and" which are stop words, only "cello" should match
        let pills = [Pill(id: "instrument:cello", label: "Cello", category: .instrument, semanticPhrase: "solo cello for and the")]
        let reranked = reranker.rerank(results: results, selectedPills: pills)
        let celloResult = reranked.first(where: { $0.track.id == "match" })
        let fluteResult = reranked.first(where: { $0.track.id == "nomatch" })
        XCTAssertGreaterThan(celloResult!.score, fluteResult!.score)
    }

    func testMultiplePillsCombineWords() {
        let reranker = SearchReranker()
        let results = [
            makeResult(id: "perfect", score: 0.5, title: "solo piano melancholy rainy day"),
            makeResult(id: "partial", score: 0.5, title: "orchestral symphony"),
        ]
        let pills = [
            Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano"),
            Pill(id: "mood:melancholy", label: "Melancholy", category: .mood, semanticPhrase: "melancholy, sad"),
            Pill(id: "context:rainy_day", label: "Rainy Day", category: .context, semanticPhrase: "rainy day, contemplative"),
        ]
        let reranked = reranker.rerank(results: results, selectedPills: pills)
        let perfectResult = reranked.first(where: { $0.track.id == "perfect" })
        let partialResult = reranked.first(where: { $0.track.id == "partial" })
        // "perfect" matches "solo", "piano", "melancholy", "rainy", "day" = 5 out of ~7 unique words
        // "partial" matches nothing = 0
        XCTAssertTrue(perfectResult!.score > partialResult!.score)
    }

    // MARK: - shuffleTopN

    func testShuffleTopNWithZeroDoesNotShuffle() {
        let reranker = SearchReranker()
        var results: [SearchResult] = []
        for i in 0..<10 {
            results.append(makeResult(id: "\(i)", score: 1.0 - Float(i) * 0.05))
        }
        let reranked = reranker.rerank(results: results, shuffleTopN: 0)
        // Should be in strict score order
        let ids = reranked.map(\.track.id)
        XCTAssertEqual(ids, ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"])
    }

    func testShuffleTopNKeepsTailOrdered() {
        let reranker = SearchReranker()
        var results: [SearchResult] = []
        for i in 0..<10 {
            results.append(makeResult(id: "\(i)", score: 1.0 - Float(i) * 0.05))
        }
        // Run multiple times to account for randomness
        for _ in 0..<20 {
            let reranked = reranker.rerank(results: results, shuffleTopN: 3)
            // Top 3 may be shuffled, but tail (index 3+) must be in score order
            let ids = reranked.map(\.track.id)
            let tail = Array(ids[3...])
            XCTAssertEqual(tail, ["3", "4", "5", "6", "7", "8", "9"])
        }
    }

    func testShuffleTopNGreaterThanCountDoesNotCrash() {
        let reranker = SearchReranker()
        let results = [
            makeResult(id: "a", score: 0.9),
            makeResult(id: "b", score: 0.8),
        ]
        let reranked = reranker.rerank(results: results, shuffleTopN: 10)
        XCTAssertEqual(reranked.count, 2)
    }

    // MARK: - Weights

    func testWeightRebalancePillScoreHasHigherImpact() {
        let defaultWeights = SearchReranker.Weights()
        XCTAssertEqual(defaultWeights.clapSimilarity, 0.50)
        XCTAssertEqual(defaultWeights.metadataPillScore, 0.35)
        XCTAssertEqual(defaultWeights.noveltyScore, 0.10)
        XCTAssertEqual(defaultWeights.userTasteScore, 0.05)

        let sum = defaultWeights.clapSimilarity + defaultWeights.metadataPillScore
            + defaultWeights.noveltyScore + defaultWeights.userTasteScore
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
    }

    func testPillMatchOverridesWeakCLAP() {
        let weights = SearchReranker.Weights(
            clapSimilarity: 0.50,
            metadataPillScore: 0.35,
            noveltyScore: 0.10,
            userTasteScore: 0.05
        )
        let reranker = SearchReranker(weights: weights)
        let results = [
            makeResult(id: "strong_clap_no_match", score: 0.95, title: "Cumana"),
            makeResult(id: "weak_clap_strong_match", score: 0.30, title: "solo piano melancholy sad adagio"),
        ]
        let pills = [
            Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano"),
            Pill(id: "mood:melancholy", label: "Melancholy", category: .mood, semanticPhrase: "melancholy sad"),
        ]
        let reranked = reranker.rerank(results: results, selectedPills: pills)
        let first = reranked.first!
        XCTAssertEqual(first.track.id, "weak_clap_strong_match",
                       "Strong pill-matched track should outrank weak CLAP-only track with new weights")
    }
}
