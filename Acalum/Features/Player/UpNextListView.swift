import SwiftUI

struct UpNextListView: View {
    let tracks: [Track]
    let hasNoStrongMatches: Bool
    let onTapTrack: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Up next")
                    .font(AcalumTypography.caption.weight(.semibold))
                Spacer()
                Text("rotates \(SeenHistoryStore.minRotation)+ before repeat")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AcalumSpacing.xs)
            .padding(.bottom, AcalumSpacing.xs)

            if hasNoStrongMatches {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "circle.dotted")
                        .font(.system(size: 14))
                    Text("**No strong matches.** Rotating fresh, loosely-related tracks instead of dead-ending — most-related first.")
                        .font(.caption)
                        .foregroundStyle(Color(.systemBrown))
                        .lineLimit(nil)
                }
                .padding(11)
                .background(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, AcalumSpacing.xs)
                .padding(.bottom, AcalumSpacing.xs)
            }

            ForEach(Array(tracks.enumerated()), id: \.element.id) { i, track in
                UpNextRowView(track: track, delay: Double(i) * 0.04)
                    .onTapGesture {
                        onTapTrack?(i)
                    }
                if track.id != tracks.last?.id {
                    Divider()
                }
            }
        }
    }
}

private struct UpNextRowView: View {
    let track: Track
    let delay: Double
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AcalumSpacing.md) {
                if let mm = track.moodMatch {
                    MoodRingView(index: mm.index, size: 42, showLabel: false)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() }
                        }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(AcalumTypography.body.weight(.medium))
                        .lineLimit(1)
                    Text([track.composer, track.year.map(String.init)].compactMap { $0 }.joined(separator: " · "))
                        .font(AcalumTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, AcalumSpacing.sm)

            if expanded, let mm = track.moodMatch {
                MatchDetailsView(match: mm, expanded: $expanded)
                    .padding(.leading, 55)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
