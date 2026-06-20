import SwiftUI

struct NowPlayingCardView: View {
    let track: Track?

    var body: some View {
        VStack(spacing: AcalumSpacing.xs) {
            Text(track?.title ?? "No Track")
                .font(AcalumTypography.title)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if let composer = track?.composer {
                Text(composer)
                    .font(AcalumTypography.body)
                    .foregroundStyle(.secondary)
            }

            if let performer = track?.performer {
                Text("Performed by \(performer)")
                    .font(AcalumTypography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        guard let track = track else { return "No track playing" }
        var parts = [track.title]
        if let composer = track.composer { parts.append("by \(composer)") }
        if let performer = track.performer { parts.append("performed by \(performer)") }
        return parts.joined(separator: ", ")
    }
}
