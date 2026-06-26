import SwiftUI

struct MoodRingView: View {
    let index: Int
    var size: CGFloat = 62
    var showLabel: Bool = true

    private var color: Color {
        index >= 80 ? .accentColor : index >= 40 ? .orange : Color(.systemBrown)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(index) / 100)
                .stroke(color, style: .init(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text("\(index)%")
                    .font(.system(size: size * 0.26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if showLabel {
                    Text("FIT")
                        .font(.system(size: size * 0.13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Fit \(index) percent")
    }
}
