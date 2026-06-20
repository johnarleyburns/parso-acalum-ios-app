# Recommendation Engine Design — Parso Muse

## Available Signals

The system already assumes a growing database of public-domain music with:

- CLAP 512-dimensional vectors
- MFCC vectors
- chroma vectors
- metadata
- tags/classifications
- user feedback events

## Core Ranking Philosophy

Recommendations should blend:

1. semantic match to user prompt/pills
2. acoustic similarity
3. harmonic similarity
4. user taste profile
5. metadata confidence
6. novelty
7. repeat avoidance
8. skip avoidance

## MVP Scoring Formula

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

Weights should be config-driven.

## Query Vector

Build query text from prompt and selected pills.

```text
query_text = prompt + " " + selected_pill_labels
```

Examples:

```text
quiet spanish guitar at dusk guitar calm romantic reading
```

If no prompt exists:

```text
query_text = default_seed + selected_pill_labels
```

## Taste Vector

MVP taste vector:

```text
taste_vector =
  avg(favorited_tracks * 3.0)
+ avg(completed_tracks * 1.5)
- avg(skipped_tracks * 1.5)
```

Normalize after update.

## Skip Interpretation

Skip timing matters.

```text
skip under 20 seconds:
  strong negative signal for style/context

skip after 60 seconds:
  weak negative signal for exact track

skip near end:
  very weak negative signal or no penalty
```

## Favorite Interpretation

Favorite is a strong positive signal.

Effects:

- boost similar CLAP vectors
- boost similar metadata tags
- boost similar composer/instrument if confidence is high
- do not overfit to the exact track

## Queue Generation Pseudocode

```go
func GenerateQueue(req QueueRequest) ([]TrackRecommendation, error) {
    queryText := BuildQueryText(req.Prompt, req.SelectedPills)

    queryVector := EmbedText(queryText)

    tasteVector := LoadTasteVector(req.SessionID)

    candidates := VectorSearch(queryVector, limit=300)

    candidates = ApplyMetadataBoosts(candidates, req.SelectedPills)
    candidates = RemoveRecentlyPlayed(candidates, req.RecentTrackIDs)
    candidates = ApplyTasteBoost(candidates, tasteVector)
    candidates = ApplySkipPenalty(candidates, req.SkipTrackIDs)
    candidates = ApplyNoveltyBoost(candidates)

    ranked := SortByFinalScore(candidates)

    return BuildRecommendations(ranked[:req.Limit]), nil
}
```

## Explanation Generation

Every returned track should include simple reasons.

Example:

```json
{
  "reasons": [
    "Matches guitar",
    "Matches calm mood",
    "Similar to tracks you favorited"
  ],
  "matched_pills": ["Guitar", "Calm"],
  "similarity_score": 0.91,
  "user_taste_score": 0.74
}
```

## Novelty Controls

Avoid:

- same track repeated
- same recording repeated
- same canonical work repeated too often
- same composer over and over unless user strongly requests it

Suggested MVP rules:

```text
- exclude recent 25 tracks
- downrank same composer if last 3 tracks share composer
- downrank same canonical title within recent 50 tracks
- downrank same source item if already heard this session
```

## Cold Start Strategy

Use seed prompts and popular high-confidence tracks.

Initial seeds:

- Spanish Guitar
- Peaceful Piano
- Sacred Choir
- Early Jazz
- Reading Music
- Sleep Music

## Human-Review Confidence

If ingestion classification confidence is available:

- prioritize high-confidence tracks in MVP
- hide low-confidence tracks until reviewed or validated by listening behavior

