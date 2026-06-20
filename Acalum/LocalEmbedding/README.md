# LocalEmbedding — Acalum

## Overview

Acalum uses local prompt-to-vector embedding to search a catalog of public-domain
music tracks. The embedding model is **laion/clap-htsat-fused** — the same model
used by the Internet Archive music indexer (`johnarleyburns/parso-ia-music-indexer`).

## Architecture

```
User prompt + pills
       │
       ▼
QueryTextBuilder
       │ natural language query string
       ▼
TextEmbeddingService
       │ 512-dim L2-normalized Embedding512
       ▼
LocalVectorSearchService
       │ cosine similarity against catalog CLAP vectors
       ▼
SearchReranker
       │ final scored + explained results
       ▼
PlaybackQueue
```

## CLAP model

| Field             | Value                                              |
|-------------------|----------------------------------------------------|
| Model             | `laion/clap-htsat-fused`                           |
| Source             | Hugging Face Transformers                          |
| Embedding dim     | 512                                                |
| Normalization     | L2                                                 |
| Audio dtype       | float16 blobs in SQLite                            |
| Text dtype        | float32 on-device, compared via cosine / dot       |

## Existing catalog vectors

The indexer produces **audio** CLAP vectors:

```
Internet Archive MP3
  → stream first ~1.6 MB
  → decode to PCM float32
  → resample to 48 kHz
  → AutoProcessor → input_features
  → ClapModel.audio_model(...)
  → audio_projection(pooler_output)
  → L2 normalize
  → 512-dim float16 blob
```

These are stored in `track_embeddings.clap` in `parso_indexer.db`.

## Local text embedding (this module)

The iOS app must reproduce the indexer's **text** embedding path:

```
User query string
  → CLAPTokenizer.encode(text)
  → input_ids + attention_mask
  → Core ML model (text_model + text_projection)
  → 512-dim vector
  → L2 normalize
```

## Future Core ML model

The model should be exported as:

```
AcalumCLAPTextEncoder.mlpackage
```

It must wrap:

- `ClapModel.text_model` (RoBERTa-based encoder)
- `ClapModel.text_projection` (linear projection to shared 512-dim space)

The tokenizer must match `AutoProcessor.from_pretrained("laion/clap-htsat-fused")`.

## Validation

For each test prompt, compare the iOS-produced vector to the Python sidecar vector:

- **Target**: `cosine_similarity(iOS, Python) >= 0.995` (FP32)
- **Acceptable**: `>= 0.98` after aggressive quantization

Test prompts:

1. "quiet Spanish guitar at dusk"
2. "melancholy piano for reading"
3. "Gregorian chant in an old cathedral"
4. "early jazz from the 1920s"
5. "romantic classical guitar"
6. "soft public domain music for sleep"
7. "baroque strings and harpsichord"
8. "nostalgic old recordings"
9. "peaceful violin music"
10. "dramatic organ music"

## What is NOT needed for MVP

- Full local audio encoding (catalog already has precomputed audio vectors)
- ONNX Runtime
- Server-side embedding fallback
- Real-time audio feature extraction
