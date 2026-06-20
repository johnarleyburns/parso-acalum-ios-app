import AVFoundation
import Combine
import Foundation

protocol AudioPlayerServiceProtocol: AnyObject {
    var statePublisher: AnyPublisher<PlaybackState, Never> { get }
    var currentTimePublisher: AnyPublisher<Double, Never> { get }
    var durationPublisher: AnyPublisher<Double, Never> { get }

    func play(url: URL)
    func pause()
    func resume()
    func stop()
}

final class AudioPlayerService: NSObject, AudioPlayerServiceProtocol, ObservableObject {
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var itemDidEndObserver: NSObjectProtocol?

    private let stateSubject = CurrentValueSubject<PlaybackState, Never>(.idle)
    private let currentTimeSubject = CurrentValueSubject<Double, Never>(0)
    private let durationSubject = CurrentValueSubject<Double, Never>(0)

    var statePublisher: AnyPublisher<PlaybackState, Never> { stateSubject.eraseToAnyPublisher() }
    var currentTimePublisher: AnyPublisher<Double, Never> { currentTimeSubject.eraseToAnyPublisher() }
    var durationPublisher: AnyPublisher<Double, Never> { durationSubject.eraseToAnyPublisher() }

    var onTrackFinished: (() -> Void)?

    override init() {
        super.init()
        configureAudioSession()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    func play(url: URL) {
        stop()
        stateSubject.send(.loading)

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)

        observeItemStatus(item: item)
        observeTime()
        observeEnd()

        player?.play()
    }

    func pause() {
        player?.pause()
        stateSubject.send(.paused)
    }

    func resume() {
        player?.play()
        stateSubject.send(.playing)
    }

    func stop() {
        removeObservers()
        player?.pause()
        player = nil
        currentTimeSubject.send(0)
        durationSubject.send(0)
        stateSubject.send(.idle)
    }

    private func observeItemStatus(item: AVPlayerItem) {
        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    let duration = item.duration.seconds
                    if duration.isFinite {
                        self?.durationSubject.send(duration)
                    }
                    self?.stateSubject.send(.playing)
                case .failed:
                    let message = item.error?.localizedDescription ?? "Unknown error"
                    self?.stateSubject.send(.failed(message))
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func observeTime() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let seconds = time.seconds
            if seconds.isFinite {
                self?.currentTimeSubject.send(seconds)
            }
        }
    }

    private func observeEnd() {
        itemDidEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.stateSubject.send(.idle)
            self?.onTrackFinished?()
        }
    }

    private func removeObservers() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = itemDidEndObserver {
            NotificationCenter.default.removeObserver(observer)
            itemDidEndObserver = nil
        }
        cancellables.removeAll()
    }

    deinit {
        removeObservers()
    }
}
