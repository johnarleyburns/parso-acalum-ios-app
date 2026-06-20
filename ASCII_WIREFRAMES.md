# ASCII Wireframes — Parso Muse

## Main Home Screen

```text
┌────────────────────────────────────┐
│                                    │
│  Parso Muse                   ⚙︎   │
│                                    │
│        ┌──────────────────┐        │
│        │                  │        │
│        │   generative /   │        │
│        │  public-domain   │        │
│        │   cover visual   │        │
│        │                  │        │
│        └──────────────────┘        │
│                                    │
│     Recuerdos de la Alhambra       │
│        Francisco Tárrega           │
│        Performed by Segovia        │
│                                    │
│       ━━━━━━━●━━━━━━━━             │
│        1:42              3:56      │
│                                    │
│      ♡        ⏯        ⏭          │
│                                    │
│  How should the music feel?        │
│                                    │
│  [Guitar] [Calm] [Romantic]        │
│  [Old Europe] [Reading] [+]        │
│                                    │
│  ┌──────────────────────────────┐  │
│  │ rainy spanish guitar at dusk │  │
│  └──────────────────────────────┘  │
│                                    │
│     Reshaping your stream...       │
│                                    │
└────────────────────────────────────┘
```

## Main Screen With Track Info Button

```text
┌────────────────────────────────────┐
│  Parso Muse                   ⚙︎   │
│                                    │
│  ┌──────────────────────────────┐  │
│  │                              │  │
│  │        Ambient Artwork        │  │
│  │     slow gradient / paper     │  │
│  │       / waveform motion       │  │
│  │                              │  │
│  └──────────────────────────────┘  │
│                                    │
│  Track Title                  ⓘ    │
│  Composer · Performer              │
│  Source / Year                     │
│                                    │
│  progress bar                      │
│                                    │
│      dislike   favorite   skip     │
│                                    │
│  Selected mood                     │
│  [Piano] [Melancholy] [Rainy]      │
│                                    │
│  Prompt input                      │
│  "quiet music for late reading"    │
│                                    │
└────────────────────────────────────┘
```

## First Launch Screen

```text
┌────────────────────────────────────┐
│                                    │
│          Welcome to Parso Muse      │
│                                    │
│   Public-domain music, discovered   │
│   by feeling instead of browsing.   │
│                                    │
│   What do you want to hear first?   │
│                                    │
│   [Peaceful Piano]                  │
│   [Spanish Guitar]                  │
│   [Sacred Choir]                    │
│   [Early Jazz]                      │
│                                    │
│   Or describe it:                   │
│   ┌──────────────────────────────┐  │
│   │ music for reading at night   │  │
│   └──────────────────────────────┘  │
│                                    │
└────────────────────────────────────┘
```

## Why This Sheet

```text
┌────────────────────────────────────┐
│ Why this track?                    │
│                                    │
│ Recuerdos de la Alhambra           │
│                                    │
│ Matched because:                   │
│ ✓ Similar to "spanish guitar"      │
│ ✓ Nylon-string guitar profile      │
│ ✓ Calm + romantic mood             │
│ ✓ Close to tracks you favorited    │
│                                    │
│ Source: Internet Archive           │
│ License: Public Domain             │
│                                    │
└────────────────────────────────────┘
```

## Track Detail Sheet

```text
┌────────────────────────────────────┐
│ Track Details                      │
│                                    │
│ Title                              │
│ Recuerdos de la Alhambra           │
│                                    │
│ Composer                           │
│ Francisco Tárrega                  │
│                                    │
│ Performer                          │
│ Andrés Segovia                     │
│                                    │
│ Source                             │
│ Internet Archive                   │
│                                    │
│ License                            │
│ Public Domain                      │
│                                    │
│ [Open Source Page]                 │
│                                    │
└────────────────────────────────────┘
```

## App Navigation

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

