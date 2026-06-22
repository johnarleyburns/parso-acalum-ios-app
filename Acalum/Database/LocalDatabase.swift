import Foundation
import SQLite3

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

        if !fileManager.fileExists(atPath: dbURL.path) {
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

    func loadTracks() throws -> [TrackVectorRecord] {
        let sql = """
            SELECT t.id, t.title, t.duration, t.download_url,
                   a.ia_identifier, a.title AS album_title, a.creator, a.art_url,
                   te.clap
            FROM tracks t
            JOIN albums a ON t.album_id = a.ia_identifier
            JOIN track_embeddings te ON t.id = te.track_id
            WHERE t.status = 'completed'
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw Error(message: "Query prepare failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        defer { sqlite3_finalize(stmt) }

        var records: [TrackVectorRecord] = []
        records.reserveCapacity(8000)

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

            records.append(TrackVectorRecord(
                id: String(trackID),
                title: title,
                composer: creator,
                performer: nil,
                clapVector: clapVector,
                tags: nil,
                durationSeconds: duration > 0 ? duration : nil,
                sourceURL: sourceURL,
                audioURL: downloadURL,
                artURL: artURL
            ))
        }

        return records
    }
}
