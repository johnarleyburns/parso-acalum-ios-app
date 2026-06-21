import SwiftUI

struct PillSelectorView: View {
    let pills: [Pill]
    let selectedPills: Set<Pill>
    let onToggle: (Pill) -> Void

    private var grouped: [(PillCategory, [Pill])] {
        let categories: [PillCategory] = [.instrument, .mood, .context, .era]
        return categories.compactMap { category in
            let items = pills.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AcalumSpacing.sm) {
            Text("How should the music feel?")
                .font(AcalumTypography.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, AcalumSpacing.xs)

            FlowLayout(spacing: AcalumSpacing.sm) {
                ForEach(pills) { pill in
                    PillButton(
                        pill: pill,
                        isSelected: selectedPills.contains(pill),
                        onTap: { onToggle(pill) }
                    )
                }
            }
        }
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
