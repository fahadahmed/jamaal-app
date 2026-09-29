# ADR 0001: Anchor as a third object type

> **Status: accepted for v1, including the positioning decision** (see "Positioning"). Drafted from the reasoning already recorded in `docs/schema/anchor.md`, `docs/schema/habit.md` and CLAUDE.md.

## Context

Jamaal began (in the earlier planning chat) with two primitives, Task and Habit. Salah — five daily prayers — was modelled as five binary habits in a "Salah" group. That fit badly:

- A Habit is **self-paced**: the user decides when and whether to do it, and success is a pattern the user builds (shown as density, not streaks).
- Prayer windows are **externally fixed**: the times come from the sun, and the window closing is a fact of the day, not a choice. The same is true of a school run, bin night or (less rigidly) watering plants on a schedule.
- A shaded-grid of "how much did I do" is the wrong lens for these. Missing Dhuhr is not a gap in a pattern you are building — the window closed on something external, and attendance is the honest measure.

## Decision

Add a third primitive, **Anchor**: something the user's life *moves around*, whose timing and the consequence of a miss are external. Anchors are tracked by **attendance** (`pending` / `attended` / `missed` / `skipped`), not streaks or completion.

| Primitive | Created by | Tracked via | Nature |
| --------- | ---------- | ----------- | ------ |
| Task | User | Completion | Something you *do* |
| Habit | User | Density | Something you *cultivate* |
| Anchor | User — as a recurring rule (instances generated) or a one-off | Attendance | Something your life *moves around* |

Recurring Anchors are generated from a persisted `AnchorRule` (`sourceKey` + `configData`), not computed ad hoc, so user-defined recurring commitments work without code changes.

## Consequences

- Salah leaves the Habit engine; Habits stay simpler (no externally timed windows).
- Three trackers to explain in onboarding and to lay out on Today (Anchors first, sorted by window start).
- A dedicated generation module in the rules engine (module 3) and a rules-management screen in the app.
- Anchors take real time out of the day; they carry an optional `effortMinutes` so the load check can count them as committed time.

## Alternatives considered

*The second alternative below is inferred from the schema docs, not recorded from the original discussion — correct it if it wasn't actually weighed.*

- **Keep salah as a Habit group** (the v2 design): works visually, but attendance semantics are wrong and prayer times have to be hand-entered and re-entered.
- **Model an Anchor as a Task with a fixed time window**: loses attendance semantics and pollutes the completion-based Task list with things that can't be deferred.

## Positioning

Settled in review: **the user creates Anchors in two ways.**

1. **Recurring commitments** — the user creates an `AnchorRule` (prayer times, school run, bin night, plant watering, custom); the app generates the instances. The user never authors a recurring instance by hand.
2. **One-off Anchors** — the user adds a single Anchor directly, with no rule (a dentist appointment, a parents' evening). This uses the schema's existing optional `Anchor.rule`; no new field.

Why: "generated" alone doesn't fit how people actually have fixed-time commitments — they choose them, and many are one-offs. Supporting one-offs is what lets Jamaal replace a calendar app for fixed-time things without adding a fourth primitive, and costs one extra creation path.

Boundary: a one-off Anchor is fixed-time and attendance-tracked; a Task with a due date is flexible and completion-tracked.

**`skipped` status.** An instance that doesn't apply (school holidays, a skipped bin night) gets a "Not today" action that sets `skipped`. It is not a miss, is ignored by wellbeing patterns, and is never regenerated. Otherwise holidays would read as misses, against the app's non-punitive tone.

**Naming.** Users see "Anchors" (not "Fixed times" or "Commitments"); onboarding teaches the three-way frame: things you *do*, *cultivate*, *attend*.

**Rule configuration.** `AnchorRule.configData` has two families — computed (prayer times) and scheduled (school run, bin night, plant watering and custom share one recurrence-plus-slots shape). Shapes and generation rules are in [anchor.md](../../schema/anchor#configdata-shapes) and [rules-engine.md](../rules-engine) (module 3).

## Still open

- Whether a calendar-events reader is ever in scope; if it is, it changes how one-offs relate to it (see [app-flow.md](../../journeys/app-flow), "Gaps found in review").
- Pausing a rule until a date (holidays), Jumu'ah on Fridays, and per-rule reminder lead time — listed in [anchor.md](../../schema/anchor) open questions.
