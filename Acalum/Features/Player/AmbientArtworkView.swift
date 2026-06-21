import SwiftUI

struct AmbientArtworkView: View {
    let track: Track?
    let isPlaying: Bool

    @State private var animationPhase: CGFloat = 0

    private var colors: [Color] {
        guard let track = track else {
            return [Color(.systemGray5), Color(.systemGray4)]
        }
        let hash = abs(track.id.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = Double((hash / 360) % 360) / 360.0
        let hue3 = Double((hash / 129600) % 360) / 360.0
        return [
            Color(hue: hue1, saturation: 0.3, brightness: 0.85),
            Color(hue: hue2, saturation: 0.25, brightness: 0.9),
            Color(hue: hue3, saturation: 0.2, brightness: 0.95),
        ]
    }

    var body: some View {
        Group {
            if let artworkURL = track?.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        gradientView
                    @unknown default:
                        gradientView
                    }
                }
            } else {
                gradientView
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .opacity(0.3)
        )
        .aspectRatio(1.0, contentMode: .fit)
        .onAppear {
            if isPlaying {
                startAnimation()
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startAnimation()
            }
        }
        .accessibilityLabel("Album artwork")
    }

    private var gradientView: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: UnitPoint(x: 0.5 + 0.3 * cos(animationPhase), y: 0),
                    endPoint: UnitPoint(x: 0.5 + 0.3 * sin(animationPhase), y: 1)
                )
            )
    }

    private func startAnimation() {
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
            animationPhase = .pi * 2
        }
    }
}
