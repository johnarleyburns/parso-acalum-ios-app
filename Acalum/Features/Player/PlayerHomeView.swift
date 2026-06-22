import SwiftUI

struct PlayerHomeView: View {
    @StateObject var viewModel: PlayerViewModel
    @State private var toastData: ToastData?

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

                if viewModel.currentTrack == nil {
                    if viewModel.isInitialLoading || viewModel.playbackState == .loading {
                        loadingCardView
                    } else {
                        emptyStateView
                    }
                } else {
                    progressView

                    PlaybackControlsView(
                        isPlaying: viewModel.isPlaying,
                        isFavorited: viewModel.isFavorited,
                        onFavorite: viewModel.toggleFavorite,
                        onPlayPause: viewModel.togglePlayPause,
                        onSkip: viewModel.skip
                    )
                }

                if case .failed(let message) = viewModel.playbackState {
                    errorBanner(message: message)
                }

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
        .toast(data: $toastData)
        .onReceive(viewModel.networkMonitor.$isConnected.dropFirst()) { connected in
            if connected {
                toastData = ToastData(message: "Back online", icon: "wifi")
            } else {
                toastData = ToastData(message: "You're offline", icon: "wifi.slash")
            }
        }
    }

    private var loadingCardView: some View {
        VStack(spacing: AcalumSpacing.md) {
            ProgressView()
                .scaleEffect(1.1)
            Text("Loading...")
                .font(AcalumTypography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AcalumSpacing.xl)
    }

    private var emptyStateView: some View {
        VStack(spacing: AcalumSpacing.md) {
            Text("Choose your sound")
                .font(AcalumTypography.headline)
                .foregroundStyle(.secondary)
            Text("Select some pills or type a prompt to discover public-domain music")
                .font(AcalumTypography.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AcalumSpacing.xl)
        .padding(.vertical, AcalumSpacing.lg)
    }

    private func errorBanner(message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(AcalumTypography.caption)
            .foregroundStyle(.red)
            .padding(.horizontal, AcalumSpacing.md)
            .padding(.vertical, AcalumSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.red.opacity(0.1))
            )
            .padding(.horizontal, AcalumSpacing.md)
            .accessibilityLabel("Playback error: \(message)")
    }

    private var loadingOverlay: some View {
        Color(.systemBackground)
            .opacity(0.6)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: AcalumSpacing.md) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(AcalumTypography.body)
                        .foregroundStyle(.secondary)
                }
            }
    }

    private var headerView: some View {
        HStack {
            Text("Acalum")
                .font(AcalumTypography.largeTitle)
                .foregroundStyle(.primary)

            Spacer()

            if !viewModel.networkMonitor.isConnected {
                Image(systemName: "wifi.slash")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }

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
        .animation(.easeInOut(duration: 0.3), value: viewModel.networkMonitor.isConnected)
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
