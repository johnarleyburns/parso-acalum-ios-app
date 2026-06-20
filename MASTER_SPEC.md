# Parso Muse — Consolidated Agentic Coding Spec

## Product Sentence

Describe how you want the music to feel, and Parso Muse continuously finds public-domain music that fits.

## Vision

Parso Muse is an iOS app for continuous public-domain music discovery. The user does not choose stations, playlists, or albums. The user shapes a single living stream with mood/instrument/context/era pills, freeform prompts, skips, favorites, and listen behavior.

The backend searches over CLAP 512-dimensional embeddings, MFCC vectors, chroma vectors, metadata, tags, and user taste vectors.

## MVP Scope

Must include:

- one continuous playback queue
- prompt input
- pill selection
- skip
- favorite
- listen tracking
- queue generation API
- basic taste loop
- Why This explanation
- track detail sheet
- local feedback cache

Must not include:

- accounts
- stations
- playlists
- album browsing
- tab bar
- social features
- monetization

## Main UX

```text
┌────────────────────────────────────┐
│  Parso Muse                   ⚙︎   │
│                                    │
│        ┌──────────────────┐        │
│        │   Ambient Art     │        │
│        └──────────────────┘        │
│                                    │
│     Current Track Title            │
│     Composer · Performer           │
│                                    │
│       ━━━━━━━●━━━━━━━━             │
│                                    │
│      ♡        ⏯        ⏭          │
│                                    │
│  [Guitar] [Calm] [Romantic]        │
│  [Old Europe] [Reading] [+]        │
│                                    │
│  ┌──────────────────────────────┐  │
│  │ quiet spanish guitar at dusk │  │
│  └──────────────────────────────┘  │
│                                    │
└────────────────────────────────────┘
```

## Navigation

```text
RootView
 └── PlayerHomeView
      ├── PromptBar
      ├── PillSelector
      ├── PlaybackControls
      ├── TrackInfoSheet
      ├── WhyThisSheet
      └── SettingsSheet
```

## iOS Architecture

```text
ParsoMuseApp
 ├── App/
 ├── Features/
 │   ├── Player/
 │   ├── Discovery/
 │   ├── TrackInfo/
 │   └── Settings/
 ├── Audio/
 ├── Networking/
 ├── Persistence/
 ├── Recommendation/
 └── DesignSystem/
```

## Core Swift Types

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

struct TrackExplanation: Codable, Equatable {
    let reasons: [String]
    let matchedPills: [String]
    let similarityScore: Double?
    let userTasteScore: Double?
}

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
```

## Backend HLD

```text
┌──────────────┐ HTTPS ┌──────────────┐
│   iOS App    ├──────►│ API Backend  │
└──────────────┘       └──────┬───────┘
                              ▼
                       ┌──────────────┐
                       │ Recommender  │
                       └──────┬───────┘
                              ▼
                       ┌──────────────┐
                       │ Postgres +   │
                       │ pgvector     │
                       └──────────────┘
```

## Queue API

```http
POST /v1/queue/generate
```

Request:

```json
{
  "session_id": "abc123",
  "prompt": "quiet spanish guitar at dusk",
  "selected_pills": ["instrument:guitar", "mood:calm"],
  "recent_track_ids": ["t1", "t2"],
  "favorite_track_ids": ["t9"],
  "skip_track_ids": ["t5"],
  "limit": 10
}
```

Response:

```json
{
  "tracks": [
    {
      "id": "track_123",
      "title": "Recuerdos de la Alhambra",
      "composer": "Francisco Tárrega",
      "performer": "Andrés Segovia",
      "audio_url": "https://example.com/audio.mp3",
      "duration_seconds": 236,
      "source_name": "Internet Archive",
      "source_url": "https://archive.org/details/example",
      "license": "Public Domain",
      "year": 1930,
      "explanation": {
        "reasons": ["Matches guitar", "Matches calm mood"],
        "matched_pills": ["Guitar", "Calm"],
        "similarity_score": 0.91,
        "user_taste_score": 0.74
      }
    }
  ]
}
```

## Recommendation Formula

```text
final_score =
  0.50 * clap_similarity
+ 0.15 * mfcc_similarity
+ 0.10 * chroma_similarity
+ 0.15 * user_taste_similarity
+ 0.05 * metadata_match
+ 0.05 * novelty_score
- repeat_penalty
- skip_similarity_penalty
```

## Taste Vector

```text
taste_vector =
  avg(favorited_tracks * 3.0)
+ avg(completed_tracks * 1.5)
- avg(skipped_tracks * 1.5)
```

Normalize after update.

## Phases

### Phase 0 — Static UI

- SwiftUI shell
- mock track
- artwork view
- controls
- pills
- prompt field

### Phase 1 — Local Playback

- AVPlayer
- mock queue
- play/pause/skip
- progress

### Phase 2 — Backend Queue

- APIClient
- queue endpoint
- prompt and pill requests
- QueueCoordinator

### Phase 3 — Feedback Loop

- FeedbackTracker
- local event persistence
- batch event sync
- favorite persistence

### Phase 4 — Explanation

- WhyThisSheet
- TrackInfoSheet
- source/license display

### Phase 5 — Polish

- haptics
- subtle animation
- error/loading states
- lock-screen metadata
- accessibility
- Dynamic Type

## Key Decision Defaults

- App name: Parso Muse
- First seeds: Spanish Guitar, Peaceful Piano, Sacred Choir, Early Jazz, Reading Music, Sleep Music
- Prompt changes affect upcoming tracks only
- Skip timing determines negative feedback strength
- Source/license in detail sheet, not always visible
- MVP recommendations are server-first
- MVP artwork is generated abstract artwork

## Master Agent Prompt

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

