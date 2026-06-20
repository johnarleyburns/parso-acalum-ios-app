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
