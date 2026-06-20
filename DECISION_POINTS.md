# Product Decision Points — Parso Muse

These decisions require owner input before final production build.

## Decision 1 — App Name

Options:

```text
A. Parso Muse
B. Parso Drift
C. Parso Echoes
D. Parso Public Domain Radio
E. Other
```

Recommendation: **Parso Muse**

Reason: It avoids “radio,” feels calmer and more personal, and aligns with prompt-driven discovery.

## Decision 2 — First Launch Seeds

Pick 4–6:

```text
Spanish Guitar
Peaceful Piano
Sacred Choir
Early Jazz
Baroque Strings
Vintage Blues
Sleep Music
Reading Music
```

Recommendation:

```text
Spanish Guitar
Peaceful Piano
Sacred Choir
Early Jazz
Reading Music
Sleep Music
```

## Decision 3 — Prompt Behavior

When the user changes prompt, should the app:

```text
A. Affect upcoming tracks only
B. Immediately skip to a new recommendation
C. Ask user each time
```

Recommendation: **A. Affect upcoming tracks only**

Reason: It preserves continuous calm listening and avoids jarring transitions.

## Decision 4 — Meaning of Skip

Should skip mean:

```text
A. I dislike this exact track
B. I dislike this style right now
C. Both, depending how fast I skipped
```

Recommendation: **C**

Suggested rule:

```text
skip under 20 seconds = strong style/context penalty
skip after 60 seconds = weak exact-track penalty
skip near end = minimal penalty
```

## Decision 5 — Source and License Visibility

Should source/license be:

```text
A. Always visible
B. In track detail only
C. Hidden unless user asks
```

Recommendation: **B**

Reason: Trust matters, but always-visible license details clutter the calm player UI.

## Decision 6 — Recommendation Architecture

Options:

```text
A. Server-first search, local feedback cache
B. Fully local vector search
C. Hybrid
```

Recommendation MVP: **A**

Future: **C**

Reason: server-first is faster to build while the ingestion pipeline evolves.

## Decision 7 — Artwork Strategy

Options:

```text
A. Generated abstract artwork only
B. Source cover art where available
C. Hybrid generated + public-domain cover art
```

Recommendation MVP: **A**

Future: **C**

Reason: public-domain audio metadata often lacks consistent artwork.

## Decision 8 — Feedback Controls

MVP controls:

```text
A. Favorite + skip only
B. Favorite + dislike + skip
C. Favorite + more-like-this + less-like-this + skip
```

Recommendation MVP: **A**

Reason: fewer controls makes the app feel less like work. Skip timing can infer negative signal.

