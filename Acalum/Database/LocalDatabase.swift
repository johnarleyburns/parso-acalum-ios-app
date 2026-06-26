import Foundation
import SQLite3
import os

final class LocalDatabase {
    struct Error: Swift.Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private let db: OpaquePointer

    convenience init() throws {
        guard let bundlePath = Bundle.main.path(forResource: "parso_indexer", ofType: "db") else {
            throw Error(message: "parso_indexer.db not found in bundle")
        }

        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbURL = appSupport.appendingPathComponent("parso_indexer.db")

        let shouldCopy: Bool
        if !fileManager.fileExists(atPath: dbURL.path) {
            shouldCopy = true
        } else {
            let bundleDate = (try? fileManager.attributesOfItem(atPath: bundlePath)[.modificationDate]) as? Date
            let cachedDate = (try? fileManager.attributesOfItem(atPath: dbURL.path)[.modificationDate]) as? Date
            shouldCopy = {
                guard let bundle = bundleDate else { return true }
                guard let cached = cachedDate else { return true }
                return bundle > cached
            }()
        }

        if shouldCopy {
            os_log(.info, "LocalDatabase: copying DB from bundle (bundle date: %@, cached date: %@)", 
                   (try? fileManager.attributesOfItem(atPath: bundlePath)[.modificationDate]).map { "\($0)" } ?? "nil",
                   (try? fileManager.attributesOfItem(atPath: dbURL.path)[.modificationDate]).map { "\($0)" } ?? "nil")
            try? fileManager.removeItem(at: dbURL)
            try fileManager.copyItem(atPath: bundlePath, toPath: dbURL.path)
        }

        try self.init(fileURL: dbURL)
    }

