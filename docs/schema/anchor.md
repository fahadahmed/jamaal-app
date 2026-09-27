# Anchor

> **Status: draft, needs review.** This is a first-pass proposal based on CLAUDE.md's primitives table and CloudKit constraints — not yet confirmed. See "Open questions" below, especially the Habit/Anchor boundary question carried over from [habit.md](habit).

Something the user's life **moves around**. **Generated** (not user-created directly), tracked via attendance rather than streaks. Timing and the consequence of a miss are external to the user — examples from CLAUDE.md: prayer windows, school runs, bin night, watering plants.

Full rationale for Anchor as a third primitive (vs. folding into Habit) is meant to live in [ADR 0001](../architecture/decisions/0001-anchor-object-type) — that file is currently an empty stub and needs to be filled in; this schema draft is written from the primitives table alone.

## Fields

| Field             | Type       | Default    | Notes                                                                                     |
| ----------------- | ---------- | ---------- | -------------------------------------------------------------------------------------------- |
| `id`              | `UUID`     | `UUID()`   |                                                                                                |
| `title`           | `String`   | `""`       | e.g. "Fajr", "School run — pickup", "Bin night".                                              |
| `sourceKey`       | `String`   | `"custom"` | What generated this instance — e.g. `"prayerWindow"`, `"schoolRun"`, `"binNight"`, `"plantWatering"`, or `"custom"`. |
| `windowStart`     | `Date`     | `.now`     | Start of the external window this instance is anchored to.                                   |
| `windowEnd`       | `Date`     | `.now`     | End of the window; after this, a miss is final for this instance.                            |
| `attendanceStatus`| `String`   | `"pending"`| One of `pending` / `attended` / `missed`. `String` rather than enum, matching the Task category approach — see open question in [task.md](task).|
| `generatedAt`     | `Date`     | `.now`     |                                                                                                |

## Relationships

None drafted yet — see open question on recurrence source below.

## CloudKit constraints applied

- All properties have defaults.
- No unique constraints.
- No relationships yet, so nothing to mark optional here.

## Open questions

- **Habit/Anchor boundary for prayer windows**: prayer windows appear as an example under *both* Habit ("five daily prayers as a preset") and Anchor ("prayer windows") in CLAUDE.md's primitives table. Need to confirm: is the Habit the streak-tracked "did I complete salah today" and the Anchor the individual generated window/reminder that the Habit's completion is attached to? If so, does Anchor need a `sourceHabitID: UUID?` (optional relationship or raw ID) back to the Habit that spawned it?
- **Recurrence source**: what actually generates an Anchor instance — a rule evaluated by the rules engine (module 3: "Anchor generation") with no persisted "recurrence rule" model, or a stored `AnchorRule`/schedule that the engine reads? This determines whether there's a second model here.
- **Missed-anchor consequences**: CLAUDE.md says "the consequence of a miss are external to the user" — does the app need to *record* anything about the consequence, or is `attendanceStatus: "missed"` sufficient and everything else is just UI framing?
- **Sharing/referral**: same note as Task/Habit — deliberately left out of this draft, pending [issue #8](https://github.com/fahadahmed/jamaal-app/issues/8).
