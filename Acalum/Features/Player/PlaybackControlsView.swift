import SwiftUI

struct PlaybackControlsView: View {
    let isPlaying: Bool
    let isFavorited: Bool
    let onFavorite: () -> Void
    let onPlayPause: () -> Void
    let onSkip: () -> Void
    let onMoreLikeThis: (() -> Void)?

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

            if let onMoreLikeThis {
                Button {
                    HapticFeedback.medium()
                    onMoreLikeThis()
                } label: {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel("More like this")
                .accessibilityHint("Finds upcoming tracks similar to the current track")
            }

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
