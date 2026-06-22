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
                        Text("Splash image: \"Beautiful girl listening to music with headphones\"")
                            .font(AcalumTypography.body)
                        Text("Licensed under CC BY-SA 4.0")
                            .font(AcalumTypography.caption)
                            .foregroundStyle(.tertiary)
                        Link("View on Wikimedia Commons",
                             destination: URL(string: "https://commons.wikimedia.org/wiki/File:Beautiful_girl_listening_to_music_with_headphones.jpg")!)
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
