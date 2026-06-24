# Acalum — Public Domain Music Discovery

An iOS app for continuous public-domain music discovery using semantic similarity search over CLAP embeddings, MFCC, chroma, metadata, and user feedback. No accounts, no server dependency, offline-capable.

Users shape a single continuous stream via instrument/mood/context/era pills, freeform natural-language prompts, skips, favorites, and listening duration.

## Current Status

- **v0.1.0** — Core player, mood matching, background audio, offline downloads, splash, app icon.
- **Build:** Green on iOS 17+ simulator and device.
- See [`current_state.md`](current_state.md) for detailed module status and recent changes.

## Stack

- Swift + SwiftUI, iOS 17+
- AVFoundation (AVPlayer + AVAudioSession) for audio playback
- MediaPlayer (MPRemoteCommandCenter + MPNowPlayingInfoCenter) for lock screen / background audio
- Core ML for CLAP text embedding (local on-device)
- SQLite via `parso_indexer.db` (copied from sibling project at build time)
- Accelerate (vDSP) for vector math
- XcodeGen (`project.yml`) for project generation
- Combine for reactive state

## Setup

```bash
# Generate Xcode project
xcodegen

# Build for simulator
xcodebuild -project Acalum.xcodeproj -scheme Acalum \
  -destination 'platform=iOS Simulator,id=FC7B2F90-A27B-4BD5-9313-7B267636E165' build

# Run tests
xcodebuild -project Acalum.xcodeproj -scheme Acalum \
  -destination 'platform=iOS Simulator,id=FC7B2F90-A27B-4BD5-9313-7B267636E165' test
```

> **Note:** Real-device builds required to test background audio, interruptions, and lock screen behavior.

## Architecture

| Module | Purpose |
|--------|---------|
| `App/` | Entry point, splash screen |
| `Audio/` | `AudioPlayerService`, `PlaybackQueue` |
| `Database/` | `LocalDatabase`, `VectorMath` |
| `DesignSystem/` | Spacing, typography, haptics, toasts |
| `Features/Player/` | Player UI, mood ring, progress, up-next |
| `Features/Discovery/` | Pill selector, prompt bar |
| `Features/Settings/` | Settings sheet |
| `LocalEmbedding/` | CLAP tokenizer, text embedding |
| `LocalSearch/` | Cosine vector search |
| `Models/` | Track, Pill, MoodMatch, DiscoveryContext |
| `Persistence/` | LocalStore, SeenHistory, TasteProfile, Downloads |
| `Recommendation/` | Mood scorer, calibrator, recommendation engine |

## Image Credits

- **Splash image:** "SAKURAKO listen to music" — Photo by MIKI Yoshihito (CC BY 2.0)

## License

Source code: MIT. Music: all sourced from the public domain.
