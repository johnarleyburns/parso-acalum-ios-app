import SwiftUI

struct PlaybackControlsView: View {
    let isPlaying: Bool
    let isFavorited: Bool
    let onFavorite: () -> Void
    let onPlayPause: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: AcalumSpacing.xxl) {
            Button {
                HapticFeedback.medium()
                onFavorite()
            } label: {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundStyle(isFavorited ? .red : .primary)
            }
            .accessibilityLabel(isFavorited ? "Unfavorite" : "Favorite")

            Button {
                HapticFeedback.light()
                onPlayPause()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            Button {
                HapticFeedback.medium()
                onSkip()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel("Skip to next track")
        }
    }
}
