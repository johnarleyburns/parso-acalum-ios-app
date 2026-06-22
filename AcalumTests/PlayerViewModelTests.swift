@testable import Acalum
import Combine
import XCTest

@MainActor
final class PlayerViewModelTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        cancellables = []
        LocalStore.saveLastPrompt("")
        LocalStore.saveLastPillIDs([])
        LocalStore.saveFavorites([])
    }

    func testTogglePillDoesNotAutoPlay() async throws {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        let piano = Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano")
        vm.togglePill(piano)
        await Task.yield()

        XCTAssertTrue(vm.selectedPills.contains(piano), "Pill should be selected")
        XCTAssertFalse(audioService.didPlay, "togglePill should NOT auto-play")
    }

    func testSubmitPromptAutoPlays() async throws {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        vm.prompt = "slow solo piano"
        vm.submitPrompt()

        for _ in 0..<50 { await Task.yield(); if audioService.didPlay { break } }

        XCTAssertNotNil(vm.currentTrack, "currentTrack should be set after submitPrompt")
        XCTAssertEqual(vm.currentTrack?.id, "prompt_001")
        XCTAssertTrue(audioService.didPlay, "submitPrompt should auto-play")
    }

    func testSkipRegeneratesQueueFromPills() async throws {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        // Select pills first
        let piano = Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano")
        let melancholy = Pill(id: "mood:melancholy", label: "Melancholy", category: .mood, semanticPhrase: "melancholy, sad")
        vm.togglePill(piano)
        vm.togglePill(melancholy)

        // Skip should regenerate based on current pills
        vm.skip()
        for _ in 0..<50 { await Task.yield(); if audioService.didPlay { break } }

        XCTAssertNotNil(vm.currentTrack, "skip should enqueue and play a track")
        XCTAssertEqual(vm.currentTrack?.id, "pill_piano_mel_001", "Skip should use current pills to generate")
        XCTAssertTrue(audioService.didPlay, "skip should auto-play")
    }

    func testSkipWithEmptyQueueGeneratesFresh() async throws {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        vm.skip()
        for _ in 0..<50 { await Task.yield(); if audioService.didPlay { break } }

        // Even with empty queue, skip calls replaceQueueAndPlay which generates and plays
        XCTAssertNotNil(vm.currentTrack, "skip should generate and play even with empty queue")
    }

    func testIsFavoritedReflectsFavorites() async throws {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        LocalStore.saveFavorites(["test_track_id"])

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        await Task.yield()

        XCTAssertTrue(vm.favoriteIDs.contains("test_track_id"))
    }
}

// MARK: - Mock Services

final class MockAudioPlayerService: AudioPlayerServiceProtocol, ObservableObject {
    private let stateSubject = CurrentValueSubject<PlaybackState, Never>(.idle)
    private let currentTimeSubject = CurrentValueSubject<Double, Never>(0)
    private let durationSubject = CurrentValueSubject<Double, Never>(0)

    var statePublisher: AnyPublisher<PlaybackState, Never> { stateSubject.eraseToAnyPublisher() }
    var currentTimePublisher: AnyPublisher<Double, Never> { currentTimeSubject.eraseToAnyPublisher() }
    var durationPublisher: AnyPublisher<Double, Never> { durationSubject.eraseToAnyPublisher() }

    var didPlay = false
    var didPause = false
    var didResume = false
    var didStop = false
    var lastPlayedURL: URL?
    var lastNowPlayingTrack: Track?

    var onTrackFinished: (() -> Void)?
    var onInterruptionBegan: (() -> Void)?
    var onInterruptionEnded: (() -> Void)?
    var onPlaybackFailed: (() -> Void)?

    func play(url: URL) {
        didPlay = true
        lastPlayedURL = url
        stateSubject.send(.playing)
    }

    func pause() {
        didPause = true
        stateSubject.send(.paused)
    }

    func resume() {
        didResume = true
        stateSubject.send(.playing)
    }

    func stop() {
        didStop = true
        stateSubject.send(.idle)
    }

    func updateNowPlaying(track: Track?) {
        lastNowPlayingTrack = track
    }
}

final class MockRecommenderQueueService: QueueServiceProtocol {
    let tracks: [Track] = [
        Track(
            id: "pill_piano_001",
            title: "Piano Sonata No. 14",
            composer: "Beethoven",
            performer: nil,
            sourceName: "Test",
            sourceURL: nil,
            audioURL: URL(string: "https://example.com/piano.mp3")!,
            durationSeconds: 200,
            artworkURL: nil,
            license: nil,
            year: nil,
            explanation: nil
        ),
        Track(
            id: "pill_piano_mel_001",
            title: "Melancholy Piano Adagio",
            composer: "Chopin",
            performer: nil,
            sourceName: "Test",
            sourceURL: nil,
            audioURL: URL(string: "https://example.com/mel.mp3")!,
            durationSeconds: 240,
            artworkURL: nil,
            license: nil,
            year: nil,
            explanation: nil
        ),
        Track(
            id: "prompt_001",
            title: "Slow Piano Adagio",
            composer: "Test Composer",
            performer: nil,
            sourceName: "Test",
            sourceURL: nil,
            audioURL: URL(string: "https://example.com/test.mp3")!,
            durationSeconds: 180,
            artworkURL: nil,
            license: nil,
            year: nil,
            explanation: nil
        ),
    ]

    func generateQueue(context: DiscoveryContext) async -> [Track] {
        if let prompt = context.prompt, !prompt.isEmpty {
            return [tracks[2]]
        }

        let hasPiano = context.selectedPills.contains(where: { $0.label == "Piano" })
        let hasMelancholy = context.selectedPills.contains(where: { $0.label == "Melancholy" })

        if hasPiano && hasMelancholy {
            return [tracks[1]]
        } else if hasPiano {
            return [tracks[0]]
        }

        return [tracks[2]]
    }
}
