import Combine
import Foundation

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var currentTrack: Track?
    @Published var playbackState: PlaybackState = .idle
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var draftPills: Set<Pill> = []
    @Published private(set) var committedPills: Set<Pill> = []
    @Published var draftPrompt: String = ""
    @Published private(set) var committedPrompt: String = ""
    @Published var favoriteIDs: Set<String> = []
    @Published var isInitialLoading = true
    @Published private(set) var upNext: [Track] = []

    enum Sheet: Identifiable {
        case whyThis
        case trackInfo
        case settings

        var id: String { String(describing: self) }
    }
    @Published var activeSheet: Sheet?

    var pendingMoodChange: Bool {
        draftPills != committedPills ||
        draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines) != committedPrompt
    }

    private var queue: PlaybackQueue
    private let audioService: any AudioPlayerServiceProtocol
    private let feedbackTracker: FeedbackTracker
    private let queueService: QueueServiceProtocol
    let networkMonitor: NetworkMonitor
    private let downloadManager: DownloadManager?
    private var cancellables = Set<AnyCancellable>()

    var isPlaying: Bool { playbackState == .playing }

    var isFavorited: Bool {
        guard let track = currentTrack else { return false }
        return favoriteIDs.contains(track.id)
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    func seek(to time: Double) {
        audioService.seek(to: time)
    }

    init(
        audioService: any AudioPlayerServiceProtocol = AudioPlayerService(),
        feedbackTracker: FeedbackTracker = FeedbackTracker(),
        queueService: QueueServiceProtocol = MockQueueService(),
        networkMonitor: NetworkMonitor = NetworkMonitor(),
        downloadManager: DownloadManager? = nil
    ) {
        self.audioService = audioService
        self.feedbackTracker = feedbackTracker
        self.queueService = queueService
        self.networkMonitor = networkMonitor
        self.downloadManager = downloadManager
        self.queue = PlaybackQueue()
        self.currentTrack = queue.current
        self.favoriteIDs = LocalStore.loadFavorites()

        let savedPillIDs = Set(LocalStore.loadLastPillIDs())
        let restoredPills = Set(MockData.pills.filter { savedPillIDs.contains($0.id) })
        self.draftPills = restoredPills
        self.committedPills = restoredPills

        if let savedPrompt = LocalStore.loadLastPrompt() {
            self.draftPrompt = savedPrompt
            self.committedPrompt = savedPrompt
        }

        bindAudio()
        observeNetwork()
        refreshQueue()
    }

    private func observeNetwork() {
        networkMonitor.$isConnected
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self else { return }
                if connected {
                    self.handleCameOnline()
                } else {
                    self.handleWentOffline()
                }
            }
            .store(in: &cancellables)
    }

    private func handleWentOffline() {
        guard let dm = downloadManager else { return }
        if let current = currentTrack,
           dm.localAudioURL(for: current.id) == nil {
            skip()
        }
    }

    private func handleCameOnline() {
        refreshQueue()
    }

    private func bindAudio() {
        audioService.statePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$playbackState)

        audioService.currentTimePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentTime)

        audioService.durationPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$duration)

        audioService.onTrackFinished = { [weak self] in
            self?.handleTrackFinished()
        }

        audioService.onInterruptionBegan = { [weak self] in
            self?.audioService.pause()
        }

        audioService.onInterruptionEnded = { [weak self] in
            guard let self, let track = self.currentTrack else { return }
            self.audioService.play(url: self.resolveAudioURL(for: track))
            self.audioService.updateNowPlaying(track: track)
        }

        audioService.onPlaybackFailed = { [weak self] in
            self?.handlePlaybackFailed()
        }

        $currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.audioService.updateNowPlaying(track: track)
            }
            .store(in: &cancellables)
    }

    func togglePlayPause() {
        switch playbackState {
        case .idle:
            guard let track = currentTrack else { return }
            surface(track)
        case .playing:
            audioService.pause()
        case .paused:
            audioService.resume()
        case .loading:
            break
        case .failed:
            guard let track = currentTrack else { return }
            surface(track)
        }
    }

    func skip() {
        let skippedTrackID = currentTrack?.id
        feedbackTracker.log(
            type: .skipped,
            trackID: skippedTrackID,
            listenSeconds: currentTime,
            selectedPillIDs: committedPills.map(\.id)
        )
        if let skippedID = skippedTrackID {
            TasteProfileStore.recordSkipped(skippedID, listenSeconds: currentTime)
        }

        if let next = queue.skipToNext() {
            surface(next)
            upNext = queue.upcoming
        } else {
            replaceQueueAndPlay()
        }
    }

    func playFromUpNext(at index: Int) {
        let skippedTrackID = currentTrack?.id
        feedbackTracker.log(
            type: .skipped,
            trackID: skippedTrackID,
            listenSeconds: currentTime,
            selectedPillIDs: committedPills.map(\.id)
        )
        if let skippedID = skippedTrackID {
            TasteProfileStore.recordSkipped(skippedID, listenSeconds: currentTime)
        }

        if let next = queue.jumpTo(index: index) {
            surface(next)
            upNext = queue.upcoming
        }
    }

    func toggleFavorite() {
        guard let track = currentTrack else { return }
        if favoriteIDs.contains(track.id) {
            favoriteIDs.remove(track.id)
            feedbackTracker.log(type: .unfavorited, trackID: track.id, selectedPillIDs: committedPills.map(\.id))
            TasteProfileStore.removeFavorite(track.id)
        } else {
            favoriteIDs.insert(track.id)
            feedbackTracker.log(type: .favorited, trackID: track.id, selectedPillIDs: committedPills.map(\.id))
            TasteProfileStore.recordFavorite(track.id)
        }
        LocalStore.saveFavorites(favoriteIDs)
    }

    func togglePill(_ pill: Pill) {
        if draftPills.contains(pill) { draftPills.remove(pill) } else { draftPills.insert(pill) }
        HapticFeedback.selection()
    }

    func submitPrompt() { applyMood(startNow: true) }

    func applyMood(startNow: Bool = false) {
        committedPills = draftPills
        committedPrompt = draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        LocalStore.saveLastPillIDs(committedPills.map(\.id))
        LocalStore.saveLastPrompt(committedPrompt.isEmpty ? nil : committedPrompt)
        SeenHistoryStore.clear()
        if startNow { replaceQueueAndPlay() } else { refreshUpcoming() }
    }

    func shakeItUp() {
        HapticFeedback.medium()
        draftPills = Self.randomCoherentPills(excluding: committedPills)
        draftPrompt = ""
        applyMood(startNow: true)
    }

    private static func randomCoherentPills(excluding current: Set<Pill>) -> Set<Pill> {
        func pick(_ c: PillCategory) -> Pill? { MockData.pills.filter { $0.category == c }.randomElement() }
        var next: Set<Pill> = []
        repeat {
            next = []
            if let m = pick(.mood) { next.insert(m) }
            if Bool.random(), let i = pick(.instrument) { next.insert(i) }
            if Bool.random(), let x = pick(Bool.random() ? .context : .era) { next.insert(x) }
        } while next == current || next.isEmpty
        return next
    }

    private func surface(_ track: Track) {
        currentTrack = track
        audioService.play(url: resolveAudioURL(for: track))
        audioService.updateNowPlaying(track: track)
        feedbackTracker.log(type: .playStarted, trackID: track.id, selectedPillIDs: committedPills.map(\.id))
        SeenHistoryStore.record(track.id)
    }

    private var offlineTrackIDs: Set<String>? {
        guard let dm = downloadManager, !networkMonitor.isConnected else { return nil }
        return dm.downloadedTrackIDs
    }

    private func makeContext() -> DiscoveryContext {
        DiscoveryContext(
            prompt: committedPrompt.isEmpty ? nil : committedPrompt,
            selectedPills: Array(committedPills),
            dislikedTrackIDs: [],
            favoriteTrackIDs: Array(favoriteIDs),
            recentlyPlayedTrackIDs: Array(Set(queue.history.map(\.id)).union(SeenHistoryStore.recentIDs)),
            offlineTrackIDs: offlineTrackIDs
        )
    }

    private func replaceQueueAndPlay() {
        audioService.stop()
        currentTrack = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            let context = self.makeContext()
            let tracks = await self.queueService.generateQueue(context: context)
            self.queue = PlaybackQueue(tracks: tracks)

            if let first = self.queue.current {
                self.surface(first)
            }
            self.upNext = self.queue.upcoming
        }
    }

    private func resolveAudioURL(for track: Track) -> URL {
        if let dm = downloadManager,
           !networkMonitor.isConnected,
           let local = dm.localAudioURL(for: track.id) {
            return local
        }
        return track.audioURL
    }

    private func handleTrackFinished() {
        feedbackTracker.log(
            type: .playCompleted,
            trackID: currentTrack?.id,
            listenSeconds: duration,
            selectedPillIDs: committedPills.map(\.id)
        )
        if let completedID = currentTrack?.id {
            TasteProfileStore.recordCompleted(completedID)
        }

        if let next = queue.skipToNext() {
            surface(next)
            upNext = queue.upcoming
        } else {
            currentTrack = nil
            refreshQueue()
        }
    }

    private func handlePlaybackFailed() {
        replaceQueueAndPlay()
    }

    private func refreshQueue() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let context = self.makeContext()
            let tracks = await self.queueService.generateQueue(context: context)
            self.queue.appendTracks(tracks)

            if self.currentTrack == nil, let next = self.queue.skipToNext() {
                self.currentTrack = next
            }
            self.upNext = self.queue.upcoming
            self.isInitialLoading = false
        }
    }

    private func refreshUpcoming() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let tracks = await self.queueService.generateQueue(context: self.makeContext())
            self.queue = PlaybackQueue(tracks: [self.currentTrack].compactMap { $0 } + tracks)
            self.upNext = self.queue.upcoming
        }
    }

    func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
