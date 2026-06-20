import SwiftUI

struct PlayerHomeView: View {
    @StateObject var viewModel: PlayerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: AcalumSpacing.lg) {
                headerView

                AmbientArtworkView(
                    track: viewModel.currentTrack,
                    isPlaying: viewModel.isPlaying
                )
                .padding(.horizontal, AcalumSpacing.xxl)

                NowPlayingCardView(track: viewModel.currentTrack)

                progressView

                PlaybackControlsView(
                    isPlaying: viewModel.isPlaying,
                    isFavorited: viewModel.isFavorited,
                    onFavorite: viewModel.toggleFavorite,
                    onPlayPause: viewModel.togglePlayPause,
                    onSkip: viewModel.skip
                )

                PillSelectorView(
                    pills: MockData.pills,
                    selectedPills: viewModel.selectedPills,
                    onToggle: viewModel.togglePill
                )
                .padding(.horizontal, AcalumSpacing.sm)

                PromptBarView(
                    prompt: $viewModel.prompt,
                    onSubmit: viewModel.submitPrompt
                )
                .padding(.horizontal, AcalumSpacing.sm)

                Spacer(minLength: AcalumSpacing.lg)
            }
            .padding(.top, AcalumSpacing.sm)
        }
        .background(Color(.systemBackground))
        .sheet(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .whyThis:
                WhyThisSheet(track: viewModel.currentTrack)
            case .trackInfo:
                TrackInfoSheet(track: viewModel.currentTrack)
            case .settings:
                SettingsSheet()
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text("Acalum")
                .font(AcalumTypography.largeTitle)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                viewModel.activeSheet = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, AcalumSpacing.md)
    }

    private var progressView: some View {
        VStack(spacing: AcalumSpacing.xs) {
            ProgressView(value: viewModel.progress)
                .tint(.primary)
                .accessibilityLabel("Playback progress")

            HStack {
                Text(viewModel.formattedTime(viewModel.currentTime))
                    .font(AcalumTypography.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(viewModel.formattedTime(viewModel.duration))
                    .font(AcalumTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, AcalumSpacing.xl)
    }
}
