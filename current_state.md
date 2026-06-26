# Current State — Acalum

Live progress tracker for the Acalum iOS app.

_Last updated: 2026-06-26 — Queue-generation race fix; listenability gate, catalog-backed discovery, Previous, IA links, fade fix._

## Repo / branch

- Repo: `/Users/arley/github/parso-acalum-ios-app`
- **`main`** = All features merged. Builds + runs clean.
- Latest: queue-generation race fix on top of the listenability/discovery/playback overhaul.

## What just shipped

### Queue-generation race fix

`PlayerViewModel`'s async queue methods each spawn a task that `await`s `generateQueue` and then mutates the shared queue, so a stale task could resume *after* a newer operation and clobber it — the init `refreshQueue` could append onto a fresh Play-now queue and push a phantom Previous entry (a track that was only transiently surfaced).

- Added a monotonic `queueGeneration` token. Authoritative ops (`refreshQueue`, `replaceQueueAndPlay`, `refreshUpcoming`, `moreLikeThis`) call `beginQueueGeneration()` synchronously before spawning; the incremental `refillStableQueueIfNeeded` captures the current token without bumping. Every task re-checks `guard generation == queueGeneration` after its `await` and discards its result if superseded. Chosen over task cancellation because it's correct regardless of whether `generateQueue` is cooperatively cancellable.
- Added a non-invasive test seam: `NetworkMonitor(startMonitoring:)` (defaults `true`; production unchanged) so `NWPathMonitor`'s unpredictable one-shot can't fire a mid-test refresh.
- New deterministic regression test `testStaleInitRefreshDoesNotClobberPlayNow` with a `GatedQueueService` (suspends each `generateQueue` until released, tags tracks by call order). Verified it **fails without the guard** (stale refresh pollutes `upNext` with `gen1_*` tracks) and passes with it. Suite now **155** tests, all green.

### Listenability, Discovery, and Playback overhaul

Implements `ACALUM_LISTENABILITY_DISCOVERY_PLAN.md` (7 phases).

- **Listenability catalog gate (Phase 1).** `LocalDatabase.loadTracks()` detects the indexer's `listenability_*` columns via `PRAGMA table_info` and, when present, filters the default catalog to `listenability_decision='include' AND listenability_stream='default'` (completed + embedded). Old DBs without the columns fall back to the prior query and log it. `TrackVectorRecord`/`Track` gained optional listenability fields (`Listenability` struct: score, tier, decision, stream, reasons, components; JSON reasons/components parsed). Verified bundled DB: **10** listenability columns, **16,246** include/default embedded tracks. No longform/excluded rows enter the default stream.
- **Catalog-backed pills + Fit model (Phase 2).** New `PillRegistry` replaces the old mood-heavy set with **Sound / Style / Tradition / Listening Mode** pills grounded in real catalog counts (Classical, Orchestra, Baroque, Folk & World, Jazz, Opera, Vocal/Choir, Piano, Organ, Guitar, Latin/Bossa, African, Gregorian Chant, Indian Classical, Gamelan, Stage & Screen, Easy Listening, Romantic Era). `Pill` now splits `embeddingPhrase` (CLAP retrieval) from strict `metadataTerms`/`negativeTerms` (literal tag match). Listening-mode pills are semantic-only — they shape direction via CLAP and **never** assert a metadata match. `MoodMatchScorer` only counts metadata-capable pills toward the tag ratio, so generic words (`music`, `classical`) no longer create false "tag present" claims. UI/summary copy reframed Mood → **Fit/Direction**.
- **Listenability ranking nudge (Phase 3).** `LocalRecommendationEngine` orders the queue by `wFit·fit + wLex·lex + wListen·listen` (0.50/0.30/0.20 with explicit intent; 0.45/0.25/0.30 promptless). Listenability never enters the displayed Fit index. Listenability is mapped onto each `Track`.
- **Internet Archive links (Phase 4).** `openURL(track.sourceURL)` links on the Now Playing card, every Up Next row (trailing icon), and a full-width row in Track Info (which also shows a "Stream quality: tier (score)" line). Logs a `.sourceOpened` feedback event. Now Playing also exposes a Details button to open Track Info.
- **Persistent Previous back stack (Phase 5).** New `PlaybackHistoryStore` (depth 50, persisted to `UserDefaults`, survives restarts). New Previous button (disabled when empty) and lock-screen Previous command. Previous pops the last listened track, places the current track at the front of upcoming (so Next returns to it), uses a previous-specific fade, and does **not** log skip/dislike.
- **Fade reliability + remote semantics (Phase 6).** `AudioPlayerService` now tracks every scheduled volume-ramp work item and cancels them all before each transition (no stale ramps under rapid skip/previous/play). Previous uses `fadeOutIn(0.35, 0.55)`. Lock-screen **Next** now uses skip semantics (`onSkipRequested`), not completion, so it logs a skip rather than a play-completed.
- **UI flow polish (Phase 7).** Up Next moved above the discovery controls. Discovery now offers **Update upcoming** (non-interrupting default) and **Play now** (immediate). Prompt bar gained a real **Update** button; clearing the prompt edits the draft only. Keyboard submit behaves like Update upcoming. Fit ring relabeled.

