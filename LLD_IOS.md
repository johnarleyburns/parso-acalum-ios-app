# Low-Level Design — iOS App

## Module Structure

```text
ParsoMuseApp
 ├── App/
 │   ├── ParsoMuseApp.swift
 │   └── AppEnvironment.swift
 │
 ├── Features/
 │   ├── Player/
 │   │   ├── PlayerHomeView.swift
 │   │   ├── PlayerViewModel.swift
 │   │   ├── PlaybackControlsView.swift
 │   │   └── NowPlayingCardView.swift
 │   │
 │   ├── Discovery/
 │   │   ├── PromptBarView.swift
 │   │   ├── PillSelectorView.swift
 │   │   ├── Pill.swift
 │   │   └── DiscoveryContext.swift
 │   │
 │   ├── TrackInfo/
 │   │   ├── TrackInfoSheet.swift
 │   │   └── WhyThisSheet.swift
 │   │
 │   └── Settings/
 │       └── SettingsSheet.swift
 │
 ├── Audio/
 │   ├── AudioPlayerService.swift
 │   ├── PlaybackQueue.swift
 │   └── NowPlayingInfoService.swift
 │
 ├── Networking/
 │   ├── APIClient.swift
 │   ├── DTOs.swift
 │   └── Endpoint.swift
 │
 ├── Persistence/
 │   ├── LocalStore.swift
 │   ├── TrackCache.swift
 │   ├── FeedbackEventStore.swift
 │   └── SessionStore.swift
 │
 ├── Recommendation/
 │   ├── FeedbackTracker.swift
 │   ├── TasteSummaryBuilder.swift
 │   └── QueueCoordinator.swift
 │
 └── DesignSystem/
     ├── MuseButton.swift
     ├── MusePill.swift
     ├── MuseCard.swift
     ├── Typography.swift
     └── Spacing.swift
```

## Core Types

### Track

```swift
struct Track: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let composer: String?
    let performer: String?
    let sourceName: String
    let sourceURL: URL?
    let audioURL: URL
    let durationSeconds: Double
    let license: String?
    let year: Int?
    let explanation: TrackExplanation?
}
```

### TrackExplanation

```swift
struct TrackExplanation: Codable, Equatable {
    let reasons: [String]
    let matchedPills: [String]
    let similarityScore: Double?
    let userTasteScore: Double?
}
```

### Pill

```swift
enum PillCategory: String, Codable, CaseIterable {
    case instrument
    case mood
    case era
    case context
    case texture
}

struct Pill: Identifiable, Codable, Hashable {
    let id: String
    let label: String
    let category: PillCategory
}
```

### DiscoveryContext

```swift
struct DiscoveryContext: Codable, Equatable {
    var prompt: String?
    var selectedPills: [Pill]
    var dislikedTrackIDs: [String]
    var favoriteTrackIDs: [String]
    var recentlyPlayedTrackIDs: [String]
}
```

### FeedbackEvent

```swift
enum FeedbackEventType: String, Codable {
    case playStarted
    case playCompleted
    case skipped
    case favorited
    case unfavorited
    case replayed
    case promptChanged
    case pillSelected
    case pillRemoved
}

struct FeedbackEvent: Codable, Identifiable {
    let id: UUID
    let sessionID: String
    let trackID: String?
    let type: FeedbackEventType
    let timestamp: Date
    let listenSeconds: Double?
    let prompt: String?
    let selectedPillIDs: [String]
}
```

### PlaybackQueue

```swift
struct PlaybackQueue {
    var current: Track?
    var upcoming: [Track]
    var history: [Track]
}
```

## PlayerViewModel Responsibilities

```text
- expose current track
- expose playback state
- expose selected pills
- expose prompt
- handle play/pause
- handle skip
- handle favorite/unfavorite
- handle prompt submission
- handle pill toggles
- coordinate queue refresh
- coordinate feedback tracking
```

## AudioPlayerService

### Responsibilities

```text
- configure audio session
- play track URL
- pause
- resume
- observe playback progress
- notify when playback completes
- handle interruptions
- update now-playing metadata later
```

### Protocol

```swift
protocol AudioPlayerServiceProtocol {
    var state: PlaybackState { get }
    var currentTime: Double { get }
    var duration: Double { get }

    func play(track: Track)
    func pause()
    func resume()
    func stop()
}
```

### PlaybackState

```swift
enum PlaybackState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case failed(String)
}
```

## QueueCoordinator

### Responsibilities

```text
- keep 5-10 upcoming tracks
- fetch more when queue falls below threshold
- avoid recent repeats
- request backend recommendations from current DiscoveryContext
- avoid interrupting current playback when prompt/pills change
```

### Rules

```text
- Maintain at least 3 upcoming tracks.
- Request 10 tracks from backend when refilling.
- Do not repeat recent 25 tracks.
- Prompt changes affect upcoming tracks only.
- Skip immediately advances to next available track.
```

## FeedbackTracker

### Responsibilities

```text
- create feedback events
- persist unsent events locally
- batch-send events
- retry failed sends
- provide recent feedback summary to QueueCoordinator
```

## Local Persistence

MVP storage can use SwiftData, SQLite, or simple JSON files.

Recommended MVP:

- simple local JSON storage for prototype speed
- move to SQLite/SwiftData once shape stabilizes

Persist:

- session ID
- favorites
- recently played tracks
- unsent feedback events
- cached queue
- last active prompt/pills

## SwiftUI View Composition

```swift
struct PlayerHomeView: View {
    @StateObject var viewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: 20) {
            HeaderView()
            AmbientArtworkView(track: viewModel.currentTrack, isPlaying: viewModel.isPlaying)
            NowPlayingCardView(track: viewModel.currentTrack)
            PlaybackProgressView(progress: viewModel.progress)
            PlaybackControlsView(...)
            PillSelectorView(...)
            PromptBarView(...)
        }
        .sheet(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .whyThis: WhyThisSheet(track: viewModel.currentTrack)
            case .trackInfo: TrackInfoSheet(track: viewModel.currentTrack)
            case .settings: SettingsSheet()
            }
        }
    }
}
```

