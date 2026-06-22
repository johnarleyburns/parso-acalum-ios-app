@testable import Acalum
import XCTest

final class ExactCosineVectorSearchTests: XCTestCase {
    private func makeRecord(id: String, direction: Int) -> TrackVectorRecord {
        var values = [Float](repeating: 0, count: 512)
        values[direction % 512] = 1.0
        return TrackVectorRecord(
            id: id,
            title: "Track \(id)",
            composer: nil,
            performer: nil,
            clapVector: try! Embedding512(values: values).normalized(),
            tags: nil,
            albumTitle: nil,
            albumSubjects: nil,
            albumGenres: nil,
            durationSeconds: 180,
            sourceURL: nil,
            audioURL: nil,
            artURL: nil
        )
    }

    private func makeQuery(direction: Int) -> Embedding512 {
        var values = [Float](repeating: 0, count: 512)
        values[direction % 512] = 1.0
        return try! Embedding512(values: values).normalized()
    }

    func testReturnsMostSimilarFirst() async throws {
        let catalog = [
            makeRecord(id: "a", direction: 0),
            makeRecord(id: "b", direction: 100),
            makeRecord(id: "c", direction: 200),
        ]
        let service = ExactCosineVectorSearchService(catalog: catalog)
        let query = makeQuery(direction: 0)
        let results = try await service.search(query: query, limit: 10, excluding: [])
        XCTAssertEqual(results.first?.track.id, "a")
        XCTAssertEqual(results.first?.score ?? 0, 1.0, accuracy: 1e-5)
    }

    func testRespectsLimit() async throws {
        let catalog = (0..<20).map { makeRecord(id: "\($0)", direction: $0) }
        let service = ExactCosineVectorSearchService(catalog: catalog)
        let query = makeQuery(direction: 0)
        let results = try await service.search(query: query, limit: 5, excluding: [])
        XCTAssertEqual(results.count, 5)
    }

    func testExcludesTrackIDs() async throws {
        let catalog = [
            makeRecord(id: "a", direction: 0),
            makeRecord(id: "b", direction: 0),
        ]
        let service = ExactCosineVectorSearchService(catalog: catalog)
        let query = makeQuery(direction: 0)
        let results = try await service.search(query: query, limit: 10, excluding: ["a"])
        XCTAssertFalse(results.contains(where: { $0.track.id == "a" }))
        XCTAssertEqual(results.count, 1)
    }

    func testEmptyCatalog() async throws {
        let service = ExactCosineVectorSearchService(catalog: [])
        let query = makeQuery(direction: 0)
        let results = try await service.search(query: query, limit: 10, excluding: [])
        XCTAssertTrue(results.isEmpty)
    }

    func testLimitLargerThanCatalog() async throws {
        let catalog = [
            makeRecord(id: "a", direction: 0),
            makeRecord(id: "b", direction: 1),
        ]
        let service = ExactCosineVectorSearchService(catalog: catalog)
        let query = makeQuery(direction: 0)
        let results = try await service.search(query: query, limit: 100, excluding: [])
        XCTAssertEqual(results.count, 2)
    }

    func testResultsAreSortedDescending() async throws {
        let catalog = (0..<10).map { makeRecord(id: "\($0)", direction: $0) }
        let service = ExactCosineVectorSearchService(catalog: catalog)
        let query = makeQuery(direction: 3)
        let results = try await service.search(query: query, limit: 10, excluding: [])
        for i in 0..<(results.count - 1) {
            XCTAssertGreaterThanOrEqual(results[i].score, results[i + 1].score)
        }
    }
}
