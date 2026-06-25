import SwiftUI

struct MatchDetailsView: View {
    let match: MoodMatch
    @Binding var expanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("\(match.summary) · why")
                        .font(AcalumTypography.caption)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(match.components) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: c.matched ? "checkmark.circle.fill" : "minus.circle")
                                    .font(.caption2)
                                    .foregroundStyle(c.matched ? Color.accentColor : .secondary)
                                Text(c.label)
                                    .font(AcalumTypography.caption)
                                    .foregroundStyle(c.matched ? .primary : .secondary)
                                Spacer()
                                Text(c.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(.systemGray5))
                                    Capsule()
                                        .fill(c.matched ? Color.accentColor : Color(.systemGray3))
                                        .frame(width: geo.size.width * CGFloat(c.share) / 100)
                                }
                            }
                            .frame(height: 6)
                        }
                    }

                    if !match.matchedPhraseTerms.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Matched your phrase", systemImage: "text.quote")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(match.matchedPhraseTerms.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Matched phrase words: \(match.matchedPhraseTerms.joined(separator: ", "))")
                            if match.phraseMatchedVerbatim {
                                Label("Full phrase appears in metadata", systemImage: "checkmark.seal.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !match.context.isEmpty {
                        Divider()
                        ForEach(match.context, id: \.self) { text in
                            Text(text)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
