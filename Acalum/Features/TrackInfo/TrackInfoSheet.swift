import SwiftUI

struct TrackInfoSheet: View {
    let track: Track?

    var body: some View {
        NavigationStack {
            List {
                if let track = track {
                    Section("Title") {
                        Text(track.title)
                    }

                    if let composer = track.composer {
                        Section("Composer") {
                            Text(composer)
                        }
                    }

                    if let performer = track.performer {
                        Section("Performer") {
                            Text(performer)
                        }
                    }

                    Section("Source") {
                        Text(track.sourceName)
                    }

                    if let license = track.license {
                        Section("License") {
                            Text(license)
                        }
                    }

                    if let year = track.year {
                        Section("Year") {
                            Text(String(year))
                        }
                    }

                    if let sourceURL = track.sourceURL {
                        Section {
                            Link("Open Source Page", destination: sourceURL)
                        }
                    }
                } else {
                    Text("No track selected")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Track Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
