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

                Section("Image Credits") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Splash image: \"SAKURAKO listen to music\"")
                            .font(AcalumTypography.body)
                        Text("Photo by MIKI Yoshihito — CC BY 2.0")
                            .font(AcalumTypography.caption)
                            .foregroundStyle(.tertiary)
                        Link("View on Wikimedia Commons",
                             destination: URL(string: "https://commons.wikimedia.org/wiki/File:SAKURAKO_listen_to_music_(46579718321).jpg")!)
                            .font(AcalumTypography.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