Verification: full build **green**; **154** tests pass (added/updated `LocalDatabaseTests` listenability + fallback, `PillTests`, `MoodMatchScorerTests` strict-metadata + generic-word, `LocalRecommendationEngineTests` listenability ranking/Fit-isolation, `PlaybackHistoryStoreTests`, `PlayerViewModelTests` previous behavior + non-interrupting prompt).

## What previously shipped

### Inline why breakdown phrase-match display
- The visible inline **"`summary` · why"** breakdown now renders the existing phrase-match metadata from `MoodMatch`: matched prompt words plus the "Full phrase appears in metadata" badge when applicable.
- This closes the gap where phrase matching was computed by `MoodMatchScorer` and shown only in the older `WhyThisSheet`, while the player UI actually presented `MatchDetailsView`.
- No scoring, retrieval, queueing, or mood-index behavior changed.
- Verification: `MoodMatchScorerTests` focused suite passed (12 tests, 0 failures); simulator build passed.

### More Like This, Stable Up Next, and Smooth Mood Transitions
- **Visible Up Next** now shows max 4 tracks (internal queue targets 8 for smooth playback). Normal skips/track completions preserve queue order and append only 1 track at the tail. Whole Up Next replacement only happens on explicit mood apply.
- **"More like this" button** (sparkles icon) nudges future recommendations toward the current track via CLAP-vector blending (0.65 mood + 0.35 seed when mood exists, seed-only otherwise). Does not favorite or disrupt current playback. Clears on mood apply.
- **Audio fade transitions:** manual skip/Up Next tap uses fade-out 0.55s + fade-in 0.75s; mood start-now uses longer fade-out 0.9s + fade-in 1.1s; natural completion uses fade-in 0.35s. AVPlayer volume ramps cancel on repeated skips.
- **Mood transition graphic:** `MoodSignature` (pill IDs + prompt) drives a deterministic palette overlay on `AmbientArtworkView` during mood changes. Transitions in over 1.2s, fades out after 1.5s. Respects Reduce Motion (cross-dissolve only).
- **RotationPlanner fix:** refill path now excludes seen tracks (was only checking disliked/chosen), closing a gap where recently played tracks could be re-recommended during queue starvation.

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
21 test files under `AcalumTests/`. 155 tests, all green. New since prior: `testStaleInitRefreshDoesNotClobberPlayNow` (queue-generation race regression, with a gated queue service); `PlaybackHistoryStoreTests` (LIFO/dedup/capacity/persistence), listenability cases in `LocalDatabaseTests`, strict-metadata + generic-word cases in `MoodMatchScorerTests`, listenability ranking/Fit-isolation in `LocalRecommendationEngineTests`, Previous behavior + non-interrupting prompt in `PlayerViewModelTests`.

## Notes / decisions in effect
- No accounts, no server dependency, offline-capable with downloads.
- Database (`parso_indexer.db`) copied from sibling `parso-ia-music-indexer` project.
- Project generated via `xcodegen` — edit `project.yml`, not `.xcodeproj`.
- `Info.plist` generated via `project.yml` → `info:` block — do not hand-edit.
- All merges to `main` are fast-forward.
