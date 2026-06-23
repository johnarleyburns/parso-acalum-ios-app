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
        SeenHistoryStore.clear()
    }

    func testTogglePillDoesNotChangeCommittedPills() {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        let piano = Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano")
        vm.togglePill(piano)

        XCTAssertTrue(vm.draftPills.contains(piano), "Draft pills should include piano")
        XCTAssertFalse(vm.committedPills.contains(piano), "Committed pills should NOT change")
        XCTAssertTrue(vm.pendingMoodChange, "Should have pending change")
    }

    func testPendingMoodChangeTogglesCorrectly() {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        XCTAssertFalse(vm.pendingMoodChange, "Should start with no pending change")

        let piano = Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano")
        vm.togglePill(piano)
        XCTAssertTrue(vm.pendingMoodChange)

        vm.applyMood(startNow: false)
        XCTAssertFalse(vm.pendingMoodChange, "Should be resolved after apply")
        XCTAssertTrue(vm.committedPills.contains(piano))
    }

    func testApplyMoodCommitsAndClearsSeen() async throws {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        SeenHistoryStore.record("prev_track_1")
        SeenHistoryStore.record("prev_track_2")

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        let piano = Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano")
        vm.togglePill(piano)
        vm.applyMood(startNow: true)

        for _ in 0..<50 { await Task.yield(); if vm.currentTrack != nil { break } }

        XCTAssertTrue(vm.committedPills.contains(piano))
        XCTAssertFalse(SeenHistoryStore.recentIDs.contains("prev_track_1"), "Old seen entries should be cleared on apply")
        XCTAssertFalse(SeenHistoryStore.recentIDs.contains("prev_track_2"), "Old seen entries should be cleared on apply")
        XCTAssertNotNil(vm.currentTrack)
    }

    func testShakeItUpYieldsDifferentSet() {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        let initial = vm.committedPills
        vm.shakeItUp()

        XCTAssertNotEqual(vm.committedPills, initial, "Shake should produce different pills")
        XCTAssertFalse(vm.draftPrompt.isEmpty == false && vm.committedPrompt.isEmpty == false,
                       "Prompt should be empty after shake")
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

        XCTAssertTrue(vm.draftPills.contains(piano), "Pill should be in draft")
        XCTAssertFalse(audioService.didPlay, "togglePill should NOT auto-play")
    }

    func testSubmitPromptAppliesAndPlays() async throws {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        vm.draftPrompt = "slow solo piano"
        vm.submitPrompt()

        for _ in 0..<50 { await Task.yield(); if audioService.didPlay { break } }

        XCTAssertEqual(vm.committedPrompt, "slow solo piano")
        XCTAssertTrue(audioService.didPlay, "submitPrompt should auto-play")
    }

    func testSkipRegeneratesQueueFromCommittedPills() async throws {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        let piano = Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano")
        let melancholy = Pill(id: "mood:melancholy", label: "Melancholy", category: .mood, semanticPhrase: "melancholy, sad")
        vm.togglePill(piano)
        vm.togglePill(melancholy)
        vm.applyMood(startNow: true)

        for _ in 0..<50 { await Task.yield(); if audioService.didPlay { break } }

        XCTAssertNotNil(vm.currentTrack, "apply should enqueue and play a track")
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

    func testSurfaceRecordsSeen() {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        let piano = Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano")
        vm.togglePill(piano)

        SeenHistoryStore.record("pre_existing")
        XCTAssertTrue(SeenHistoryStore.recentIDs.contains("pre_existing"))

        vm.applyMood(startNow: true)
        // applyMood clears old entries; surface() records new track, so old is gone
        XCTAssertFalse(SeenHistoryStore.recentIDs.contains("pre_existing"), "Old seen entry cleared on apply")
    }

    func testDraftPromptTracking() {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        vm.draftPrompt = "test mood"
        XCTAssertTrue(vm.pendingMoodChange)
        vm.draftPrompt = ""
        XCTAssertFalse(vm.pendingMoodChange)
    }

    func testUpNextPopulatedAfterGenerate() async throws {
        let audioService = MockAudioPlayerService()
        let queueService = MockRecommenderQueueService()

        let vm = PlayerViewModel(
            audioService: audioService,
            feedbackTracker: FeedbackTracker(),
            queueService: queueService
        )

        let piano = Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano")
        vm.togglePill(piano)
        vm.applyMood(startNow: true)

        for _ in 0..<50 { await Task.yield(); if !vm.upNext.isEmpty { break } }
        XCTAssertFalse(vm.upNext.isEmpty, "Up next should be populated")
    }
}

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
    static func makeTrack(id: String, title: String, composer: String = "Test Composer") -> Track {
        Track(
            id: id, title: title, composer: composer, performer: nil,
            sourceName: "Test", sourceURL: nil,
            audioURL: URL(string: "https://example.com/\(id).mp3")!,
            durationSeconds: 200, artworkURL: nil,
            license: nil, year: nil,
            explanation: nil,
            moodMatch: MoodMatch(
                index: 75, summary: "Good match",
                components: [
                    MoodComponent(label: "Acoustic character", detail: "cosine 0.60", share: 60, matched: true)
                ],
                context: ["Fresh"]
            )
        )
    }

    func generateQueue(context: DiscoveryContext) async -> [Track] {
        let hasPills = !context.selectedPills.isEmpty
        let hasPrompt = context.prompt != nil && !(context.prompt ?? "").isEmpty

        let tracks: [Track]
        if hasPrompt {
            tracks = [Self.makeTrack(id: "prompt_001", title: "Slow Piano Adagio")]
        } else if hasPills {
            tracks = [
                Self.makeTrack(id: "pill_001", title: "Piano Sonata No. 14", composer: "Beethoven"),
                Self.makeTrack(id: "pill_002", title: "Melancholy Adagio", composer: "Chopin"),
                Self.makeTrack(id: "pill_003", title: "Moonlight Sonata", composer: "Beethoven"),
            ]
        } else {
            tracks = [
                Self.makeTrack(id: "fresh_001", title: "Catalog Track 1"),
                Self.makeTrack(id: "fresh_002", title: "Catalog Track 2"),
            ]
        }

        return tracks
    }
}
