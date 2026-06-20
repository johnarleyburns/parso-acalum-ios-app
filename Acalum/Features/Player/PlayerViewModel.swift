import Combine
import Foundation

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var currentTrack: Track?
    @Published var playbackState: PlaybackState = .idle
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var selectedPills: Set<Pill> = []
    @Published var prompt: String = ""
    @Published var favoriteIDs: Set<String> = []

    enum Sheet: Identifiable {
        case whyThis
        case trackInfo
        case settings

        var id: String { String(describing: self) }
    }
    @Published var activeSheet: Sheet?

    private var queue: PlaybackQueue
    private let audioService: AudioPlayerService
    private let feedbackTracker: FeedbackTracker
    private let queueService: QueueServiceProtocol
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

    init(
        audioService: AudioPlayerService = AudioPlayerService(),
        feedbackTracker: FeedbackTracker = FeedbackTracker(),
        queueService: QueueServiceProtocol = MockQueueService()
    ) {
        self.audioService = audioService
        self.feedbackTracker = feedbackTracker
        self.queueService = queueService
        self.queue = PlaybackQueue(tracks: MockData.tracks)
        self.currentTrack = queue.current
        self.favoriteIDs = LocalStore.loadFavorites()

        if let savedPrompt = LocalStore.loadLastPrompt() {
            self.prompt = savedPrompt
        }
        let savedPillIDs = Set(LocalStore.loadLastPillIDs())
        self.selectedPills = Set(MockData.pills.filter { savedPillIDs.contains($0.id) })

        bindAudio()
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
    }

    func togglePlayPause() {
        switch playbackState {
        case .idle:
            guard let track = currentTrack else { return }
            audioService.play(url: track.audioURL)
            feedbackTracker.log(type: .playStarted, trackID: track.id, selectedPillIDs: selectedPills.map(\.id))
        case .playing:
            audioService.pause()
        case .paused:
            audioService.resume()
        case .loading:
            break
        case .failed:
            guard let track = currentTrack else { return }
            audioService.play(url: track.audioURL)
        }
    }

    func skip() {
        let skippedTrackID = currentTrack?.id
        feedbackTracker.log(
            type: .skipped,
            trackID: skippedTrackID,
            listenSeconds: currentTime,
            selectedPillIDs: selectedPills.map(\.id)
        )

        if let next = queue.skipToNext() {
            currentTrack = next
            audioService.play(url: next.audioURL)
            feedbackTracker.log(type: .playStarted, trackID: next.id, selectedPillIDs: selectedPills.map(\.id))
        } else {
            audioService.stop()
            currentTrack = nil
            refreshQueue()
        }
    }

    func toggleFavorite() {
        guard let track = currentTrack else { return }
        if favoriteIDs.contains(track.id) {
            favoriteIDs.remove(track.id)
            feedbackTracker.log(type: .unfavorited, trackID: track.id, selectedPillIDs: selectedPills.map(\.id))
        } else {
            favoriteIDs.insert(track.id)
            feedbackTracker.log(type: .favorited, trackID: track.id, selectedPillIDs: selectedPills.map(\.id))
        }
        LocalStore.saveFavorites(favoriteIDs)
    }

    func togglePill(_ pill: Pill) {
        if selectedPills.contains(pill) {
            selectedPills.remove(pill)
            feedbackTracker.log(type: .pillRemoved, selectedPillIDs: selectedPills.map(\.id))
        } else {
            selectedPills.insert(pill)
            feedbackTracker.log(type: .pillSelected, selectedPillIDs: selectedPills.map(\.id))
        }
        LocalStore.saveLastPillIDs(selectedPills.map(\.id))
        refreshQueue()
    }

    func submitPrompt() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        feedbackTracker.log(type: .promptChanged, prompt: trimmed, selectedPillIDs: selectedPills.map(\.id))
        LocalStore.saveLastPrompt(trimmed)
        refreshQueue()
    }

    private func handleTrackFinished() {
        feedbackTracker.log(
            type: .playCompleted,
            trackID: currentTrack?.id,
            listenSeconds: duration,
            selectedPillIDs: selectedPills.map(\.id)
        )

        if let next = queue.skipToNext() {
            currentTrack = next
            audioService.play(url: next.audioURL)
            feedbackTracker.log(type: .playStarted, trackID: next.id, selectedPillIDs: selectedPills.map(\.id))
        } else {
            currentTrack = nil
            refreshQueue()
        }
    }

    private func refreshQueue() {
        Task {
            let context = DiscoveryContext(
                prompt: prompt.isEmpty ? nil : prompt,
                selectedPills: Array(selectedPills),
                dislikedTrackIDs: [],
                favoriteTrackIDs: Array(favoriteIDs),
                recentlyPlayedTrackIDs: queue.history.map(\.id)
            )
            let tracks = await queueService.generateQueue(context: context)
            queue.appendTracks(tracks)

            if currentTrack == nil, let next = queue.skipToNext() {
                currentTrack = next
            }
        }
    }

    func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
