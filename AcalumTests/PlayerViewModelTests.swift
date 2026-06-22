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

    func testTogglePillClearsQueueAndPlaysNewTrack() async throws {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        // Wait for initial refreshQueue to settle
        for _ in 0..<10 { await Task.yield(); if vm.currentTrack != nil { break } }

        let piano = Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano")
        vm.togglePill(piano)

        for _ in 0..<50 { await Task.yield(); if audioService.didPlay { break } }

        XCTAssertNotNil(vm.currentTrack, "currentTrack should be set after togglePill")
        XCTAssertEqual(vm.currentTrack?.id, "pill_piano_001")
        XCTAssertTrue(audioService.didPlay, "togglePill should auto-play")
    }

    func testSubmitPromptClearsQueueAndPlaysNewTrack() async throws {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        for _ in 0..<10 { await Task.yield(); if vm.currentTrack != nil { break } }

        vm.prompt = "slow solo piano"
        vm.submitPrompt()

        for _ in 0..<50 { await Task.yield(); if audioService.didPlay { break } }

        XCTAssertNotNil(vm.currentTrack, "currentTrack should be set after submitPrompt")
        XCTAssertEqual(vm.currentTrack?.id, "prompt_001")
        XCTAssertTrue(audioService.didPlay, "submitPrompt should auto-play")
    }

    func testTogglePillReplacesStaleTracks() async throws {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        let piano = Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano")
        vm.togglePill(piano)
        for _ in 0..<50 { await Task.yield(); if vm.currentTrack != nil { break } }

        let firstTrack = vm.currentTrack
        XCTAssertEqual(firstTrack?.id, "pill_piano_001")

        audioService.didPlay = false
        let melancholy = Pill(id: "mood:melancholy", label: "Melancholy", category: .mood, semanticPhrase: "melancholy, sad")
        vm.togglePill(melancholy)
        for _ in 0..<50 { await Task.yield(); if vm.currentTrack != nil && vm.currentTrack?.id != firstTrack?.id { break } }

        let secondTrack = vm.currentTrack
        XCTAssertNotNil(secondTrack, "Should have a new track after toggling second pill")
        XCTAssertEqual(secondTrack?.id, "pill_piano_mel_001", "Second track should reflect combined pills")
        XCTAssertNotEqual(secondTrack?.id, firstTrack?.id, "togglePill should replace the queue, not append")
    }

    func testSkipDoesNotAutoPlayIfQueueEmpty() async throws {
        let audioService = MockAudioPlayerService()
        let queueService = EmptyQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        for _ in 0..<10 { await Task.yield() }
        vm.skip()
        await Task.yield()

        XCTAssertNil(vm.currentTrack, "Skip with empty queue should leave currentTrack nil")
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

final class EmptyQueueService: QueueServiceProtocol {
    func generateQueue(context: DiscoveryContext) async -> [Track] {
        return []
    }
}
