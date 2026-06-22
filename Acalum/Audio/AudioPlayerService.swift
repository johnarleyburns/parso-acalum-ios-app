import AVFoundation
import Combine
import Foundation
import MediaPlayer
import os

protocol AudioPlayerServiceProtocol: AnyObject {
    var statePublisher: AnyPublisher<PlaybackState, Never> { get }
    var currentTimePublisher: AnyPublisher<Double, Never> { get }
    var durationPublisher: AnyPublisher<Double, Never> { get }

    var onTrackFinished: (() -> Void)? { get set }
    var onInterruptionBegan: (() -> Void)? { get set }
    var onInterruptionEnded: (() -> Void)? { get set }
    var onPlaybackFailed: (() -> Void)? { get set }

    func play(url: URL)
    func pause()
    func resume()
    func stop()
    func updateNowPlaying(track: Track?)
}

final class AudioPlayerService: NSObject, AudioPlayerServiceProtocol, ObservableObject {
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var itemDidEndObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?

    private let stateSubject = CurrentValueSubject<PlaybackState, Never>(.idle)
    private let currentTimeSubject = CurrentValueSubject<Double, Never>(0)
    private let durationSubject = CurrentValueSubject<Double, Never>(0)

    var statePublisher: AnyPublisher<PlaybackState, Never> { stateSubject.eraseToAnyPublisher() }
    var currentTimePublisher: AnyPublisher<Double, Never> { currentTimeSubject.eraseToAnyPublisher() }
    var durationPublisher: AnyPublisher<Double, Never> { durationSubject.eraseToAnyPublisher() }

    var onTrackFinished: (() -> Void)?
    var onInterruptionBegan: (() -> Void)?
    var onInterruptionEnded: (() -> Void)?
    var onPlaybackFailed: (() -> Void)?

    override init() {
        super.init()
        configureAudioSession()
        configureRemoteCommands()
        observeInterruptions()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            os_log(.info, "AudioPlayer: audio session activated, category=%@", session.category.rawValue)
        } catch {
            os_log(.error, "AudioPlayer: audio session setup failed: %{public}@", error.localizedDescription)
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.onTrackFinished?()
            return .success
        }
        center.previousTrackCommand.addTarget { _ in .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent,
                  let player = self?.player else { return .commandFailed }
            player.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: 600))
            return .success
        }
    }

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            switch type {
            case .began:
                self?.onInterruptionBegan?()
            case .ended:
                if let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self?.onInterruptionEnded?()
                    }
                }
            @unknown default:
                break
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            switch reason {
            case .oldDeviceUnavailable:
                self?.pause()
            default:
                break
            }
        }
    }

    func play(url: URL) {
        os_log(.info, "AudioPlayer: play(url:) called with %{public}@", url.absoluteString)
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
        clearNowPlaying()
    }

    func updateNowPlaying(track: Track?) {
        guard let track else {
            clearNowPlaying()
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.composer ?? track.sourceName,
            MPMediaItemPropertyPlaybackDuration: track.durationSeconds,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTimeSubject.value,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]

        if let artURL = track.artworkURL {
            loadArtwork(url: artURL) { image in
                if let image {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    currentInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                }
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
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
                    os_log(.info, "AudioPlayer: item readyToPlay, duration=%.2fs", duration)
                case .failed:
                    let nsError = item.error as NSError?
                    let domain = nsError?.domain ?? "unknown"
                    let code = nsError?.code ?? 0
                    let desc = nsError?.localizedDescription ?? "Unknown error"
                    let underlying = nsError?.userInfo[NSUnderlyingErrorKey] as? NSError
                    os_log(.error, "AudioPlayer: item failed domain=%@ code=%d desc=\"%@\" underlying=%@ userInfo=%@",
                           domain, code, desc,
                           underlying?.description ?? "none",
                           nsError?.userInfo.description ?? "none")
                    self?.stateSubject.send(.failed(desc))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.onPlaybackFailed?()
                    }
                case .unknown:
                    os_log(.debug, "AudioPlayer: item status = unknown")
                @unknown default:
                    os_log(.debug, "AudioPlayer: item status = @unknown default")
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
                if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = seconds
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
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
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
