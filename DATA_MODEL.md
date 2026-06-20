# Data Model — Parso Muse

## Backend Tables

### tracks

```sql
CREATE TABLE tracks (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    canonical_title TEXT,
    composer TEXT,
    performer TEXT,
    source_name TEXT NOT NULL,
    source_url TEXT,
    audio_url TEXT NOT NULL,
    duration_seconds DOUBLE PRECISION NOT NULL,
    license TEXT,
    year INT,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

### track_embeddings

```sql
CREATE TABLE track_embeddings (
    track_id TEXT PRIMARY KEY REFERENCES tracks(id),
    clap_vector vector(512),
    mfcc_vector vector,
    chroma_vector vector
);
```

Note: vector dimensions for MFCC and chroma depend on your feature extraction design. Lock these dimensions before production migrations.

### track_tags

```sql
CREATE TABLE track_tags (
    track_id TEXT REFERENCES tracks(id),
    tag_type TEXT NOT NULL,
    tag_value TEXT NOT NULL,
    confidence DOUBLE PRECISION,
    PRIMARY KEY (track_id, tag_type, tag_value)
);
```

Example tags:

```text
tag_type=instrument, tag_value=guitar
 tag_type=mood, tag_value=calm
 tag_type=era, tag_value=romantic
 tag_type=context, tag_value=reading
```

### feedback_events

```sql
CREATE TABLE feedback_events (
    id UUID PRIMARY KEY,
    session_id TEXT NOT NULL,
    track_id TEXT,
    event_type TEXT NOT NULL,
    listen_seconds DOUBLE PRECISION,
    prompt TEXT,
    selected_pills JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

### user_profiles

```sql
CREATE TABLE user_profiles (
    session_id TEXT PRIMARY KEY,
    taste_vector vector(512),
    updated_at TIMESTAMPTZ DEFAULT now()
);
```

### played_tracks

Optional but useful for repeat avoidance.

```sql
CREATE TABLE played_tracks (
    session_id TEXT NOT NULL,
    track_id TEXT NOT NULL REFERENCES tracks(id),
    played_at TIMESTAMPTZ DEFAULT now(),
    listen_seconds DOUBLE PRECISION,
    completed BOOLEAN DEFAULT false,
    skipped BOOLEAN DEFAULT false,
    PRIMARY KEY (session_id, track_id, played_at)
);
```

## Local iOS Persistence

Persist locally:

- session ID
- favorite track IDs
- recently played track IDs
- skipped track IDs
- unsent feedback events
- last selected pills
- last prompt
- cached queue

## Local JSON Prototype Shape

```json
{
  "session_id": "abc123",
  "last_prompt": "quiet spanish guitar at dusk",
  "selected_pills": ["instrument:guitar", "mood:calm"],
  "favorite_track_ids": ["track_1", "track_9"],
  "recent_track_ids": ["track_2", "track_3"],
  "skipped_track_ids": ["track_4"],
  "unsent_events": [],
  "cached_queue": []
}
```

## Event Types

```text
playStarted
playCompleted
skipped
favorited
unfavorited
replayed
promptChanged
pillSelected
pillRemoved
```

## Data Retention Recommendation

MVP:

- Keep all local favorites indefinitely.
- Keep recent tracks locally up to 100.
- Keep skipped tracks locally up to 100.
- Keep unsent events until successfully synced.

Backend:

- Keep feedback events for model improvement.
- Allow future delete/reset taste profile feature.

