# Acalum — Next Implementation Plan

Written: 2026-06-19
Last commit: ce9c3cd (main)
Tests: 46/46 passing, 0 failures

## Current State

### What exists and works

The app launches into a single-screen player (PlayerHomeView) with:

- AVPlayer playback (play/pause/skip through 5 mock tracks)
- Favorite toggle (persisted via UserDefaults)
- 22 pills with semantic phrases (instrument/mood/context/era)
- Freeform prompt input
- Feedback event logging (playStarted, skipped, favorited, promptChanged, pillSelected, etc.)
- FeedbackEventStore persists unsent events locally

### What's built but not yet wired to the playback UI

LocalEmbedding module:
- Embedding512 type (512-dim vector with Accelerate-based L2 norm, dot, cosine similarity)
- TextEmbeddingService protocol
- MockTextEmbeddingService (deterministic FNV-1a hash → normalized vector)
- CLAPTextEmbeddingService stub (throws modelNotBundled; ready for AcalumCLAPTextEncoder.mlpackage)
- CLAPTokenizer protocol/stub (ready for RoBERTa tokenizer from laion/clap-htsat-fused)
- QueryTextBuilder (prompt + pill semanticPhrases → CLAP query string)

LocalSearch module:
- LocalVectorSearchService protocol
- ExactCosineVectorSearchService (in-memory exact cosine search over TrackVectorRecord array)
- SearchReranker (0.80 CLAP + 0.10 metadata + 0.05 novelty + 0.05 taste)
- TrackVectorRecord and SearchResult types

Database:
- parso_indexer.db (53 MB) copied to Acalum/Resources/ (gitignored)
- Contains 7,900 tracks with CLAP/MFCC/chroma embeddings from parso-ia-music-indexer
- Schema: tracks, albums, track_embeddings, collections, collection_albums
- Embeddings: CLAP 512-dim float16 BLOBs (1024 bytes each), L2 normalized
- Audio URLs: full Internet Archive download URLs
- Art URLs: Internet Archive image service URLs
- No Swift code reads it yet

### Commit history

```
ce9c3cd fix: add app icon, iPad orientations, CFBundleIconName
49d04e7 feat: add LocalEmbedding and LocalSearch modules
7bd0912 fix: enable automatic code signing
2e66d92 feat: implement Phase 0 and Phase 1
```

## Shortest Path to Real Music: Phase 2b

### Goal

Replace the 5 hardcoded mock tracks with real music from the 7,900-track Internet Archive catalog. User launches app → hears real public-domain music → pills and taste shape what plays next.

### Architecture overview

```
parso_indexer.db (bundled, read-only)
       │
       ▼
LocalDatabase.swift (SQLite3 C API, read-only)
       │ loads tracks + f16 CLAP blobs
       ▼
[TrackVectorRecord] (7,900 records, ~15 MB in memory)
       │
       ▼
ExactCosineVectorSearchService (already built)
       │ cosine search against query vector
       ▼
SearchReranker (already built)
       │ final scored results
       ▼
PlayerViewModel → PlaybackQueue → AVPlayer
       │ streams audio from archive.org URLs
       ▼
AmbientArtworkView → AsyncImage from archive.org art URLs
```

### Implementation steps

#### Step 1: VectorMath.swift

Location: Acalum/Database/VectorMath.swift

Purpose: Decode float16 BLOBs from SQLite into [Float] arrays.

```swift
import Accelerate

enum VectorMath {
    static func decodeFloat16Blob(_ data: Data) -> [Float]
    // Read UInt16 pairs, convert via Float16(bitPattern:), widen to Float
    // Use vImageConvert_Planar16FtoPlanarF for speed if needed
}
```

The database stores CLAP as 1024-byte BLOBs (512 × Float16).
MFCC as 80-byte BLOBs (40 × Float16).
Chroma as 24-byte BLOBs (12 × Float16).

#### Step 2: LocalDatabase.swift

Location: Acalum/Database/LocalDatabase.swift

Purpose: Read-only SQLite wrapper using the sqlite3 C API (no external deps).

Key queries:
```sql
-- Load all tracks with album metadata and embeddings
SELECT t.id, t.title, t.duration, t.download_url,
       a.title AS album_title, a.creator, a.art_url,
       te.clap
FROM tracks t
JOIN albums a ON t.album_id = a.ia_identifier
JOIN track_embeddings te ON t.id = te.track_id
WHERE t.status = 'completed'
```

