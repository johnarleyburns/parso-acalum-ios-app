import SwiftUI

struct WhyThisSheet: View {
    let track: Track?

    var body: some View {
        NavigationStack {
            List {
                if let track = track {
                    Section("Track") {
                        Text(track.title)
                            .font(AcalumTypography.headline)
                    }

                    if let explanation = track.explanation {
                        Section("Matched because") {
                            ForEach(explanation.reasons, id: \.self) { reason in
                                Label(reason, systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !explanation.matchedPills.isEmpty {
                            Section("Matched pills") {
                                Text(explanation.matchedPills.joined(separator: ", "))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Source") {
                        Text(track.sourceName)
                            .foregroundStyle(.secondary)
                    }

                    if let license = track.license {
                        Section("License") {
                            Text(license)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("No track selected")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Why this track?")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
