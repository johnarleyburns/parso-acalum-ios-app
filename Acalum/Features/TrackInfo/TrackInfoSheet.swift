import SwiftUI

struct TrackInfoSheet: View {
    let track: Track?
    var onOpenSource: ((Track) -> Void)? = nil
    @Environment(\.openURL) private var openURL

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

                    if let listenability = track.listenability {
                        Section("Stream quality") {
                            Text(listenability.qualitySummary)
                                .accessibilityLabel("Stream quality \(listenability.tier), score \(String(format: "%.2f", listenability.score))")
                        }
                    }

                    if let sourceURL = track.sourceURL {
                        Section {
                            Button {
                                onOpenSource?(track)
                                openURL(sourceURL)
                            } label: {
                                Label("Open Internet Archive entry", systemImage: "arrow.up.right.square")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .accessibilityLabel("Open this track on Internet Archive")
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
