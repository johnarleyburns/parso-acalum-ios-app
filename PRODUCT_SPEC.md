# Product Specification — Parso Muse

## Working Name

**Parso Muse**

Working tagline:

> Describe a feeling. Hear forgotten music.

## Product Vision

Build an iOS app for continuous public-domain music discovery.

The user does **not** choose stations, albums, or playlists.

The user shapes a single living stream using:

- instrument pills
- mood pills
- era/context pills
- freeform natural-language prompts
- skip/listen/favorite behavior

The app retrieves tracks by similarity search over:

- CLAP 512-dimensional embeddings
- MFCC vectors
- chroma vectors
- user preference vectors
- metadata filters

The product should feel like:

> A calm, intelligent, public-domain music companion that learns my taste.

## Product Is Not

This app is not:

- an internet radio directory
- a station selector
- a playlist manager
- an album browser
- a Spotify clone
- a podcast app
- a chatbot app

## Core UX Principles

### 1. One Continuous Stream

There is one living queue. The user shapes it continuously.

### 2. Search Without Searching

The user does not browse a large catalog. They describe a feeling or select soft constraints.

### 3. Low Cognitive Load

The main screen should do almost everything. Avoid tab bars, dense menus, and heavy navigation in MVP.

### 4. Taste Evolves Silently

Skips, favorites, full listens, partial listens, and repeated prompt choices improve future recommendations.

### 5. Trust Through Explanation

Every recommendation can be explained through a simple “Why this?” sheet.

## MVP Scope

### MVP Must Include

- Continuous playback queue
- Prompt input
- Pill selection
- Similarity search API integration or mock endpoint
- Skip
- Favorite
- Listen tracking
- Basic taste vector update
- “Why this?” explanation
- Minimal track detail sheet
- Local cache of recent tracks and user actions

### MVP Must Not Include

- Accounts
- Social features
- Manual playlist creation
- Complex browsing
- Offline downloads
- Full ML personalization pipeline
- Monetization
- Apple Music/Spotify integration

## Target User Experience

The app opens directly into music.

The user can immediately:

1. listen
2. skip
3. favorite
4. tap pills like Guitar, Calm, Reading, Romantic
5. type a phrase like “quiet Spanish guitar at dusk”

The current track should not abruptly stop when the user changes the prompt or pills. The upcoming queue should reshape quietly.

## Product Differentiator

The app’s unique asset is semantic discovery over forgotten and public-domain music.

The differentiated experience is:

> A single adaptive stream that responds to mood, language, and taste over time.

