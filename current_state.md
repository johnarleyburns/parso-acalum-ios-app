# Current State — Acalum

Live progress tracker for the Acalum iOS app.

_Last updated: 2026-06-23 — Background audio fix, mood calibration, app icon, info.plist migration._

## Repo / branch

- Repo: `/Users/arley/github/parso-acalum-ios-app`
- **`main`** = All features merged. Builds + runs clean.
- Latest: `b78df3d` — explicit Info.plist with UIBackgroundModes array for background audio.

## What just shipped

### Background audio (Bugfix)
- **Root cause:** `INFOPLIST_KEY_UIBackgroundModes: audio` was a flat string that didn't produce the required array in the generated Info.plist — the `UIBackgroundModes` key was entirely absent.
- **Fix:** Created explicit `Acalum/Info.plist` via `project.yml` → `info:` block with `UIBackgroundModes: [audio]` as a proper array. Removed `GENERATE_INFOPLIST_FILE` and all `INFOPLIST_KEY_*` settings from target settings.
- **Also fixed:** `MPRemoteCommand.isEnabled = true` on all commands, `AVAudioSession.setActive(true)` on resume, `MPNowPlayingInfoPropertyMediaType` added, NowPlaying restored after interruption-end.

### Mood calibration (Bugfix)
- **Root cause:** `MoodIndexCalibrator` default `sHi=0.45` meant raw scores above ~0.5 saturated at 100% mood match.
- **Fix:** Raised `sHi` from `0.45` to `0.80`. With 2/2 tags + cosine 0.91, raw score 0.944 now maps to ~97% instead of 100%.

### Other bugfixes (bugs 1-5, feature 7 from BUGFIX_PLAN.md)
- **Bug 1:** Mood match formula now penalizes missing tags (`clapWeight * clap * max(tagRatio, 0.15) + tagWeight * tagRatio`).
- **Bug 2:** Skip advances within queue first, only regens when exhausted.
- **Bug 3:** `refreshUpcoming()` no longer calls `skipToNext()` — prevents silent track discard.
- **Bug 4:** `replaceQueueAndPlay()` plays first track directly instead of skipping it.
- **Bug 5:** Draggable time slider replaces non-interactive `ProgressView`. `seek(to:)` on `AudioPlayerService` + `PlayerViewModel`.
- **Feature 7:** Tap Up Next track to play immediately via `queue.jumpTo(index:)`.

### App icon + splash
- **App icon:** Generated 14 iOS icon sizes (20–1024) from `acalum_app_logo.jpeg` (1024×1024).
- **Splash:** Replaced with cropped portrait version of "SAKURAKO listen to music" (1242×2688).

## Module map
| Module | Status |
|--------|--------|
| `App/` | Done — splash, app entry |
| `Audio/` | Done — AVPlayer, background audio, remote commands, NowPlaying |
| `Database/` | Done — LocalDatabase, VectorMath |
| `DesignSystem/` | Done — Spacing, Typography, Haptic, Toast |
| `Features/Player/` | Done — player, mood ring, progress slider, up-next tap |
| `Features/Discovery/` | Done — pills, prompt bar |
| `Features/Settings/` | Done — settings sheet |
| `Features/TrackInfo/` | Done — why-this, track info sheets |
| `LocalEmbedding/` | Done — CLAP tokenizer, text embedding, Embedding512 |
| `LocalSearch/` | Done — cosine search, vector records |
| `Models/` | Done — Track, Pill, MoodMatch, DiscoveryContext, FeedbackEvent |
| `Networking/` | Stub — APIClient, SyncManager, DTOs |
| `Persistence/` | Done — LocalStore, SeenHistory, TasteProfile, DownloadManager, NetworkMonitor |
| `Recommendation/` | Done — scorer, calibrator, recommendation engine, rotation, feedback, taste vector |

## Tests
17 test files under `AcalumTests/`. All modules have at least basic coverage.

## Notes / decisions in effect
- No accounts, no server dependency, offline-capable with downloads.
- Database (`parso_indexer.db`) copied from sibling `parso-ia-music-indexer` project.
- Project generated via `xcodegen` — edit `project.yml`, not `.xcodeproj`.
- `Info.plist` generated via `project.yml` → `info:` block — do not hand-edit.
- All merges to `main` are fast-forward.