    init(fileURL: URL) throws {
        var db: OpaquePointer?
        let rc = sqlite3_open_v2(fileURL.path, &db, SQLITE_OPEN_READONLY, nil)
        guard rc == SQLITE_OK, let db else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let db { sqlite3_close(db) }
            throw Error(message: "Failed to open database (rc=\(rc)): \(msg)")
        }
        self.db = db
    }

    deinit {
        sqlite3_close(db)
    }

    /// Whether the most recent `loadTracks()` found the indexer's listenability
    /// columns and applied the default-stream filter. Old DBs report `false`.
    private(set) var listenabilityFilteringEnabled = false

    /// Detects the indexer's listenability schema via `PRAGMA table_info`.
    /// The checked app resource can be stale before the pre-build copy runs, so
    /// we never assume the columns exist.
    func hasListenabilityColumns() -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info('tracks')", -1, &stmt, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(stmt) }
        var found = Set<String>()
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let namePtr = sqlite3_column_text(stmt, 1) {
                found.insert(String(cString: namePtr))
            }
        }
        return found.contains("listenability_decision") && found.contains("listenability_stream")
    }

    func loadTracks() throws -> [TrackVectorRecord] {
        let hasListenability = hasListenabilityColumns()
        listenabilityFilteringEnabled = hasListenability

        let listenabilitySelect = hasListenability
            ? """
            ,
                   t.listenability_score, t.listenability_tier,
                   t.listenability_decision, t.listenability_stream,
                   t.listenability_reasons, t.listenability_components
            """
            : ""

        // Default stream gate: completed, indexer-included, default stream only.
        // Longform candidates and excluded rows never enter the default catalog.
        let listenabilityWhere = hasListenability
            ? """

              AND t.listenability_decision = 'include'
              AND t.listenability_stream = 'default'
            """
            : ""

        let sql = """
            SELECT t.id, t.title, t.duration, t.download_url,
                   a.ia_identifier, a.title AS album_title, a.creator, a.art_url,
                   te.clap,
                   t.tags, a.subjects, a.genres\(listenabilitySelect)
            FROM tracks t
            JOIN albums a ON t.album_id = a.ia_identifier
            JOIN track_embeddings te ON t.id = te.track_id
            WHERE t.status = 'completed'\(listenabilityWhere)
            """

        if hasListenability {
            os_log(.info, "LocalDatabase: listenability columns present — filtering to include/default stream")
        } else {
            os_log(.info, "LocalDatabase: listenability columns absent — loading without listenability filter (old DB fallback)")
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw Error(message: "Query prepare failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        defer { sqlite3_finalize(stmt) }

        var records: [TrackVectorRecord] = []
        records.reserveCapacity(hasListenability ? 16000 : 8000)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let trackID = Int(sqlite3_column_int64(stmt, 0))
            let title = String(cString: sqlite3_column_text(stmt, 1))
            let duration = sqlite3_column_double(stmt, 2)

            let downloadURL: URL? = sqlite3_column_text(stmt, 3)
                .map { String(cString: $0) }
                .flatMap(URL.init(string:))

            let iaIdentifier = String(cString: sqlite3_column_text(stmt, 4))

            let creator: String? = sqlite3_column_text(stmt, 6)
                .map { String(cString: $0) }

            let artURL: URL? = sqlite3_column_text(stmt, 7)
                .map { String(cString: $0) }
                .flatMap(URL.init(string:))

            let sourceURL = URL(string: "https://archive.org/details/\(iaIdentifier)")

            let clapBlob = sqlite3_column_blob(stmt, 8)
            let clapBytes = sqlite3_column_bytes(stmt, 8)

            let clapVector: Embedding512 = {
                guard clapBytes == 1024, let blob = clapBlob else { return .zero }
                let data = Data(bytes: blob, count: Int(clapBytes))
                let values = VectorMath.decodeFloat16Blob(data)
                return (try? Embedding512(values: values)) ?? .zero
            }()

            let tags: [String]? = sqlite3_column_text(stmt, 9)
                .map { String(cString: $0) }
                .map { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }

            let albumTitle: String? = sqlite3_column_text(stmt, 5)
                .map { String(cString: $0) }

            let albumSubjects: String? = sqlite3_column_text(stmt, 10)
                .map { String(cString: $0) }

            let albumGenres: String? = sqlite3_column_text(stmt, 11)
                .map { String(cString: $0) }

            var listenScore: Double?
            var listenTier: String?
            var listenDecision: String?
            var listenStream: String?
            var listenReasons: [String] = []
            var listenComponents: [String: Double] = [:]

            if hasListenability {
                if sqlite3_column_type(stmt, 12) != SQLITE_NULL {
                    listenScore = sqlite3_column_double(stmt, 12)
                }
                listenTier = sqlite3_column_text(stmt, 13).map { String(cString: $0) }
                listenDecision = sqlite3_column_text(stmt, 14).map { String(cString: $0) }
                listenStream = sqlite3_column_text(stmt, 15).map { String(cString: $0) }
                listenReasons = Self.decodeStringArray(sqlite3_column_text(stmt, 16).map { String(cString: $0) })
                listenComponents = Self.decodeDoubleMap(sqlite3_column_text(stmt, 17).map { String(cString: $0) })
            }

            records.append(TrackVectorRecord(
                id: String(trackID),
                title: title,
                composer: creator,
                performer: nil,
                clapVector: clapVector,
                tags: tags,
                albumTitle: albumTitle,
                albumSubjects: albumSubjects,
                albumGenres: albumGenres,
                durationSeconds: duration > 0 ? duration : nil,
                sourceURL: sourceURL,
                audioURL: downloadURL,
                artURL: artURL,
                listenabilityScore: listenScore,
                listenabilityTier: listenTier,
                listenabilityDecision: listenDecision,
                listenabilityStream: listenStream,
                listenabilityReasons: listenReasons,
                listenabilityComponents: listenComponents
            ))
        }

        return records
    }

    /// Parses an indexer JSON array of strings, e.g. `["has_audio_url"]`.
    private static func decodeStringArray(_ json: String?) -> [String] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    /// Parses an indexer JSON object of doubles, e.g. `{"duration":1,"album_shape":0.84}`.
    private static func decodeDoubleMap(_ json: String?) -> [String: Double] {
        guard let json, let data = json.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }
}
