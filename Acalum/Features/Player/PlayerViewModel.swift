import Combine
import Foundation

struct MoodSignature: Equatable {
    let pillIDs: [String]
    let prompt: String
}

struct MoodTransition: Equatable {
    let fromSignature: MoodSignature
    let toSignature: MoodSignature
    let startedAt: Date
}

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
    @Published private(set) var moreLikeThisTrackID: String?
    @Published private(set) var moodTransition: MoodTransition?
    @Published private(set) var canGoPrevious: Bool = !PlaybackHistoryStore.isEmpty

    private enum QueueSizing {
        static let visibleUpNextLimit = 4
        static let targetUpcomingCount = 8
        static let appendOnAdvanceCount = 1
    }

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
    /// Monotonic token guarding async queue (re)generation. Each authoritative
    /// queue operation bumps it synchronously before awaiting; a task whose
    /// captured token no longer matches has been superseded and must discard
    /// its result instead of clobbering newer state. Prevents a stale
    /// `refreshQueue`/refill from overwriting a later `replaceQueueAndPlay`.
    private var queueGeneration = 0
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

        audioService.onSkipRequested = { [weak self] in
            self?.skip()
        }

        audioService.onPreviousRequested = { [weak self] in
            guard let self, !PlaybackHistoryStore.isEmpty else { return false }
            self.previous()
            return true
        }

        audioService.onInterruptionBegan = { [weak self] in
            self?.audioService.pause()
        }

        audioService.onInterruptionEnded = { [weak self] in
            guard let self, let track = self.currentTrack else { return }
            self.audioService.play(url: self.resolveAudioURL(for: track), transition: .fadeIn(0.35))
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
            surface(track, transition: .fadeIn(0.35))
        case .playing:
            audioService.pause()
        case .paused:
            audioService.resume()
        case .loading:
            break
        case .failed:
            guard let track = currentTrack else { return }
            surface(track, transition: .fadeIn(0.35))
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
            surface(next, transition: .fadeOutIn(out: 0.55, in: 0.75))
            publishUpNext()
            refillStableQueueIfNeeded()
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
            surface(next, transition: .fadeOutIn(out: 0.55, in: 0.75))
            publishUpNext()
            refillStableQueueIfNeeded(appending: index + 1)
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

    func moreLikeThis() {
        guard let track = currentTrack else { return }
        feedbackTracker.log(type: .moreLikeThis, trackID: track.id, selectedPillIDs: committedPills.map(\.id))
        moreLikeThisTrackID = track.id
        HapticFeedback.medium()

        let generation = beginQueueGeneration()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let context = self.makeContext()
            let tracks = await self.queueService.generateQueue(context: context)
            guard generation == self.queueGeneration else { return }
            let keepCount = min(2, self.queue.upcomingCount)
            let existing = Array(self.queue.upcoming.prefix(keepCount))
            let replaceCount = max(0, QueueSizing.targetUpcomingCount - keepCount)
            let fresh = Array(tracks.prefix(replaceCount))
            self.queue.replaceUpcoming(existing + fresh)
            self.publishUpNext()
        }
    }

    func togglePill(_ pill: Pill) {
        if draftPills.contains(pill) { draftPills.remove(pill) } else { draftPills.insert(pill) }
        HapticFeedback.selection()
    }

    /// Logs that the user opened a track's Internet Archive source page.
    func recordSourceOpened(_ track: Track) {
        feedbackTracker.log(type: .sourceOpened, trackID: track.id, selectedPillIDs: committedPills.map(\.id))
    }

    func submitPrompt() { applyMood(startNow: false) }

    func applyMood(startNow: Bool = false) {
        let fromSignature = MoodSignature(
            pillIDs: committedPills.map(\.id).sorted(),
            prompt: committedPrompt
        )
        committedPills = draftPills
        committedPrompt = draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let toSignature = MoodSignature(
            pillIDs: committedPills.map(\.id).sorted(),
            prompt: committedPrompt
        )
        if fromSignature != toSignature {
            moodTransition = MoodTransition(fromSignature: fromSignature, toSignature: toSignature, startedAt: Date())
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.moodTransition = nil
            }
        }
        LocalStore.saveLastPillIDs(committedPills.map(\.id))
        LocalStore.saveLastPrompt(committedPrompt.isEmpty ? nil : committedPrompt)
        SeenHistoryStore.clear()
        moreLikeThisTrackID = nil
        if startNow {
            replaceQueueAndPlay()
        } else if currentTrack == nil {
            // Nothing is playing yet (e.g. first run) — start the stream rather
            // than silently staging upcoming tracks behind an empty Now Playing.
            replaceQueueAndPlay()
        } else {
            refreshUpcoming()
        }
    }

    func shakeItUp() {
        HapticFeedback.medium()
        draftPills = Self.randomCoherentPills(excluding: committedPills)
        draftPrompt = ""
        applyMood(startNow: true)
    }

    private static func randomCoherentPills(excluding current: Set<Pill>) -> Set<Pill> {
        func pick(_ c: PillCategory) -> Pill? { PillRegistry.all.filter { $0.category == c }.randomElement() }
        var next: Set<Pill> = []
        repeat {
            next = []
            if let s = pick(.style) { next.insert(s) }
            if Bool.random(), let snd = pick(.sound) { next.insert(snd) }
            if Bool.random(), let x = pick(Bool.random() ? .tradition : .listeningMode) { next.insert(x) }
        } while next == current || next.isEmpty
        return next
    }

    private func surface(_ track: Track, transition: AudioTransition = .immediate, recordPrevious: Bool = true) {
        // Push the outgoing track onto the persistent back stack so Previous can
        // return to it. Skipped when stepping backward (recordPrevious == false).
        if recordPrevious, let outgoing = currentTrack, outgoing.id != track.id {
            PlaybackHistoryStore.push(outgoing)
            refreshCanGoPrevious()
        }
        currentTrack = track
        audioService.play(url: resolveAudioURL(for: track), transition: transition)
        audioService.updateNowPlaying(track: track)
        feedbackTracker.log(type: .playStarted, trackID: track.id, selectedPillIDs: committedPills.map(\.id))
        SeenHistoryStore.record(track.id)
    }

    /// Plays the most recently listened track from the persistent back stack.
    /// Does not log skip/dislike feedback. Places the current track at the front
    /// of upcoming so Next returns to where the user came from. Persists history.
    func previous() {
        guard let prev = PlaybackHistoryStore.pop() else {
            refreshCanGoPrevious()
            return
        }
        HapticFeedback.light()
        if let current = currentTrack {
            queue.upcoming.insert(current, at: 0)
        }
        queue.current = prev
        surface(prev, transition: .fadeOutIn(out: 0.35, in: 0.55), recordPrevious: false)
        publishUpNext()
        refreshCanGoPrevious()
    }

    private func refreshCanGoPrevious() {
        canGoPrevious = !PlaybackHistoryStore.isEmpty
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
            offlineTrackIDs: offlineTrackIDs,
            similarToTrackID: moreLikeThisTrackID
        )
    }

    private func publishUpNext() {
        upNext = Array(queue.upcoming.prefix(QueueSizing.visibleUpNextLimit))
    }

    private func refillStableQueueIfNeeded(appending neededCount: Int = QueueSizing.appendOnAdvanceCount) {
        let deficit = max(0, QueueSizing.targetUpcomingCount - queue.upcomingCount)
        let count = max(neededCount, deficit)
        guard count > 0 else { return }

        let generation = queueGeneration
        Task { @MainActor [weak self] in
            guard let self else { return }
            let context = self.makeContext()
            let tracks = await self.queueService.generateQueue(context: context)
            guard generation == self.queueGeneration else { return }
            let limited = Array(tracks.prefix(count))
            self.queue.appendTracks(limited)
            self.publishUpNext()
        }
    }

    private func replaceQueueAndPlay() {
        let generation = beginQueueGeneration()
        let outgoing = currentTrack
        audioService.stop()
        currentTrack = nil
        if let outgoing {
            PlaybackHistoryStore.push(outgoing)
            refreshCanGoPrevious()
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let context = self.makeContext()
            let tracks = await self.queueService.generateQueue(context: context)
            guard generation == self.queueGeneration else { return }
            self.queue = PlaybackQueue(tracks: tracks)

            if let first = self.queue.current {
                self.surface(first, transition: .fadeOutIn(out: 0.9, in: 1.1))
            }
            self.publishUpNext()
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
            surface(next, transition: .fadeIn(0.35))
            publishUpNext()
            refillStableQueueIfNeeded()
        } else {
            currentTrack = nil
            refreshQueue()
        }
    }

    private func handlePlaybackFailed() {
        replaceQueueAndPlay()
    }

    /// Starts a new authoritative queue generation, invalidating any async
    /// queue task still in flight. Call synchronously before spawning the task.
    @discardableResult
    private func beginQueueGeneration() -> Int {
        queueGeneration += 1
        return queueGeneration
    }

    private func refreshQueue() {
        let generation = beginQueueGeneration()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let context = self.makeContext()
            let tracks = await self.queueService.generateQueue(context: context)
            guard generation == self.queueGeneration else { return }
            let limited = Array(tracks.prefix(QueueSizing.targetUpcomingCount))
            self.queue.appendTracks(limited)

            if self.currentTrack == nil, let next = self.queue.skipToNext() {
                self.currentTrack = next
            }
            self.publishUpNext()
            self.isInitialLoading = false
        }
    }

    private func refreshUpcoming() {
        let generation = beginQueueGeneration()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let tracks = await self.queueService.generateQueue(context: self.makeContext())
            guard generation == self.queueGeneration else { return }
            self.queue = PlaybackQueue(tracks: [self.currentTrack].compactMap { $0 } + tracks)
            self.publishUpNext()
        }
    }

    func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
