import SwiftUI

struct NowPlayingCardView: View {
    let track: Track?
    @State private var detailsExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(track?.title ?? "No Track")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let track = track {
                        Text([track.composer, track.year.map(String.init)].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 13.5, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text("\(track.sourceName) · \(track.license ?? "Public Domain")")
                            .font(.system(size: 11.5, design: .rounded))
                            .foregroundStyle(Color(.systemBrown))
                            .padding(.top, 4)
                    }
                }

                Spacer(minLength: 0)

                if let mm = track?.moodMatch {
                    MoodRingView(index: mm.index)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) { detailsExpanded.toggle() }
                        }
                }
            }

            if let mm = track?.moodMatch {
                MatchDetailsView(match: mm, expanded: $detailsExpanded)
                    .padding(.top, 12)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(.systemGray5), lineWidth: 1)
        )
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
