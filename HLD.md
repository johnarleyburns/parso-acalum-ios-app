# High-Level Design — Parso Muse

## System Overview

```text
┌────────────────────────────────────┐
│ iOS App                             │
│ SwiftUI + AVFoundation              │
│                                     │
│ - Player UI                         │
│ - Prompt/pill state                 │
│ - Local feedback cache              │
│ - Playback queue                    │
└──────────────────┬─────────────────┘
                   │ HTTPS
                   ▼
┌────────────────────────────────────┐
│ API Backend                         │
│ Go recommended                      │
│                                     │
│ - Authless session ID               │
│ - Queue generation                  │
│ - Event ingestion                   │
│ - Recommendation context            │
└──────────────────┬─────────────────┘
                   │
                   ▼
┌────────────────────────────────────┐
│ Recommendation Service              │
│                                     │
│ - CLAP vector search                │
│ - MFCC/chroma similarity            │
│ - metadata filters                  │
│ - user taste vector                 │
│ - reranking                         │
└──────────────────┬─────────────────┘
                   │
                   ▼
┌────────────────────────────────────┐
│ Music Database                      │
│ PostgreSQL + pgvector               │
│                                     │
│ tracks                              │
│ embeddings                          │
│ audio_features                      │
│ feedback_events                     │
│ user_profiles                       │
└────────────────────────────────────┘
```

## Major Responsibilities

### iOS App

- Render calm, single-screen player UI
- Manage playback with AVPlayer
- Maintain local queue and playback state
- Capture feedback events
- Persist unsent feedback events
- Send prompt/pill context to backend
- Display recommendation explanations

### API Backend

- Generate recommendation queues
- Accept feedback events
- Track anonymous session profile
- Return track metadata and streamable URLs
- Return explanation metadata

### Recommendation Service

- Embed prompt and pill labels
- Search CLAP vector space
- Apply MFCC/chroma similarity
- Apply metadata boosts
- Apply user taste vector
- Penalize skips and recent repeats
- Return reranked track list

### Music Database

- Store track metadata
- Store vectors and audio features
- Store tags and classification labels
- Store feedback events
- Store session taste vectors

## Privacy Model

MVP should use an anonymous local session ID.

No account required.
No email required.
No third-party analytics required.

Future account support can be optional for syncing favorites across devices.

## Core Runtime Flow

```text
App launch
 ↓
Load or create anonymous session ID
 ↓
Load local queue/favorites/events
 ↓
Fetch initial queue if needed
 ↓
Start playback on user action
 ↓
User interacts with prompt/pills/skip/favorite
 ↓
Feedback events are logged locally
 ↓
Queue refreshes continuously
 ↓
Events sync opportunistically
```

## Network Resilience

The app should keep playing existing queued tracks if the network fails.

Minimum behavior:

- if queue fetch fails, show non-blocking error
- keep current/upcoming local queue
- retry event sync later
- do not lose favorites or feedback events

## MVP Deployment Assumption

The iOS app can initially target one backend environment:

```text
https://api.example.com/v1
```

Use environment configuration so staging/prod can be swapped later.

