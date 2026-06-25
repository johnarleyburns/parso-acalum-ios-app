@testable import Acalum
import XCTest

private final class FakeSearchService: LocalVectorSearchService {
    let results: [TrackVectorRecord]
    let score: Float
    init(results: [TrackVectorRecord], score: Float = 0.9) {
        self.results = results
        self.score = score
    }
    func search(query: Embedding512, limit: Int, excluding excludedTrackIDs: Set<String>) async throws -> [SearchResult] {
        results
            .filter { !excludedTrackIDs.contains($0.id) }
            .map { SearchResult(track: $0, score: query.dot($0.clapVector), explanation: []) }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }
}

final class LocalRecommendationEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearTaste()
    }

    override func tearDown() {
        clearTaste()
        super.tearDown()
    }

    private func clearTaste() {
        TasteProfileStore.favoriteTrackIDs = []
        TasteProfileStore.completedTrackIDs = []
        TasteProfileStore.skippedTrackIDs = []
        TasteProfileStore.clearTasteVectorCache()
    }

    private func rec(_ id: String, title: String, tags: [String]?) -> TrackVectorRecord {
        TrackVectorRecord(
            id: id, title: title, composer: nil, performer: nil,
            clapVector: .zero, tags: tags, albumTitle: nil, albumSubjects: nil,
            albumGenres: nil, durationSeconds: 180, sourceURL: nil, audioURL: nil, artURL: nil)
    }

    private func recV(_ id: String, direction: Int) -> TrackVectorRecord {
        var values = [Float](repeating: 0, count: Embedding512.dimension)
        values[direction % Embedding512.dimension] = 1.0
        return TrackVectorRecord(
            id: id, title: "Track \(id)", composer: nil, performer: nil,
            clapVector: try! Embedding512(values: values).normalized(), tags: nil,
            albumTitle: nil, albumSubjects: nil, albumGenres: nil,
            durationSeconds: 180, sourceURL: nil, audioURL: nil, artURL: nil)
    }

    private func makeEngine(catalog: [TrackVectorRecord],
                            searchService: LocalVectorSearchService,
                            textEmbedding: TextEmbeddingService? = nil) -> LocalRecommendationEngine {
        LocalRecommendationEngine(
            catalog: catalog,
            searchService: searchService,
            tasteBuilder: TasteVectorBuilder(catalog: catalog),
            textEmbedding: textEmbedding)
    }

    // Vector channel returns only unrelated tracks (simulating a missing/misaligned model).
    // The lexical channel must still surface the tagged tracks.
    func testLexicalUnionSurfacesTaggedTracksDespiteUnrelatedVectorHits() async {
        let catalog = [
            rec("chant1", title: "Gregorian Chant", tags: ["gregorian", "chant"]),
            rec("chant2", title: "Sacred Chant", tags: ["chant", "sacred"]),
            rec("guitar1", title: "Spanish Guitar", tags: ["guitar", "spanish"]),
            rec("jazz1", title: "Jazz One", tags: ["jazz"]),
            rec("jazz2", title: "Jazz Two", tags: ["jazz"]),
        ]
        let unrelated = [catalog[3], catalog[4]] // jazz only
        let engine = makeEngine(catalog: catalog, searchService: FakeSearchService(results: unrelated))
        let context = DiscoveryContext(prompt: "gregorian chant")

        let tracks = await engine.generateQueue(context: context)
        let ids = tracks.map(\.id)

        XCTAssertEqual(tracks.first?.id, "chant1")
        XCTAssertTrue(ids.contains("chant2"))
    }

    func testFavoritesAreNotExcludedFromResults() async {
        let catalog = [
            rec("chant1", title: "Gregorian Chant", tags: ["gregorian", "chant"]),
            rec("jazz1", title: "Jazz One", tags: ["jazz"]),
        ]
        let engine = makeEngine(catalog: catalog, searchService: FakeSearchService(results: [catalog[1]]))
        let context = DiscoveryContext(prompt: "gregorian chant", favoriteTrackIDs: ["chant1"])

        let tracks = await engine.generateQueue(context: context)
        XCTAssertTrue(tracks.map(\.id).contains("chant1"))
    }

    // Explicit pill intent is embedded before any taste vector is consulted.
    func testPillsDriveQueryVectorBeforeTaste() async throws {
        let catalog = [recV("fav", direction: 7), recV("other", direction: 200)]
        TasteProfileStore.favoriteTrackIDs = ["fav"] // taste history points at "fav"
        let engine = makeEngine(catalog: catalog,
                                searchService: FakeSearchService(results: catalog),
                                textEmbedding: MockTextEmbeddingService())
        let pill = Pill(id: "guitar", label: "Guitar", category: .instrument, semanticPhrase: "acoustic guitar")
        let context = DiscoveryContext(prompt: nil, selectedPills: [pill])

        let query = await engine.buildQueryVector(from: context)
        let expected = try await MockTextEmbeddingService().embed(prompt: "", pills: [pill])
        XCTAssertEqual(query.dot(expected), 1.0, accuracy: 1e-4)
    }

    func testTasteUsedOnlyWhenNoExplicitIntent() async {
        let fav = recV("fav", direction: 11)
        let catalog = [fav, recV("other", direction: 300)]
        TasteProfileStore.favoriteTrackIDs = ["fav"]
        let engine = makeEngine(catalog: catalog, searchService: FakeSearchService(results: catalog))

        let query = await engine.buildQueryVector(from: DiscoveryContext(prompt: nil))
        // Taste built from the single favorite is a unit vector along its direction.
        XCTAssertEqual(query.dot(fav.clapVector), 1.0, accuracy: 1e-4)
    }

    func testSimilarToTrackBiasesResultsTowardSeedVector() async {
        let seed = recV("seed", direction: 7)
        let nearSeed = recV("near", direction: 7)  // same direction
        let far = recV("far", direction: 200)
        let catalog = [seed, nearSeed, far]
        let engine = makeEngine(catalog: catalog, searchService: FakeSearchService(results: catalog))

        let context = DiscoveryContext(similarToTrackID: "seed")
        let tracks = await engine.generateQueue(context: context)

        // nearSeed should rank before far because it's closer to the seed
        let ids = tracks.map(\.id)
        guard let nearIdx = ids.firstIndex(of: "near"),
              let farIdx = ids.firstIndex(of: "far") else {
            XCTFail("Expected both near and far in results")
            return
        }
        XCTAssertLessThan(nearIdx, farIdx, "near should rank before far")
    }

    func testSimilarToTrackStillRespectsMoodWhenMoodExists() async {
        let seed = recV("seed", direction: 7)
        let moodMatch = recV("mood_match", direction: 150)
        let nearSeed = recV("near_seed", direction: 8)  // very close to seed
        let catalog = [seed, moodMatch, nearSeed]

        // Build an engine whose search service returns results presorted
        let allSorted: [TrackVectorRecord] = [moodMatch, nearSeed, seed]
        let engine = makeEngine(catalog: catalog, searchService: FakeSearchService(results: allSorted))

        let piano = Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano")
        let context = DiscoveryContext(
            prompt: nil,
            selectedPills: [piano],
            recentlyPlayedTrackIDs: ["seed"],
            similarToTrackID: "seed"
        )
        let tracks = await engine.generateQueue(context: context)

        XCTAssertFalse(tracks.isEmpty)
        // The seed track itself should be excluded as recently played
        let ids = tracks.map(\.id)
        XCTAssertFalse(ids.contains("seed"), "Seed should not appear in results")
    }

    func testSimilarToTrackExcludesRecentAndDisliked() async {
        let seed = recV("seed", direction: 7)
        let disliked = recV("disliked_match", direction: 6)
        let recent = recV("recent_match", direction: 8)
        let valid = recV("valid", direction: 50)
        let catalog = [seed, disliked, recent, valid]

        let engine = makeEngine(catalog: catalog, searchService: FakeSearchService(results: catalog))
        let context = DiscoveryContext(
            dislikedTrackIDs: ["disliked_match"],
            recentlyPlayedTrackIDs: ["recent_match", "seed"],
            similarToTrackID: "seed"
        )
        let tracks = await engine.generateQueue(context: context)
        let ids = tracks.map(\.id)

        XCTAssertFalse(ids.contains("disliked_match"), "Disliked track should be excluded")
        XCTAssertFalse(ids.contains("recent_match"), "Recently played track should be excluded")
        XCTAssertFalse(ids.contains("seed"), "Seed track itself should be excluded as recent")
        XCTAssertTrue(ids.contains("valid"), "Valid track should appear")
    }
}
