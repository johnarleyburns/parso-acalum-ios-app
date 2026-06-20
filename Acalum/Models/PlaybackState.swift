import Foundation

enum PlaybackState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case failed(String)
}