This returns 7,900 rows. Load all into memory as [TrackVectorRecord].

The database path comes from Bundle.main.path(forResource: "parso_indexer", ofType: "db").

#### Step 3: Update Track model

Add artworkURL: URL? to Track struct. Update MockData tracks. Update TrackDTO.

This lets AmbientArtworkView show real Internet Archive album art.

#### Step 4: Update AmbientArtworkView

Use AsyncImage to load artwork from the IA art_url when available.
Fall back to the existing generative gradient for tracks without art.

#### Step 5: Create LocalRecommendationEngine

Location: Acalum/Recommendation/LocalRecommendationEngine.swift

Implements QueueServiceProtocol. On generateQueue(context:):

1. Build query vector:
   - If favorites exist: compute taste vector = average of favorited track CLAP vectors (from TasteVectorBuilder)
   - If no favorites but pills selected: find tracks whose titles match pill labels, use average of their CLAP vectors as seed
   - Cold start: pick a random diverse seed from the catalog

2. Search: call ExactCosineVectorSearchService.search(query:limit:excluding:)

3. Rerank: call SearchReranker.rerank(results:selectedPills:recentTrackIDs:favoriteTrackIDs:)

4. Map SearchResult → Track and return

#### Step 6: Create TasteVectorBuilder

Location: Acalum/Recommendation/TasteVectorBuilder.swift

Implements the spec formula:
```
taste_vector =
  avg(favorited_tracks * 3.0)
+ avg(completed_tracks * 1.5)
- avg(skipped_tracks * 1.5)
```

Reads CLAP vectors for favorited/completed/skipped track IDs from the loaded catalog.
Normalizes the result to unit length.
Returns Embedding512.

#### Step 7: Wire into PlayerViewModel

Replace MockQueueService with LocalRecommendationEngine.
On app launch:
1. LocalDatabase loads catalog from bundled parso_indexer.db
2. ExactCosineVectorSearchService is initialized with catalog
3. LocalRecommendationEngine is created with search service + taste builder
4. PlayerViewModel uses LocalRecommendationEngine as its QueueServiceProtocol

#### Step 8: Map TrackVectorRecord → Track

Create a conversion from TrackVectorRecord to the existing Track model:
- id: String(dbTrackID)
- title: from DB
- composer: from albums.creator
- performer: nil (not separately stored)
- sourceName: "Internet Archive"
- sourceURL: derived from album IA identifier
- audioURL: from tracks.download_url
- durationSeconds: from tracks.duration
- license: "Public Domain"
- year: nil (not stored in current DB)
- artworkURL: from albums.art_url
- explanation: from SearchResult.explanation

### Testing Phase 2b

- Unit test: VectorMath.decodeFloat16Blob with known bytes
- Unit test: LocalDatabase loads records (may need a small test DB fixture)
- Unit test: TasteVectorBuilder produces normalized vector
- Unit test: LocalRecommendationEngine returns tracks from catalog
- Integration: app launches, plays real IA audio, shows real art

## Phase 3b: Offline Feedback + Taste

### Goal

Build taste vectors locally from all feedback events. Structure data for later sync.

### Steps

1. NetworkMonitor.swift — NWPathMonitor wrapper, publishes isConnected
2. Enhanced FeedbackEventStore — richer persistence, sync-ready format
3. SyncManager.swift — queues events for batch upload when online
4. TasteVectorBuilder integration — rebuild taste vector on every feedback event
5. Persist taste vector locally for fast cold start

## Phase 3c: Offline Favorites

### Goal

Download favorite tracks for offline playback. Generate queue from downloaded-only tracks when offline.

### Steps

1. DownloadManager.swift — URLSession background downloads of MP3s + art
2. OfflineLibrary.swift — tracks which files are downloaded, provides local file URLs
3. Offline queue generation — ExactCosineVectorSearchService scoped to downloaded tracks only
4. PlayerViewModel checks NetworkMonitor: if offline and no downloaded tracks, show message
5. Art cache — downloaded art served from local files

## Phase 2c: Local CLAP Text Encoder (deferred)

### Goal

Run CLAP text embedding on-device so prompts like "quiet Spanish guitar at dusk" produce real 512-dim vectors.

### Prerequisites (from user)

