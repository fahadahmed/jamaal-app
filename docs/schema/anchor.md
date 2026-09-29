# Anchor

> **Status: reviewed, resolved for v1.** Positioning settled: users create Anchors as recurring rules (instances generated) or as one-offs. Anchor postdates the earlier planning chat (master summary v2 has no Anchor); it is kept as-is — see [ADR 0002](../architecture/decisions/0002-reconcile-master-summary-v2). Fields below reflect decisions made in review. See "Open questions" for what's still unsettled (mainly `AnchorRule`'s schedule representation). Rationale lives in [ADR 0001](../architecture/decisions/0001-anchor-object-type).

Something the user's life **moves around**. Created by the user in one of two ways: a **recurring commitment** (an `AnchorRule`, from which the app **generates** the instances) or a **one-off** Anchor added directly with no rule (a dentist appointment, a parents' evening). Tracked via attendance rather than streaks. Timing and the consequence of a miss are external to the user. Examples: prayer windows (including salah — see [habit.md](habit) for why salah lives here and not as a Habit), school runs, bin night, watering plants, and one-off fixed-time events.

Users see these as **"Anchors"** — the name is the same in the UI and the code.

**Anchor vs. Task**: an Anchor has a fixed time the user can't move and is tracked by attendance; a Task with a due date is flexible and tracked by completion. A dentist appointment is an Anchor; "book a dentist appointment" is a Task.

Full rationale for Anchor as a third primitive (vs. folding into Habit) is meant to live in [ADR 0001](../architecture/decisions/0001-anchor-object-type) — that file is currently an empty stub and needs to be filled in.

## Fields

| Field             | Type       | Default    | Notes                                                                                     |
| ----------------- | ---------- | ---------- | -------------------------------------------------------------------------------------------- |
| `id`              | `UUID`     | `UUID()`   |                                                                                                |
| `title`           | `String`   | `""`       | e.g. "Fajr", "School run — pickup", "Bin night".                                              |
| `windowStart`     | `Date`     | `.now`     | Start of the external window this instance is anchored to.                                   |
| `windowEnd`       | `Date`     | `.now`     | End of the window; after this, a miss is final for this instance.                            |
| `effortMinutes`   | `Int?`     | `nil`      | How long attending takes. Copied from `AnchorRule.effortMinutes` when an instance is generated; set directly on one-offs. Counts toward committed time in the load check. `nil` = unknown, counts as zero. |
| `attendanceStatus`| `String`   | `"pending"`| One of `pending` / `attended` / `missed` / `skipped`. `skipped` ("Not today" — school holidays, a bin night that isn't happening) is **not a miss**: it is excluded from wellbeing patterns and shown neutrally. Sufficient on its own for v1 — no separate "consequence" field; any messaging about what a miss means is UI/copy, not data (confirmed in review). |
| `generatedAt`     | `Date`     | `.now`     |                                                                                                |

## Relationships

- `rule: AnchorRule?` (optional, per CloudKit relationship constraint) — the rule that generated this instance. **`nil` means a one-off Anchor** created directly by the user (derived, not a separate flag).

### `AnchorRule`

Anchor instances are generated from a persisted `AnchorRule` (confirmed in review — not computed purely on the fly by the rules engine, so custom user-defined anchors like plant watering are possible without code changes).

| Field         | Type      | Default    | Notes                                                                                          |
| ------------- | --------- | ---------- | -------------------------------------------------------------------------------------------------- |
| `id`          | `UUID`    | `UUID()`   |                                                                                                      |
| `title`       | `String`  | `""`       |                                                                                                      |
| `sourceKey`   | `String`  | `"custom"` | One of `prayerWindow` / `schoolRun` / `binNight` / `plantWatering` / `custom`.                       |
| `configData`  | `String`  | `"{}"`     | JSON-encoded, shape depends on `sourceKey` (e.g. prayer calculation method + location for `prayerWindow`; weekday + time for `schoolRun`; interval in days for `plantWatering`). Placeholder pending the rules-engine design pass ([issue #7](https://github.com/fahadahmed/jamaal-app/issues/7)). |
| `effortMinutes` | `Int?`  | `nil`      | How long attending takes (Fajr ≈ 10, school run ≈ 30) — **not** the window length (Fajr's window may be 90 minutes). Applies to every instance the rule generates and counts toward the day's committed time in the load check. `nil` = unknown, counts as zero. |
| `isEnabled`   | `Bool`    | `true`     |                                                                                                      |
| `createdAt`   | `Date`    | `.now`     |                                                                                                      |

## CloudKit constraints applied

- All properties have defaults.
- No unique constraints.
- The `rule` relationship is optional.

## Open questions

- **Editing behaviour** (proposal): editing or disabling an `AnchorRule` affects only *future* instances; past instances and their attendance are never rewritten. A `skipped` instance is never regenerated (generation is keyed by rule + window start; see [rules-engine.md](../architecture/rules-engine)). Editing a one-off changes just that Anchor; deleting one removes it (a one-off has no history worth keeping until attended or missed).
- **Deleting a rule**: does it delete its future pending instances only (proposed), and keep attended/missed history?
- **One-off boundary**: should one-offs support notes, or a location? Not modelled; likely not needed for v1.
- **`AnchorRule.configData` shape**: a JSON blob is a pragmatic placeholder, not a final design — each `sourceKey` needs its own decoded shape, to be defined alongside the rules-engine module boundaries ([issue #7](https://github.com/fahadahmed/jamaal-app/issues/7)).
- **ADR 0001 is still empty**: this doc references it for "why Anchor is a third primitive" but there's no content there yet to point to — worth filling in now that the Habit/Anchor boundary is actually resolved.
- **Per-instance duration**: `effortMinutes` is one value per rule, so every prayer from a `prayerWindow` rule gets the same duration. Fine for v1; per-`sourceKey` shapes (e.g. different lengths per prayer) can go in `configData` later.
- **Where users manage `AnchorRule`s in the app** (Habits tab section vs. Settings) is undecided — see [app-flow.md](../journeys/app-flow).
- **Sharing/referral**: deferred to v1.1 (see CLAUDE.md), no schema impact for now.
