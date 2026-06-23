# Acalum Bug Fix & Feature Plan

## Bug 1: 100% Mood Match Despite Mismatched Tags

**Symptom**: User selects "guitar", "nostalgic", "medieval" pills. Playing track is Indian classical (only acoustic match is high). Report shows:
- Acoustic character cosine 0.88 (matched)
- Instrument: guitar tag present (1/3 matched)
- Era: medieval not tagged (0/3)
- Mood: nostalgic not tagged (0/3)
Yet mood ring shows **100%**.

**Root Cause** (`MoodMatchScorer.swift:35-37`):
```
raw = clamp01(0.62 * clap + 0.38 * tag)
```
CLAP cosine (0.88) and tag fraction (0.33) are additive. The 0.62 weight on CLAP dominates:
- raw = 0.62*0.88 + 0.38*0.33 = 0.672
- logistic calibrator maps 0.672 → ~100% (saturates above sHi=0.45)

**Fix**: Scale CLAP contribution by tag match ratio so missing tags penalize the score:
```
tagRatio = pills.isEmpty ? 1.0 : matched / pills.count
raw = clamp01(clapWeight * clamp01(clap) * max(tagRatio, 0.15) + tagWeight * tagRatio)
```
- 1/3 tags + clap=0.88 → ~55% ("partial match", correct)
- 3/3 tags + clap=0.88 → ~100% (still achievable)
- 0/3 tags + any clap → very low (correctly "not a match")

**Files**: `Acalum/Recommendation/MoodMatchScorer.swift`, `AcalumTests/MoodMatchScorerTests.swift`

---

## Bug 2: ">>" Skip Resets Entire Up Next List

**Symptom**: Clicking ">>" goes to a completely different track and the whole Up Next list changes.

**Root Cause** (`PlayerViewModel.swift:165-177`): `skip()` calls `replaceQueueAndPlay()` which does a full `audioService.stop()` + async queue regeneration, discarding the existing upcoming list.

**Fix**: Lightweight skip — advance within existing queue, only regen when queue is exhausted:
```swift
func skip() {
    // log feedback + taste (unchanged)
    if let next = queue.skipToNext() {
        surface(next)
        upNext = queue.upcoming
    } else {
        replaceQueueAndPlay()
    }
}
```

**Files**: `Acalum/Features/Player/PlayerViewModel.swift`

---

## Bug 3: applyMood(startNow: false) Skips a Track

**Symptom**: Applying mood without restarting causes the first upcoming track to be silently discarded.

**Root Cause** (`PlayerViewModel.swift:317-324`): `refreshUpcoming()` creates a new `PlaybackQueue` with `currentTrack + generatedTracks`, then immediately calls `skipToNext()`, which moves current to history and promotes `generatedTracks[0]` as the new queue.current. This is inconsistent with ViewModel.currentTrack and causes `generatedTracks[0]` to go to history when `handleTrackFinished()` fires.

**Fix**: Remove the `skipToNext()` call. The queue will correctly have `current = currentTrack` and `upcoming = generatedTracks`. `handleTrackFinished()` will naturally advance when the track ends.

**Files**: `Acalum/Features/Player/PlayerViewModel.swift` — `refreshUpcoming()`

---

## Bug 4: replaceQueueAndPlay() Discards Best Match

**Symptom**: The first (best-ranked) track from the recommendation engine is never played.

**Root Cause** (`PlayerViewModel.swift:258-263`): `replaceQueueAndPlay()` creates `PlaybackQueue`, then immediately calls `skipToNext()`, sending `tracks[0]` to history and playing `tracks[1]`.

**Fix**: Play the first track directly:
```swift
if let next = self.queue.current {
    self.surface(next)
}
self.upNext = self.queue.upcoming
```

**Files**: `Acalum/Features/Player/PlayerViewModel.swift` — `replaceQueueAndPlay()`

---

## Bug 5: No Draggable Time Slider

**Symptom**: Elapsed/remaining time display has no draggable "." control. Users cannot scrub through the track.

**Root Cause** (`PlayerHomeView.swift:166`): Uses non-interactive `ProgressView(value:)` instead of `Slider`. No seek API exists in protocol or ViewModel.

**Fix**:
1. Add `seek(to:)` to `AudioPlayerServiceProtocol` and `AudioPlayerService`
2. Add `seek(to:)` to `PlayerViewModel`
3. Replace `ProgressView` with `Slider` bound to local drag state
4. Show remaining time alongside elapsed

**Files**: `Acalum/Audio/AudioPlayerService.swift`, `Acalum/Features/Player/PlayerViewModel.swift`, `Acalum/Features/Player/PlayerHomeView.swift`

---

## Bug 6: Background Audio Stops When Switching Apps

**Symptom**: Music stops when switching to another app.

**Root Cause**: Though `UIBackgroundModes = audio` is configured in project.pbxproj, `play(url:)` calls `stop()` → `clearNowPlaying()` which wipes `MPNowPlayingInfoCenter` metadata. The `$currentTrack` sink (which calls `updateNowPlaying`) fires BEFORE `play()` clears it, so NowPlaying info stays nil during playback. iOS uses this metadata as a key signal to keep audio alive in background.

**Fix**:
1. In `surface()`, re-set NowPlaying info **after** `play()` so it survives the `stop()` → `clearNowPlaying()` cycle
2. In `play()`, re-activate the `AVAudioSession` before starting the new player

**Files**: `Acalum/Features/Player/PlayerViewModel.swift` — `surface()`, `Acalum/Audio/AudioPlayerService.swift` — `play()`

---

## Feature 7: Tap Up Next Track to Play Immediately

**Request**: Tapping a track in the Up Next list starts it immediately while preserving the rest of the queue. Current track moves to history, skipped upcoming tracks also move to history.

**Implementation**:
1. `PlaybackQueue.swift`: Add `jumpTo(index:)` — moves current + `upcoming[0..<index]` to history, makes `upcoming[index]` current
2. `PlayerViewModel.swift`: Add `playFromUpNext(at:)` — logs skip feedback, jumps queue, surfaces tapped track
3. `UpNextListView.swift`: Add `onTap` callback, pass to rows
4. `PlayerHomeView.swift`: Wire callback

**Files**: `Acalum/Audio/PlaybackQueue.swift`, `Acalum/Features/Player/PlayerViewModel.swift`, `Acalum/Features/Player/UpNextListView.swift`, `Acalum/Features/Player/PlayerHomeView.swift`

---

## Implementation Order

1. Write plan (done)
2. Queue bugs 2-4 (closely related, same file)
3. Mood match bug 1 + update tests
4. Tap to play feature 7
5. Time slider bug 5
6. Background audio bug 6
7. Update all remaining tests
8. Build and verify
