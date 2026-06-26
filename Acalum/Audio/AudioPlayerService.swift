import AVFoundation
import Combine
import Foundation
import MediaPlayer
import os

enum AudioTransition {
    case immediate
    case fadeOutIn(out: TimeInterval, `in`: TimeInterval)
    case fadeIn(TimeInterval)
}

protocol AudioPlayerServiceProtocol: AnyObject {
    var statePublisher: AnyPublisher<PlaybackState, Never> { get }
    var currentTimePublisher: AnyPublisher<Double, Never> { get }
    var durationPublisher: AnyPublisher<Double, Never> { get }

    var onTrackFinished: (() -> Void)? { get set }
    var onSkipRequested: (() -> Void)? { get set }
    var onPreviousRequested: (() -> Bool)? { get set }
    var onInterruptionBegan: (() -> Void)? { get set }
    var onInterruptionEnded: (() -> Void)? { get set }
    var onPlaybackFailed: (() -> Void)? { get set }

    func play(url: URL)
    func play(url: URL, transition: AudioTransition)
    func pause()
    func resume()
    func stop()
    func seek(to time: TimeInterval)
    func updateNowPlaying(track: Track?)
}

final class AudioPlayerService: NSObject, AudioPlayerServiceProtocol, ObservableObject {
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var itemDidEndObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var fadeWorkItem: DispatchWorkItem?
    private var volumeRampWorkItems: [DispatchWorkItem] = []

    private let stateSubject = CurrentValueSubject<PlaybackState, Never>(.idle)
    private let currentTimeSubject = CurrentValueSubject<Double, Never>(0)
    private let durationSubject = CurrentValueSubject<Double, Never>(0)

    var statePublisher: AnyPublisher<PlaybackState, Never> { stateSubject.eraseToAnyPublisher() }
    var currentTimePublisher: AnyPublisher<Double, Never> { currentTimeSubject.eraseToAnyPublisher() }
    var durationPublisher: AnyPublisher<Double, Never> { durationSubject.eraseToAnyPublisher() }

    var onTrackFinished: (() -> Void)?
    var onSkipRequested: (() -> Void)?
    var onPreviousRequested: (() -> Bool)?
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

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.player?.rate == 0 ? self?.resume() : self?.pause()
            return .success
        }
        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            // Lock-screen Next uses skip semantics (logs a skip), not completion.
            if let onSkip = self?.onSkipRequested {
                onSkip()
            } else {
                self?.onTrackFinished?()
            }
            return .success
        }
        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let onPrevious = self?.onPreviousRequested else { return .noSuchContent }
            return onPrevious() ? .success : .noSuchContent
        }
        center.changePlaybackPositionCommand.isEnabled = true
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
        play(url: url, transition: .immediate)
    }

    func play(url: URL, transition: AudioTransition) {
        // Cancel every scheduled fade/ramp work item before starting a new
        // transition so stale ramps can't mutate the next player's volume.
        cancelScheduledFades()

        switch transition {
        case .immediate:
            playImmediate(url: url)
        case .fadeOutIn(let outDuration, let inDuration):
            fadeOutThenPlay(url: url, outDuration: outDuration, inDuration: inDuration)
        case .fadeIn(let inDuration):
            stopCurrentAndPlay(url: url, initialVolume: 0.01)
            rampVolume(to: 1.0, duration: inDuration)
        }
    }

    private func playImmediate(url: URL) {
        os_log(.info, "AudioPlayer: play(url:) called with %{public}@", url.absoluteString)
        stop()

        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            os_log(.error, "AudioPlayer: failed to reactivate audio session: %{public}@", error.localizedDescription)
        }

        stateSubject.send(.loading)

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.volume = 1.0

        observeItemStatus(item: item)
        observeTime()
        observeEnd()

        player?.play()
    }

    private func stopCurrentAndPlay(url: URL, initialVolume: Float) {
        removeObservers()
        player?.pause()
        player = nil

        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            os_log(.error, "AudioPlayer: failed to reactivate audio session: %{public}@", error.localizedDescription)
        }

        stateSubject.send(.loading)

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.volume = initialVolume

        observeItemStatus(item: item)
        observeTime()
        observeEnd()

        player?.play()
    }

    private func fadeOutThenPlay(url: URL, outDuration: TimeInterval, inDuration: TimeInterval) {
        guard let currentPlayer = player else {
            stopCurrentAndPlay(url: url, initialVolume: 0.01)
            rampVolume(to: 1.0, duration: inDuration)
            return
        }

        rampVolume(on: currentPlayer, to: 0, duration: outDuration)

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.stopCurrentAndPlay(url: url, initialVolume: 0.01)
            self.rampVolume(to: 1.0, duration: inDuration)
        }
        fadeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + outDuration, execute: item)
    }

    private func rampVolume(on target: AVPlayer? = nil, to targetVolume: Float, duration: TimeInterval) {
        let player = target ?? self.player
        guard let player else { return }

        let steps: Int = max(1, Int(duration / 0.05))
        let startVolume = player.volume
        let delta = (targetVolume - startVolume) / Float(steps)
        let interval = duration / Double(steps)

        for i in 0...steps {
            let isFinal = (i == steps)
            let workItem = DispatchWorkItem { [weak player] in
                guard let player else { return }
                player.volume = isFinal ? targetVolume : startVolume + delta * Float(i)
            }
            volumeRampWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i), execute: workItem)
        }
    }

    /// Cancels and clears every scheduled fade and volume-ramp work item.
    private func cancelScheduledFades() {
        fadeWorkItem?.cancel()
        fadeWorkItem = nil
        for item in volumeRampWorkItems { item.cancel() }
        volumeRampWorkItems.removeAll()
    }

    func pause() {
        player?.pause()
        stateSubject.send(.paused)
    }

    func resume() {
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
        stateSubject.send(.playing)
    }

    func stop() {
        cancelScheduledFades()
        removeObservers()
        player?.pause()
        player = nil
        currentTimeSubject.send(0)
        durationSubject.send(0)
        stateSubject.send(.idle)
        clearNowPlaying()
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
        currentTimeSubject.send(time)
        if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
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
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
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
