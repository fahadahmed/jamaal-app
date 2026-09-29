# ADR 0001: Anchor as a third object type

> **Status: accepted for v1; the generated-vs-user-created positioning is still parked** (see "Open question"). Drafted from the reasoning already recorded in `docs/schema/anchor.md`, `docs/schema/habit.md` and CLAUDE.md.

## Context

Jamaal began (in the earlier planning chat) with two primitives, Task and Habit. Salah — five daily prayers — was modelled as five binary habits in a "Salah" group. That fit badly:

- A Habit is **self-paced**: the user decides when and whether to do it, and success is a streak the user builds.
- Prayer windows are **externally fixed**: the times come from the sun, and the window closing is a fact of the day, not a choice. The same is true of a school run, bin night or (less rigidly) watering plants on a schedule.
- Streak framing is wrong for these. Missing Dhuhr should not read as "streak broken, start again" — attendance is the honest measure.

## Decision

Add a third primitive, **Anchor**: something the user's life *moves around*, whose timing and the consequence of a miss are external. Anchors are tracked by **attendance** (`pending` / `attended` / `missed`), not streaks or completion.

| Primitive | Created by | Tracked via | Nature |
| --------- | ---------- | ----------- | ------ |
| Task | User | Completion | Something you *do* |
| Habit | User | Streaks | Something you *cultivate* |
| Anchor | Generated from a rule | Attendance | Something your life *moves around* |

Anchors are generated from a persisted `AnchorRule` (`sourceKey` + `configData`), not computed ad hoc, so user-defined recurring commitments work without code changes.

## Consequences

- Salah leaves the Habit engine; Habits stay simpler (no externally timed windows).
- Three trackers to explain in onboarding and to lay out on Today (Anchors first, sorted by window start).
- A dedicated generation module in the rules engine (module 3) and a rules-management screen in the app.
- Anchors take real time out of the day but carry no effort estimate — how they interact with load is open.

## Alternatives considered

*The second alternative below is inferred from the schema docs, not recorded from the original discussion — correct it if it wasn't actually weighed.*

- **Keep salah as a Habit group** (the v2 design): works visually, but streak semantics are wrong and prayer times have to be hand-entered and re-entered.
- **Model an Anchor as a Task with a fixed time window**: loses attendance semantics and pollutes the completion-based Task list with things that can't be deferred.

## Open question

CLAUDE.md and `anchor.md` flag whether Anchors should be system-generated or user-created as unsettled. Recommended framing, which the onboarding flow already assumes: **the user creates a recurring commitment (an `AnchorRule`); the app generates its instances.** The user never authors a single Anchor instance by hand, but does author rules. This reconciles "generated" with the fact that users clearly choose what their Anchors are. Confirm before the Anchor rule screens are designed.
