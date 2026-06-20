# Parso Muse — Agentic Coding Design Bundle

This bundle contains an implementation-ready design for **Parso Muse**, an iOS app for continuous public-domain music discovery using semantic similarity search over CLAP, MFCC, chroma, metadata, and user feedback.

The product is **not** a radio station app, playlist app, or album browser. It is a single continuous stream shaped by:

- instrument/mood/context/era pills
- freeform natural language prompts
- skips
- favorites
- listening duration
- repeated behavior over time

## Recommended Build Order

1. Static SwiftUI prototype
2. Local mock playback queue
3. AVPlayer audio playback
4. Backend queue-generation API integration
5. Feedback event loop
6. Recommendation explanation UI
7. Polish, accessibility, haptics, lock-screen metadata

## Bundle Contents

| File | Purpose |
|---|---|
| `PRODUCT_SPEC.md` | Product vision, scope, MVP, core principles |
| `UI_UX_SPEC.md` | UI/UX design, screens, interaction model |
| `ASCII_WIREFRAMES.md` | ASCII-art layouts for implementation alignment |
| `HLD.md` | High-level system architecture |
| `LLD_IOS.md` | Low-level iOS architecture, modules, types |
| `API_CONTRACTS.md` | Backend API request/response contracts |
| `DATA_MODEL.md` | Backend and local persistence data models |
| `RECOMMENDATION_ENGINE.md` | Scoring model and feedback loop |
| `PHASED_IMPLEMENTATION_PLAN.md` | MVP and later phases with acceptance criteria |
| `DECISION_POINTS.md` | Product decisions requiring owner input |
| `AGENT_PROMPTS.md` | Prompts/instructions to feed into a coding agent |
| `TEST_ACCEPTANCE_CRITERIA.md` | Functional, UX, accessibility, and regression checks |
| `MASTER_SPEC.md` | Single-file consolidated version of the full design |

## Core Product Sentence

> Describe how you want the music to feel, and Parso Muse continuously finds public-domain music that fits.

