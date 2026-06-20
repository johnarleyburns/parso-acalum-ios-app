# Agentic Coding Prompts — Parso Muse

## Master Coding Prompt

```text
Build an iOS SwiftUI prototype for Parso Muse, a public-domain semantic music discovery app.

The app has one primary screen: a continuous music player with ambient artwork, track metadata, playback controls, selectable mood/instrument/context pills, and a freeform prompt input.

Do not build stations, tabs, album browsing, or playlists.

Architecture:
- SwiftUI views
- PlayerViewModel
- AudioPlayerService using AVPlayer
- PlaybackQueue
- APIClient with mockable queue endpoint
- FeedbackTracker
- Local persistence for favorites and unsent feedback events

MVP behavior:
- App launches into PlayerHomeView.
- Shows current track.
- User can play/pause/skip/favorite.
- User can select pills.
- User can enter a prompt.
- Prompt/pill changes call a queue generation function.
- Current playback continues while upcoming queue refreshes.
- Feedback events are logged locally.
- A “Why this?” sheet explains recommendation reasons.

Use mock data first. Keep all code modular and testable.
```

## Phase 0 Prompt — Static UI

```text
Implement Phase 0 only.

Create a compileable SwiftUI iOS app with a single PlayerHomeView. Use mock track data. Do not implement real audio or networking yet.

Views to create:
- PlayerHomeView
- AmbientArtworkView
- NowPlayingCardView
- PlaybackControlsView
- PillSelectorView
- PromptBarView

Behavior:
- Pills toggle selected/unselected.
- Prompt text can be entered.
- Playback buttons can visually respond but do not need real behavior.
- Layout should match the ASCII wireframe.

Keep components modular under Features and DesignSystem folders.
```

## Phase 1 Prompt — Local Playback

```text
Implement Phase 1.

Add local playback using AVPlayer and a mock queue of public audio URLs.

Create:
- AudioPlayerService
- PlaybackQueue
- PlaybackState

Behavior:
- Play/pause current track.
- Observe playback progress.
- Skip advances to the next mock track.
- UI updates with current track and playback state.
- Current track completion advances automatically.

Do not add backend networking yet.
```

## Phase 2 Prompt — Backend Queue Integration

```text
Implement Phase 2.

Add APIClient and DTOs for POST /v1/queue/generate.

Behavior:
- Prompt submission calls queue generation.
- Pill changes call queue generation after a short debounce.
- Current track continues playing while upcoming tracks refresh.
- QueueCoordinator maintains at least 3 upcoming tracks.
- Backend response maps into Track models.

Keep APIClient mockable for tests.
```

## Phase 3 Prompt — Feedback Loop

```text
Implement Phase 3.

Add FeedbackTracker and local persistence for unsent feedback events.

Track events:
- playStarted
- playCompleted
- skipped
- favorited
- unfavorited
- promptChanged
- pillSelected
- pillRemoved

Behavior:
- Events are stored locally first.
- Events are batch-sent to POST /v1/events.
- Failed sends remain queued for retry.
- Favorites persist locally immediately.
- Recent feedback is included in queue generation requests.
```

## Phase 4 Prompt — Explanation UI

```text
Implement Phase 4.

Add WhyThisSheet and TrackInfoSheet.

Behavior:
- User can open explanation for current track.
- Show explanation.reasons.
- Show matched pills.
- Show source name, license, year, composer, performer.
- Add source URL button when available.

Keep the UI calm and readable.
```

## Phase 5 Prompt — Polish

```text
Implement Phase 5 polish.

Add:
- haptic feedback for favorite, skip, pill toggle
- subtle artwork animation
- empty/error states
- loading microcopy
- audio interruption handling
- lock-screen now-playing metadata
- accessibility labels
- Dynamic Type support

Do not add new product complexity. Preserve the one-screen app concept.
```

## Guardrail Prompt for Coding Agent

```text
Important product constraints:

Do not add stations.
Do not add a tab bar.
Do not add album browsing.
Do not add playlists.
Do not add social features.
Do not require login.
Do not interrupt current playback when prompt or pills change.
Do not make the UI look like Spotify.

The product is one continuous adaptive stream shaped by prompt, pills, and feedback.
```

