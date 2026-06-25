# Current State — Acalum

Live progress tracker for the Acalum iOS app.

_Last updated: 2026-06-25 — "Why this track?" phrase-match section + acoustic-character cleanup._

## Repo / branch

- Repo: `/Users/arley/github/parso-acalum-ios-app`
- **`main`** = All features merged. Builds + runs clean.
- Latest: `b78df3d` — explicit Info.plist with UIBackgroundModes array for background audio.

## What just shipped

### "Why this track?" phrase matching + acoustic cleanup
- `WhyThisSheet` now shows a **"Matched your phrase"** section when a freeform prompt is entered, listing which prompt words appear in the track's metadata, plus a "Full phrase appears in metadata" badge when the whole phrase is present verbatim.
- `MoodMatchScorer.score` gained a `prompt` parameter; it tokenizes the prompt (stopwords filtered, like pill matching) and substring-matches each word against the same `searchable(record)` text used for pills. Display-only — the mood-index math is unchanged. New fields `matchedPhraseTerms` / `phraseMatchedVerbatim` flow through `MoodMatch` → `TrackExplanation` (defaulted, so DTO/mocks are unaffected).
- **Cleanup:** the "Acoustic character" component no longer leaks into the "Matched pills" list (`mapToTrack` excludes `MoodMatchScorer.acousticLabel`).
- _Note on matching channels:_ the prompt drives retrieval two ways — (1) semantic CLAP cosine over the whole phrase's meaning (one embedding, no per-word attribution; shown as "Acoustic character"), and (2) lexical word+phrase overlap in `LexicalIndex`. The new sheet section reflects the lexical word-level hits only.

### Hybrid lexical + CLAP retrieval (Recommendation fix)
- **Root cause:** retrieval was 100% CLAP-vector cosine and ignored the metadata (`tags`, `genres`, `subjects`, `title`, `composer`) already loaded on each `TrackVectorRecord`. Pills never drove retrieval (only embedded when a prompt existed; taste vectors ran *before* pills); and a missing CLAP text model silently collapsed to random picks. Net effect: "Spanish Guitar", the Guitar pill, and "gregorian chant" surfaced none of the matching tracks.
- **Phase 1 — Observable model status:** `AcalumApp.makeTextEmbeddingService()` now logs ENABLED/DISABLED and exposes `semanticSearchAvailable`. No more silent failure.
- **Phase 2 — Hybrid retrieval:** new `LocalSearch/LexicalIndex.swift` (in-memory lexical index over the indexer's precomputed `tags` bag + title/composer/album text, with phrase bonus). `LocalRecommendationEngine.generateQueue` now unions the lexical channel with CLAP top-k, fuses (`0.5·clap + 0.5·lex`), scores with the **true** CLAP cosine so the calibrated mood index is preserved, and orders the queue by a blend of mood index and lexical match. Favorites are **no longer excluded** from results (only disliked tracks are). Degrades to lexical (never random) when the model is absent.
- **Phase 3 — Intent before taste:** `buildQueryVector` embeds any explicit intent (prompt **or** pills, via `QueryTextBuilder`) before consulting taste; taste (factored into `currentTasteVector()`) is now only a fallback for genuinely empty context. Removed the old pill-title-substring seed.
- **Phase 4 (MFCC/chroma fusion):** intentionally skipped per plan (audio→audio only; not required to close the bugs).


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
| `LocalSearch/` | Done — hybrid lexical + cosine search, lexical index, vector records |
| `Models/` | Done — Track, Pill, MoodMatch, DiscoveryContext, FeedbackEvent |
| `Networking/` | Stub — APIClient, SyncManager, DTOs |
| `Persistence/` | Done — LocalStore, SeenHistory, TasteProfile, DownloadManager, NetworkMonitor |
| `Recommendation/` | Done — scorer, calibrator, recommendation engine, rotation, feedback, taste vector |

## Tests
19 test files under `AcalumTests/`. 118 tests, all green. New: `MoodMatchScorerTests` phrase-match cases (term presence, stopword filtering, verbatim phrase, empty prompt); earlier: `LexicalIndexTests`, `LocalRecommendationEngineTests` (lexical union, favorites-retained, intent-before-taste).

## Notes / decisions in effect
- No accounts, no server dependency, offline-capable with downloads.
- Database (`parso_indexer.db`) copied from sibling `parso-ia-music-indexer` project.
- Project generated via `xcodegen` — edit `project.yml`, not `.xcodeproj`.
- `Info.plist` generated via `project.yml` → `info:` block — do not hand-edit.
- All merges to `main` are fast-forward.
