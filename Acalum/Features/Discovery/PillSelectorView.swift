import SwiftUI

struct PillSelectorView: View {
    let pills: [Pill]
    let selectedPills: Set<Pill>
    let pendingMoodChange: Bool
    let onToggle: (Pill) -> Void
    let onUpdate: () -> Void
    let onPlayNow: () -> Void
    let onShake: () -> Void

    private var grouped: [(PillCategory, [Pill])] {
        let categories: [PillCategory] = [.sound, .style, .tradition, .listeningMode]
        return categories.compactMap { category in
            let items = pills.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AcalumSpacing.sm) {
            HStack {
                Text("Shape your stream")
                    .font(AcalumTypography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onShake) {
                    Label("Shake it up", systemImage: "arrow.triangle.2.circlepath")
                        .font(AcalumTypography.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.orange.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(.orange, lineWidth: 1))
                }
                .tint(.orange)
                .accessibilityHint("Switches to a new random direction")
            }
            .padding(.horizontal, AcalumSpacing.xs)

            ForEach(grouped, id: \.0) { (category, categoryPills) in
                Text(category.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)

                FlowLayout(spacing: AcalumSpacing.sm) {
                    ForEach(categoryPills) { pill in
                        PillButton(
                            pill: pill,
                            isSelected: selectedPills.contains(pill),
                            onTap: { onToggle(pill) }
                        )
                    }
                }
            }

            if pendingMoodChange {
                HStack(spacing: AcalumSpacing.sm) {
                    Button(action: onUpdate) {
                        Label("Update upcoming", systemImage: "checkmark.circle.fill")
                            .font(AcalumTypography.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                            .foregroundStyle(.white)
                    }
                    .accessibilityHint("Reshapes the queue without interrupting the current track")

                    Button(action: onPlayNow) {
                        Label("Play now", systemImage: "play.fill")
                            .font(AcalumTypography.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
                            )
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityHint("Replaces the current track immediately")
                }
                .padding(.top, AcalumSpacing.xs)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: pendingMoodChange)
    }
}

struct PillButton: View {
    let pill: Pill
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            HapticFeedback.selection()
            onTap()
        } label: {
            Text(pill.label)
                .font(AcalumTypography.pill)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .accessibilityLabel("\(pill.label), \(isSelected ? "selected" : "not selected")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x - spacing)
            totalHeight = y + rowHeight
        }

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}
