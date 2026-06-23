import SwiftUI

struct PromptBarView: View {
    @Binding var prompt: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: AcalumSpacing.sm) {
            TextField("quiet spanish guitar at dusk...", text: $prompt)
                .font(AcalumTypography.body)
                .textFieldStyle(.plain)
                .onSubmit(onSubmit)
                .submitLabel(.search)
                .accessibilityLabel("Describe how the music should feel")

            if !prompt.isEmpty {
                Text("\u{21B5} to apply")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(.systemGray2))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(.systemGray4), lineWidth: 1)
                    )
            } else {
                Text("\u{21B5} to apply")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(.systemGray3))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(.systemGray4), lineWidth: 1)
                    )
            }

            if !prompt.isEmpty {
                Button(action: {
                    prompt = ""
                    onSubmit()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear prompt")
            }
        }
        .padding(.horizontal, AcalumSpacing.md)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
        )
    }
}
