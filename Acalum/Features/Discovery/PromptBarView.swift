import SwiftUI

struct PromptBarView: View {
    @Binding var prompt: String
    /// Commits the prompt draft (Update upcoming semantics — non-interrupting).
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: AcalumSpacing.sm) {
            TextField("quiet spanish guitar at dusk...", text: $prompt)
                .font(AcalumTypography.body)
                .textFieldStyle(.plain)
                .onSubmit(onSubmit)
                .submitLabel(.go)
                .accessibilityLabel("Describe the direction for your stream")

            if !prompt.isEmpty {
                // Clear edits the draft only — it does not commit or change playback.
                Button {
                    prompt = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear prompt draft")

                Button {
                    onSubmit()
                } label: {
                    Text("Update")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Update upcoming with this prompt")
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
