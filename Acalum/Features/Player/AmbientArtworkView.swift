import SwiftUI

struct AmbientArtworkView: View {
    let track: Track?
    let isPlaying: Bool
    var moodTransition: MoodTransition? = nil

    @State private var animationPhase: CGFloat = 0
    @State private var transitionOpacity: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    private var transitionColors: [Color] {
        guard let transition = moodTransition else { return colors }
        let sig = transition.toSignature.pillIDs.joined(separator: "") + transition.toSignature.prompt
        let hash = abs(sig.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = Double((hash / 360) % 360) / 360.0
        let hue3 = Double((hash / 129600) % 360) / 360.0
        return [
            Color(hue: hue1, saturation: 0.35, brightness: 0.8),
            Color(hue: hue2, saturation: 0.30, brightness: 0.85),
            Color(hue: hue3, saturation: 0.25, brightness: 0.9),
        ]
    }

    var body: some View {
        ZStack {
            gradientView(colors: colors)

            if let artworkURL = track?.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        Color.clear
                    @unknown default:
                        Color.clear
                    }
                }
            }

            if moodTransition != nil {
                gradientView(colors: transitionColors)
                    .opacity(transitionOpacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
        .onChange(of: moodTransition) { _, transition in
            if transition != nil {
                animateTransitionIn()
            } else {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) {
                    transitionOpacity = 0
                }
            }
        }
        .accessibilityLabel("Album artwork")
    }

    private func gradientView(colors: [Color]) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: UnitPoint(x: 0.5 + 0.3 * cos(animationPhase), y: 0),
                    endPoint: UnitPoint(x: 0.5 + 0.3 * sin(animationPhase), y: 1)
                )
            )
    }

    private func animateTransitionIn() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.2)) {
            transitionOpacity = reduceMotion ? 0.4 : 0.75
        }
    }

    private func startAnimation() {
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
            animationPhase = .pi * 2
        }
    }
}
