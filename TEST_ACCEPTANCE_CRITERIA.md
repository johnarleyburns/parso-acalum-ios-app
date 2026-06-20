# Test and Acceptance Criteria — Parso Muse

## Functional Tests

### App Launch

- App launches directly to PlayerHomeView.
- A current or placeholder track is visible.
- No login is required.

### Pill Selection

- Tapping a pill toggles selected state.
- Multiple pills can be selected.
- Selected pills are included in queue requests.
- Removing a pill updates recommendation context.

### Prompt Input

- User can type a prompt.
- Submitting prompt updates discovery context.
- Prompt submission does not stop current playback.
- Prompt is included in queue-generation request.

### Playback

- Play starts current track.
- Pause pauses current track.
- Skip advances to next track.
- Track completion advances automatically.
- Progress bar updates during playback.

### Queue

- App maintains upcoming tracks.
- Queue refresh occurs when upcoming count is low.
- Recent tracks are not immediately repeated.
- Current playback continues while queue refreshes.

### Favorite

- Favorite toggles immediately in UI.
- Favorite persists locally.
- Favorite event is logged.
- Favorite event is sent to backend or retained for retry.

### Feedback Events

- playStarted is logged.
- playCompleted is logged.
- skipped is logged with listenSeconds.
- favorited/unfavorited are logged.
- promptChanged is logged.
- pillSelected/pillRemoved are logged.

### Network Failure

- Queue fetch failure does not crash app.
- Existing queue remains playable.
- Unsent events persist.
- Retry works later.

## UX Acceptance Criteria

- User can understand app in under 10 seconds.
- Main experience fits on one screen.
- The app does not feel like a station directory.
- Prompt and pills feel like shaping one stream.
- “Why this?” explanation is easy to find but not intrusive.
- UI remains calm, uncluttered, and readable.

## Accessibility Criteria

- All primary controls have VoiceOver labels.
- Dynamic Type does not break layout.
- Controls remain tappable at larger text sizes.
- Selected pills have non-color indication.
- Error states are readable by VoiceOver.

## Regression Checks

Before merging changes, verify:

```text
- No tab bar added.
- No playlist management added.
- No station picker added.
- No login wall added.
- Current playback remains uninterrupted on prompt change.
- Feedback events are not lost on app restart.
- Queue does not repeat same track immediately.
```

## Suggested Unit Tests

- Pill toggle updates selected pill set.
- GenerateQueueRequest includes prompt and pills.
- FeedbackTracker persists unsent events.
- QueueCoordinator refills below threshold.
- Skip logs listen duration.
- Favorite persists locally.
- Track DTO maps to Track model.

## Suggested UI Tests

- Launch app and see player screen.
- Toggle Guitar pill.
- Enter prompt and submit.
- Tap favorite.
- Tap skip.
- Open Why This sheet.
- Open Track Info sheet.

