# UI/UX Specification — Parso Muse

## Interaction Model

The app has one primary screen: a continuous music player.

The screen contains:

- ambient artwork
- track metadata
- playback progress
- favorite/play-skip controls
- pill selector
- prompt input
- optional “Why this?” sheet
- optional track/source detail sheet

There should be no MVP tab bar.

## Home Screen Layout

The entire MVP can be one screen plus modal sheets.

Top:

- app name
- settings/info button

Middle:

- large generated ambient artwork
- track title
- composer/performer
- source/year/license hint
- progress bar

Bottom:

- favorite/play-skip controls
- selected/available pills
- freeform prompt input
- subtle queue state text

## Visual Style

The app should feel:

- calm
- archival
- intelligent
- native to iOS
- warm
- low-friction

Use:

- large rounded cards
- soft material effects
- restrained typography
- warm neutral backgrounds
- gentle animation
- generous spacing

Avoid:

- neon gradients
- busy station grids
- dark-club music app aesthetic
- social-feed UI
- equalizer gimmicks
- heavy AI branding

## Main Components

### AmbientArtworkView

Purpose: provide visual identity even when public-domain tracks do not have reliable album art.

MVP behavior:

- deterministic generated artwork from track ID
- subtle animated gradient or waveform overlay while playing
- animation pauses when audio pauses
- no remote artwork dependency for MVP

Future behavior:

- optionally use public-domain cover art when available
- optionally generate visual textures from audio features

### PillSelectorView

Pills are soft constraints. They shape recommendations but do not create stations.

Initial categories:

#### Instrument

- Guitar
- Piano
- Violin
- Choir
- Organ
- Orchestra

#### Mood

- Calm
- Melancholy
- Joyful
- Sacred
- Romantic
- Nostalgic

#### Context

- Reading
- Sleep
- Focus
- Rainy Day
- Late Night

#### Era

- Baroque
- Romantic
- Medieval
- Jazz Age
- Early 1900s

Behavior:

- tap toggles pill
- multiple pills may be active
- selected pills are sent with queue-generation requests
- pill changes refresh upcoming queue, not current track

### PromptBarView

Prompt examples:

- “quiet spanish guitar at dusk”
- “melancholy piano for reading”
- “ancient sacred music”
- “warm romantic strings”
- “old jazz but soft”

Behavior:

- user enters text
- submit embeds prompt server-side
- current playback continues
- upcoming queue is refreshed
- prompt can be cleared

### PlaybackControlsView

Primary controls:

- favorite
- play/pause
- skip

Optional secondary control:

- more/info button

Skip behavior:

- immediately advance to next track
- log negative feedback
- penalize exact track and similar tracks depending on skip timing

Favorite behavior:

- persist locally immediately
- log positive feedback
- send feedback event to backend
- boost similar future tracks

### WhyThisSheet

Purpose: build user trust.

Example content:

- Matched because it is similar to “quiet Spanish guitar”
- Nylon-string guitar profile detected
- Calm + romantic mood match
- Similar to tracks you favorited
- Source: Internet Archive
- License: Public Domain

### TrackInfoSheet

Shows:

- title
- composer
- performer
- source
- source link
- year if known
- license
- duration
- recommendation explanation

## First Launch UX

One-screen onboarding only.

Suggested first launch copy:

> Public-domain music, discovered by feeling instead of browsing.

Seed choices:

- Spanish Guitar
- Peaceful Piano
- Sacred Choir
- Early Jazz
- Reading Music
- Sleep Music

No account creation.
No multi-page tutorial.
No permissions prompt until needed.

## Empty / Loading / Error States

### Queue Loading

Text:

> Finding music for your stream…

### Prompt Refreshing

Text:

> Reshaping your stream…

### No Results

Text:

> I could not find a good match. Try a broader feeling, instrument, or mood.

### Network Error

Text:

> You can keep listening to what is already queued. I’ll reconnect when possible.

## Accessibility Requirements

- All controls must have VoiceOver labels.
- Dynamic Type must not break main layout.
- Tap targets should be comfortably sized.
- Color must not be the only indication of selected state.
- Playback controls must be reachable and understandable without artwork.

