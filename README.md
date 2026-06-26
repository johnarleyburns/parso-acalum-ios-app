# Acalum — Public Domain Music Discovery

An iOS app for continuous public-domain music discovery using semantic similarity search over CLAP embeddings, MFCC, chroma, metadata, and user feedback. No accounts, no server dependency, offline-capable.

Users shape a single continuous stream via Sound / Style / Tradition / Listening Mode pills, freeform natural-language prompts, skips, favorites, and listening duration.

## Current Status

- **v0.1.0** — Core player, Fit matching, background audio, offline downloads, splash, app icon.
- **Listenable catalog:** the default stream is gated to the indexer's listenability `include`/`default` tracks (~16k), so short clips, sound effects, speech, channel dumps, and overlong tracks are excluded.
- **Discovery:** catalog-backed pills grouped as **Sound** (instruments/ensembles), **Style** (genre/form), **Tradition** (period/region/collection), and **Listening Mode** (quiet, focus, reading, sleep, explore — semantic direction only). Pills split their CLAP phrase from strict metadata terms so generic words don't claim false tag matches.
- **Retrieval:** hybrid — lexical metadata match (curated `tags`/genres/title) unioned with CLAP cosine. Listenability is a ranking nudge only and never enters the displayed Fit index. Degrades to lexical (never random) when the CLAP text model is not bundled.
- **Playback:** Update upcoming (non-interrupting) vs Play now; a persistent Previous back stack (depth 50, survives restarts); reliable fades under rapid skip/previous/play; lock-screen Previous/Next wired with skip semantics.
- **Links:** every visible track has an Internet Archive link (Now Playing, Up Next rows, Track Info).
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
| `LocalSearch/` | Hybrid lexical + CLAP cosine retrieval |
| `Models/` | Track, Pill, MoodMatch, DiscoveryContext |
| `Persistence/` | LocalStore, SeenHistory, TasteProfile, Downloads |
| `Recommendation/` | Mood scorer, calibrator, recommendation engine |

## Image Credits

- **Splash image:** "SAKURAKO listen to music" — Photo by MIKI Yoshihito (CC BY 2.0)

## License

Source code: MIT. Music: all sourced from the public domain.
