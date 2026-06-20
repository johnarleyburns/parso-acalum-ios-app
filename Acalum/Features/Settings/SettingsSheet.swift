import SwiftUI

struct SettingsSheet: View {
    var body: some View {
        NavigationStack {
            List {
                Section("About") {
                    LabeledContent("App", value: "Acalum")
                    LabeledContent("Version", value: "0.1.0")
                }

                Section("Music") {
                    Text("All music is sourced from the public domain.")
                        .font(AcalumTypography.body)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
