# Phased Implementation Plan — Parso Muse

## Phase 0 — Static SwiftUI Skeleton

### Goal

Create a compileable app with the target visual shape and mock data.

### Tasks

```text
1. Create SwiftUI iOS app.
2. Add PlayerHomeView.
3. Add static mock Track.
4. Build AmbientArtworkView.
5. Build PlaybackControlsView.
6. Build PillSelectorView.
7. Build PromptBarView.
8. No networking yet.
9. No real audio yet.
```

### Acceptance Criteria

```text
- App launches.
- Main screen matches ASCII layout.
- Pills toggle.
- Prompt text can be entered.
- Mock track displays.
```

## Phase 1 — Local Playback Prototype

### Goal

Play audio from hardcoded public URLs using a local mock queue.

### Tasks

```text
1. Implement AudioPlayerService using AVPlayer.
2. Add play/pause.
3. Add progress observation.
4. Add skip against mock queue.
5. Add basic playback state.
6. Add local queue with 5 mock tracks.
```

### Acceptance Criteria

```text
- User can play/pause.
- Track progress updates.
- Skip advances to next track.
- UI updates current track.
```

## Phase 2 — Backend Queue Integration

### Goal

Fetch real recommendation queues from backend.

### Tasks

```text
1. Add APIClient.
2. Add /v1/queue/generate DTOs.
3. Add QueueCoordinator.
4. Prompt submit calls backend.
5. Pill change triggers queue refresh.
6. Maintain current playback while refreshing upcoming queue.
```

### Acceptance Criteria

```text
- Prompt returns real tracks.
- Pills affect API request.
- Queue does not stop during refresh.
- Skip uses next real track.
```

## Phase 3 — Feedback Loop

### Goal

Capture user behavior and feed it into future recommendations.

### Tasks

```text
1. Implement FeedbackTracker.
2. Log playStarted, skipped, favorited, completed.
3. Batch-send events to /v1/events.
4. Store unsent events locally.
5. Retry failed sends.
6. Include recent feedback in queue request.
```

### Acceptance Criteria

```text
- Skip/favorite events reach backend.
- Offline events are stored.
- Later sync works.
- Backend can use events in recommendations.
```

## Phase 4 — Explanation and Trust

### Goal

Make recommendations understandable.

### Tasks

```text
1. Add WhyThisSheet.
2. Display explanation.reasons.
3. Display source and license.
4. Add TrackInfoSheet.
5. Link to source URL.
```

### Acceptance Criteria

```text
- User can open "Why this?"
- Reasons are human-readable.
- Source and license are visible.
```

## Phase 5 — Polish

### Goal

Make the app feel native and Apple-quality.

### Tasks

```text
1. Add haptics.
2. Add subtle artwork animation.
3. Add empty/error states.
4. Add loading microcopy.
5. Add interruption handling.
6. Add lock-screen now-playing metadata.
7. Add accessibility labels.
8. Add Dynamic Type support.
```

### Acceptance Criteria

```text
- App feels polished.
- VoiceOver labels exist.
- Large text does not break layout.
- Audio survives common interruptions gracefully.
```

## Phase 6 — Optional Future Enhancements

Potential later features:

- offline cache/downloads
- optional account sync
- richer local vector search
- fully local taste profile
- public-domain cover art ingestion
- curated editorial seed journeys
- better personal taste reset controls
- “more like this” control
- “less like this” control
- CarPlay later if product matures