- User will provide details on how to export AcalumCLAPTextEncoder.mlpackage
- Must match laion/clap-htsat-fused exactly
- Must use same tokenizer as parso-ia-music-indexer Python sidecar

### Steps (when details arrive)

1. Export Core ML model from laion/clap-htsat-fused (text_model + text_projection)
2. Export tokenizer vocabulary from same checkpoint
3. Implement CLAPTokenizer.encode() — RoBERTa tokenization
4. Implement CLAPTextEmbeddingService.embed() — tokenize → Core ML → L2 normalize
5. Validate: cosine_similarity(iOS, Python) >= 0.995 for 10 test prompts
6. Replace MockTextEmbeddingService with CLAPTextEmbeddingService in production

## Phases 4-5 (later)

Phase 4: Explanation UI
- Flesh out WhyThisSheet with real recommendation reasons
- TrackInfoSheet with source/license/year
- Link to Internet Archive source page

Phase 5: Polish
- Haptics on favorite/skip/pill toggle
- Lock-screen now-playing metadata (MPNowPlayingInfoCenter)
- Accessibility labels and Dynamic Type
- Error/loading states with spec copy
- Audio interruption handling

## Key File Paths

```
Acalum/
  App/AcalumApp.swift
  Models/Track.swift, Pill.swift, DiscoveryContext.swift, FeedbackEvent.swift, PlaybackState.swift
  Features/
    Player/PlayerHomeView.swift, PlayerViewModel.swift, PlaybackControlsView.swift,
           NowPlayingCardView.swift, AmbientArtworkView.swift
    Discovery/PillSelectorView.swift, PromptBarView.swift
    TrackInfo/WhyThisSheet.swift, TrackInfoSheet.swift
    Settings/SettingsSheet.swift
  Audio/AudioPlayerService.swift, PlaybackQueue.swift
  LocalEmbedding/
    Embedding512.swift, TextEmbeddingService.swift, CLAPTextEmbeddingService.swift,
    MockTextEmbeddingService.swift, QueryTextBuilder.swift, CLAPTokenizer.swift, README.md
  LocalSearch/
    LocalVectorSearchService.swift, ExactCosineVectorSearchService.swift,
    TrackVectorRecord.swift, SearchResult.swift, SearchReranker.swift
  Database/ (empty, ready for LocalDatabase.swift and VectorMath.swift)
  Networking/APIClient.swift, DTOs.swift
  Persistence/LocalStore.swift, FeedbackEventStore.swift, SessionStore.swift
  Recommendation/FeedbackTracker.swift
  Mocks/MockData.swift, MockQueueService.swift
  DesignSystem/Typography.swift, Spacing.swift
  Resources/Assets.xcassets/, parso_indexer.db (gitignored)
AcalumTests/ (9 test files, 46 tests)
project.yml
```

## Database Reference

Source: /Users/arley/github/parso-ia-music-indexer/data/parso_indexer.db
Copy to: Acalum/Resources/parso_indexer.db (gitignored, 53 MB)

Schema:
- tracks (id INTEGER PK, album_id, filename, title, duration REAL, download_url, status)
- albums (ia_identifier TEXT PK, title, creator, art_url, track_count, downloads)
- track_embeddings (track_id INTEGER PK, clap BLOB 1024 bytes, mfcc BLOB 80 bytes, chroma BLOB 24 bytes, dim=512, dtype=f16)
- 7,900 completed tracks with embeddings

## How to Build and Test

```bash
# Copy database (not in git)
cp ../parso-ia-music-indexer/data/parso_indexer.db Acalum/Resources/

# Generate project
xcodegen generate

# Build
xcodebuild build -project Acalum.xcodeproj -scheme Acalum -destination 'generic/platform=iOS Simulator' -quiet

# Test
xcodebuild test -project Acalum.xcodeproj -scheme Acalum -destination 'platform=iOS Simulator,id=14922B94-6522-49EB-B135-A9CFEDD2932E'
```

## Resume Instructions

To continue where this left off:

1. Read this file (NEXT_PLAN.md)
2. Read Acalum/LocalEmbedding/README.md for CLAP model details
3. Start with Phase 2b Step 1 (VectorMath.swift)
4. Work through Steps 1-8 sequentially
5. Build and test after each step
6. The goal is: app launches → real music plays from Internet Archive
