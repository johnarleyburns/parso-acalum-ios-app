import Combine
import Foundation
import os

@MainActor
final class DownloadManager: ObservableObject {
    @Published var downloadedTrackIDs: Set<String> = []

    private let networkMonitor: NetworkMonitor
    private let maxCacheBytes: Int64 = 500_000_000
    private var manifest: [String: CacheEntry] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private let fileManager = FileManager.default

    private var cacheRoot: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Acalum", isDirectory: true)
    }

    private var manifestURL: URL {
        cacheRoot.appendingPathComponent("manifest.json")
    }

    struct CacheEntry: Codable {
        let trackID: String
        var audioURL: String
        var artURL: String?
        var audioSize: Int64
        var artSize: Int64
        var downloadedAt: Date
        var lastAccessedAt: Date
    }

    init(networkMonitor: NetworkMonitor) {
        self.networkMonitor = networkMonitor
        setupCacheDirectory()
        loadManifest()
        self.downloadedTrackIDs = Set(manifest.keys)

        NotificationCenter.default
            .publisher(for: .acalumFavoritesChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncWithFavorites()
            }
            .store(in: &cancellables)
    }

    func localAudioURL(for trackID: String) -> URL? {
        guard manifest[trackID] != nil else { return nil }
        let url = cacheRoot.appendingPathComponent("\(trackID).mp3")
        guard fileManager.fileExists(atPath: url.path) else {
            removeFromManifest(trackID)
            return nil
        }
        manifest[trackID]?.lastAccessedAt = Date()
        saveManifest()
        return url
    }

    func localArtURL(for trackID: String) -> URL? {
        guard let entry = manifest[trackID], entry.artURL != nil else { return nil }
        let url = cacheRoot.appendingPathComponent("\(trackID)_art.jpg")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        manifest[trackID]?.lastAccessedAt = Date()
        saveManifest()
        return url
    }

    func currentCacheBytes() -> Int64 {
        manifest.values.reduce(0) { $0 + $1.audioSize + $1.artSize }
    }

    private func syncWithFavorites() {
        let favorites = LocalStore.loadFavorites()
        let toAdd = favorites.subtracting(downloadedTrackIDs)
        let toRemove = downloadedTrackIDs.subtracting(favorites)

        for id in toRemove {
            removeTrack(id)
        }

        for id in toAdd {
            enqueueDownload(id)
        }
    }

    private func enqueueDownload(_ trackID: String) {
        guard networkMonitor.isConnected else {
            os_log(.info, "DownloadManager: skipping download for %{public}@ — offline", trackID)
            return
        }
        guard downloadTasks[trackID] == nil else { return }

        downloadTasks[trackID] = Task { [weak self] in
            guard let self else { return }
            await self.downloadTrack(trackID)
            self.downloadTasks.removeValue(forKey: trackID)
        }
    }

    private func downloadTrack(_ trackID: String) async {
        guard let catalog = try? LocalDatabase().loadTracks().first(where: { $0.id == trackID }) else {
            os_log(.error, "DownloadManager: track %{public}@ not found in catalog", trackID)
            return
        }

        guard let audioURL = catalog.audioURL else {
            os_log(.error, "DownloadManager: no audio URL for track %{public}@", trackID)
            return
        }

        var entry = CacheEntry(
            trackID: trackID,
            audioURL: audioURL.absoluteString,
            artURL: catalog.artURL?.absoluteString,
            audioSize: 0,
            artSize: 0,
            downloadedAt: Date(),
            lastAccessedAt: Date()
        )

        os_log(.info, "DownloadManager: downloading audio for track %{public}@", trackID)
        if let audioSize = await downloadFile(from: audioURL, to: "\(trackID).mp3") {
            entry.audioSize = audioSize
        } else {
            os_log(.error, "DownloadManager: audio download failed for track %{public}@", trackID)
            return
        }

        if let artURL = catalog.artURL {
            os_log(.info, "DownloadManager: downloading art for track %{public}@", trackID)
            if let artSize = await downloadFile(from: artURL, to: "\(trackID)_art.jpg") {
                entry.artSize = artSize
            }
        }

        manifest[trackID] = entry
        evictIfNeeded()
        saveManifest()

        downloadedTrackIDs.insert(trackID)

        os_log(.info, "DownloadManager: track %{public}@ downloaded (audio: %{public}d bytes, art: %{public}d bytes)", trackID, entry.audioSize, entry.artSize)
    }

    private func downloadFile(from url: URL, to filename: String) async -> Int64? {
        let destURL = cacheRoot.appendingPathComponent(filename)

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: url)

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                os_log(.error, "DownloadManager: HTTP %{public}d for %{public}@", httpResponse.statusCode, url.absoluteString)
                return nil
            }

            try? fileManager.removeItem(at: destURL)
            try fileManager.moveItem(at: tempURL, to: destURL)

            let attrs = try fileManager.attributesOfItem(atPath: destURL.path)
            return (attrs[.size] as? Int64) ?? 0
        } catch {
            os_log(.error, "DownloadManager: download error for %{public}@: %{public}@", url.absoluteString, error.localizedDescription)
            return nil
        }
    }

    private func removeTrack(_ trackID: String) {
        os_log(.info, "DownloadManager: removing track %{public}@ (unfavorited)", trackID)
        try? fileManager.removeItem(at: cacheRoot.appendingPathComponent("\(trackID).mp3"))
        try? fileManager.removeItem(at: cacheRoot.appendingPathComponent("\(trackID)_art.jpg"))
        removeFromManifest(trackID)
        downloadedTrackIDs.remove(trackID)
    }

    private func removeFromManifest(_ trackID: String) {
        manifest.removeValue(forKey: trackID)
        saveManifest()
    }

    private func evictIfNeeded() {
        var used = currentCacheBytes()
        guard used > maxCacheBytes else { return }

        let sorted = manifest.values.sorted { $0.lastAccessedAt < $1.lastAccessedAt }

        for entry in sorted {
            guard used > maxCacheBytes else { break }
            os_log(.info, "DownloadManager: evicting track %{public}@ (cache exceeded)", entry.trackID)
            try? fileManager.removeItem(at: cacheRoot.appendingPathComponent("\(entry.trackID).mp3"))
            try? fileManager.removeItem(at: cacheRoot.appendingPathComponent("\(entry.trackID)_art.jpg"))
            manifest.removeValue(forKey: entry.trackID)
            downloadedTrackIDs.remove(entry.trackID)
            used = currentCacheBytes()
        }
        saveManifest()
    }

    private func setupCacheDirectory() {
        try? fileManager.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL),
              let entries = try? JSONDecoder().decode([CacheEntry].self, from: data) else { return }
        manifest = Dictionary(uniqueKeysWithValues: entries.map { ($0.trackID, $0) })
        downloadedTrackIDs = Set(manifest.keys)
        os_log(.info, "DownloadManager: loaded manifest with %d entries, %{public}d bytes", manifest.count, currentCacheBytes())
    }

    private func saveManifest() {
        let entries = Array(manifest.values)
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }
}
