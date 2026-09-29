## Positioning

Settled in review: **the user creates Anchors in two ways.**

1. **Recurring commitments** — the user creates an `AnchorRule` (prayer times, school run, bin night, plant watering, custom); the app generates the instances. The user never authors a recurring instance by hand.
2. **One-off Anchors** — the user adds a single Anchor directly, with no rule (a dentist appointment, a parents' evening). This uses the schema's existing optional `Anchor.rule`; no new field.

Why: "generated" alone doesn't fit how people actually have fixed-time commitments — they choose them, and many are one-offs. Supporting one-offs is what lets Jamaal replace a calendar app for fixed-time things without adding a fourth primitive, and costs one extra creation path.

Boundary: a one-off Anchor is fixed-time and attendance-tracked; a Task with a due date is flexible and completion-tracked.

**`skipped` status.** An instance that doesn't apply (school holidays, a skipped bin night) gets a "Not today" action that sets `skipped`. It is not a miss, is ignored by wellbeing patterns, and is never regenerated. Otherwise holidays would read as misses, against the app's non-punitive tone.

**Naming.** Users see "Anchors" (not "Fixed times" or "Commitments"); onboarding teaches the three-way frame: things you *do*, *cultivate*, *attend*.

## Still open

- `AnchorRule.configData` shapes (see [rules-engine.md](../rules-engine)).
- Whether a calendar-events reader is ever in scope; if it is, it changes how one-offs relate to it (see [app-flow.md](../../journeys/app-flow), "Gaps found in review").
