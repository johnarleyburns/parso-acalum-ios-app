@testable import Acalum
import SQLite3
import XCTest

final class LocalDatabaseTests: XCTestCase {
    func testInitThrowsForNonexistentFile() {
        let url = URL(fileURLWithPath: "/nonexistent/test.db")
        XCTAssertThrowsError(try LocalDatabase(fileURL: url))
    }

    func testLoadTracksReturnsExpectedCount() throws {
        let url = try makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: url) }

        let db = try LocalDatabase(fileURL: url)
        let records = try db.loadTracks()
        XCTAssertEqual(records.count, 3)
    }

    func testLoadTracksMapsFields() throws {
        let url = try makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: url) }

        let db = try LocalDatabase(fileURL: url)
        let records = try db.loadTracks()

        let bach = records.first(where: { $0.id == "1" })
        XCTAssertNotNil(bach)
        XCTAssertEqual(bach?.title, "Brandenburg Concerto No. 3")
        XCTAssertEqual(bach?.composer, "J.S. Bach")
        XCTAssertEqual(bach?.durationSeconds, 642.0)
        XCTAssertEqual(bach?.clapVector.values.count, 512)
        XCTAssertEqual(bach?.sourceURL?.absoluteString, "https://archive.org/details/bach_brandenburg")
        XCTAssertNotNil(bach?.audioURL)
    }

    func testLoadTracksExcludesNonCompleted() throws {
        let url = try makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: url) }

        let db = try LocalDatabase(fileURL: url)
        let records = try db.loadTracks()
        XCTAssertFalse(records.contains(where: { $0.id == "4" }))
    }

    func testLoadTracksClapVectorIsNonZero() throws {
        let url = try makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: url) }

        let db = try LocalDatabase(fileURL: url)
        let records = try db.loadTracks()
        for record in records {
            XCTAssertEqual(record.clapVector.values.count, 512)
            let norm = record.clapVector.l2Norm()
            XCTAssertGreaterThan(norm, 0, "Expected non-zero norm for track \(record.id)")
        }
    }

    // MARK: Listenability

    func testOldDatabaseFallsBackWithoutListenabilityFilter() throws {
        let url = try makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: url) }

        let db = try LocalDatabase(fileURL: url)
        XCTAssertFalse(db.hasListenabilityColumns())
        let records = try db.loadTracks()
        XCTAssertFalse(db.listenabilityFilteringEnabled, "Old DB should report listenability filtering disabled")
        XCTAssertEqual(records.count, 3, "Fallback should still load all completed tracks")
        XCTAssertNil(records.first?.listenabilityScore)
    }

    func testListenabilityColumnsDetectedAndFiltered() throws {
        let url = try makeListenabilityDatabase()
        defer { try? FileManager.default.removeItem(at: url) }

        let db = try LocalDatabase(fileURL: url)
        XCTAssertTrue(db.hasListenabilityColumns())
        let records = try db.loadTracks()
        XCTAssertTrue(db.listenabilityFilteringEnabled)

        let ids = Set(records.map(\.id))
        XCTAssertTrue(ids.contains("1"), "include/default should load")
        XCTAssertFalse(ids.contains("2"), "excluded should be filtered out")
        XCTAssertFalse(ids.contains("3"), "longform_candidate should be filtered out")
        XCTAssertEqual(records.count, 1)
    }

    func testListenabilityFieldsAndJSONParsed() throws {
        let url = try makeListenabilityDatabase()
        defer { try? FileManager.default.removeItem(at: url) }

        let db = try LocalDatabase(fileURL: url)
        let records = try db.loadTracks()
        let rec = records.first(where: { $0.id == "1" })
        XCTAssertNotNil(rec)
        XCTAssertEqual(rec?.listenabilityScore ?? 0, 0.8658, accuracy: 0.0001)
        XCTAssertEqual(rec?.listenabilityTier, "excellent")
        XCTAssertEqual(rec?.listenabilityDecision, "include")
        XCTAssertEqual(rec?.listenabilityStream, "default")
        XCTAssertEqual(rec?.listenabilityReasons, ["has_audio_url"])
        XCTAssertEqual(rec?.listenabilityComponents["duration"] ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(rec?.listenabilityComponents["album_shape"] ?? 0, 0.844, accuracy: 0.001)
    }

    private func makeListenabilityDatabase() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_listen_\(UUID().uuidString).db")

        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else {
            throw NSError(domain: "test", code: 1)
        }
        defer { sqlite3_close(db) }

        try exec(db, """
            CREATE TABLE tracks (
                id INTEGER PRIMARY KEY, album_id TEXT, title TEXT, duration REAL,
                download_url TEXT, status TEXT, tags TEXT,
                listenability_score REAL, listenability_tier TEXT,
                listenability_decision TEXT, listenability_stream TEXT,
                listenability_reasons TEXT, listenability_components TEXT)
            """)
        try exec(db, """
            CREATE TABLE albums (ia_identifier TEXT PRIMARY KEY, title TEXT, creator TEXT, art_url TEXT, subjects TEXT, genres TEXT)
            """)
        try exec(db, """
            CREATE TABLE track_embeddings (track_id INTEGER PRIMARY KEY, clap BLOB, dim INTEGER, dtype TEXT)
            """)

        try exec(db, "INSERT INTO albums VALUES ('alb', 'Album', 'Composer', NULL, NULL, NULL)")

        let comp = "{\"album_shape\":0.8443586419753086,\"content_type\":0.62,\"duration\":1,\"metadata_hygiene\":1,\"technical_quality\":0.98}"
        // include/default
        try exec(db, """
            INSERT INTO tracks (id, album_id, title, duration, download_url, status, tags, listenability_score, listenability_tier, listenability_decision, listenability_stream, listenability_reasons, listenability_components)
            VALUES (1, 'alb', 'Good Track', 220.0, 'https://archive.org/download/alb/1.mp3', 'completed', NULL, 0.8658, 'excellent', 'include', 'default', '["has_audio_url"]', '\(comp)')
            """)
        // excluded
        try exec(db, """
            INSERT INTO tracks (id, album_id, title, duration, download_url, status, listenability_score, listenability_tier, listenability_decision, listenability_stream)
            VALUES (2, 'alb', 'Speech Clip', 8.0, 'https://archive.org/download/alb/2.mp3', 'completed', 0.10, 'unusable', 'exclude', 'excluded')
            """)
        // longform candidate
        try exec(db, """
            INSERT INTO tracks (id, album_id, title, duration, download_url, status, listenability_score, listenability_tier, listenability_decision, listenability_stream)
            VALUES (3, 'alb', 'Long Symphony', 3600.0, 'https://archive.org/download/alb/3.mp3', 'completed', 0.60, 'good', 'demote', 'longform_candidate')
            """)

        let blob = makeNormalizedF16Blob(dimension: 512)
        try execBinding(db, "INSERT INTO track_embeddings VALUES (1, ?, 512, 'f16')", blob: blob)
        try execBinding(db, "INSERT INTO track_embeddings VALUES (2, ?, 512, 'f16')", blob: blob)
        try execBinding(db, "INSERT INTO track_embeddings VALUES (3, ?, 512, 'f16')", blob: blob)

        return url
    }

    private func makeTempDatabase() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).db")

        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else {
            throw NSError(domain: "test", code: 1)
        }
        defer { sqlite3_close(db) }

        try exec(db, """
            CREATE TABLE tracks (id INTEGER PRIMARY KEY, album_id TEXT, title TEXT, duration REAL, download_url TEXT, status TEXT, tags TEXT)
            """)
        try exec(db, """
            CREATE TABLE albums (ia_identifier TEXT PRIMARY KEY, title TEXT, creator TEXT, art_url TEXT, subjects TEXT, genres TEXT)
            """)
        try exec(db, """
            CREATE TABLE track_embeddings (track_id INTEGER PRIMARY KEY, clap BLOB, dim INTEGER, dtype TEXT)
            """)

        try exec(db, """
            INSERT INTO albums VALUES ('bach_brandenburg', 'Brandenburg Concertos', 'J.S. Bach', 'https://archive.org/services/img/bach_brandenburg', NULL, NULL)
            """)
        try exec(db, """
            INSERT INTO albums VALUES ('vivaldi_four_seasons', 'The Four Seasons', 'A. Vivaldi', NULL, NULL, NULL)
            """)

        try exec(db, """
            INSERT INTO tracks VALUES (1, 'bach_brandenburg', 'Brandenburg Concerto No. 3', 642.0, 'https://archive.org/download/bach_brandenburg/bach_01.mp3', 'completed', NULL)
            """)
        try exec(db, """
            INSERT INTO tracks VALUES (2, 'bach_brandenburg', 'Brandenburg Concerto No. 1', 610.0, 'https://archive.org/download/bach_brandenburg/bach_02.mp3', 'completed', NULL)
            """)
        try exec(db, """
            INSERT INTO tracks VALUES (3, 'vivaldi_four_seasons', 'Spring', 630.0, 'https://archive.org/download/vivaldi_four_seasons/vivaldi_spring.mp3', 'completed', NULL)
            """)
        try exec(db, """
            INSERT INTO tracks VALUES (4, 'vivaldi_four_seasons', 'Winter', 0, NULL, 'pending', NULL)
            """)

        let blob = makeNormalizedF16Blob(dimension: 512)
        try execBinding(db, "INSERT INTO track_embeddings VALUES (1, ?, 512, 'f16')", blob: blob)
        try execBinding(db, "INSERT INTO track_embeddings VALUES (2, ?, 512, 'f16')", blob: blob)
        try execBinding(db, "INSERT INTO track_embeddings VALUES (3, ?, 512, 'f16')", blob: blob)

        return url
    }

    private func exec(_ db: OpaquePointer, _ sql: String) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "test", code: 3, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    private func execBinding(_ db: OpaquePointer, _ sql: String, blob: Data) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        defer { sqlite3_finalize(stmt) }

        _ = blob.withUnsafeBytes { buf in
            sqlite3_bind_blob(stmt, 1, buf.baseAddress, Int32(blob.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "test", code: 3, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    private func makeNormalizedF16Blob(dimension: Int) -> Data {
        let value: Float = 1.0 / sqrt(Float(dimension))
        let f16Values = [Float16](repeating: Float16(value), count: dimension)
        return f16Values.withUnsafeBytes { Data($0) }
    }
}
