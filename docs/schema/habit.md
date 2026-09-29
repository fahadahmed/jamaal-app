# Habit

> **Status: reconciled with master summary v2, then updated to density-not-streaks — draft, needs review.** The v1-resolved window model is kept; v2's counted habits, groups, schedules, reminders and completion history are folded in; streaks are replaced by density. See [ADR 0002](../architecture/decisions/0002-reconcile-master-summary-v2).

Something the user **cultivates**. Created by the user, tracked by **density** (a grid of days shaded by how much was done) — not streaks. Islamic practice habits (Qur'an reading, dhikr) and general habits (exercise, running) are just different presets of this same engine — see CLAUDE.md.

Salah is **not** modeled here — it's an [Anchor](anchor) instead, since prayer timing is externally fixed rather than self-paced. (The v2 design modelled salah as five habits in a "Salah" group; that no longer applies.)

## Fields

| Field            | Type      | Default                | Notes |
| ---------------- | --------- | ---------------------- | ----- |
| `id`             | `UUID`    | `UUID()`               | |
| `title`          | `String`  | `""`                   | |
| `notes`          | `String?` | `nil`                  | |
| `presetKey`      | `String?` | `nil`                  | Built-in preset (e.g. `"quran"`, `"dhikr"`) vs. `nil` for custom. |
| `frequency`      | `String`  | `"daily"`              | One of `daily` / `weekdays` / `custom`. |
| `scheduledDays`  | `String`  | `"1,2,3,4,5,6,7"`      | ISO weekdays (Mon=1 … Sun=7) the habit is due. `weekdays` = `"1,2,3,4,5"`. Used when `targetPerWeek == 0`. |
| `targetPerWeek`  | `Int`     | `0`                    | `0` = fixed days from `scheduledDays`; `1…7` = "N times a week, any days" (custom recurrence's times/week stepper). |
| `isArchived`     | `Bool`    | `false`                | Soft-delete, so history isn't lost. |
| `createdAt`      | `Date`    | `.now`                 | |

## Relationships

- `windows: [HabitTimeWindow]?` (optional, CloudKit). Every habit has at least one window. Completion history lives on each window's entries, so density is always per-window.
- `group: HabitGroup?` (optional). `nil` = ungrouped.

### `HabitTimeWindow`

A window is one *occurrence slot* in the day that keeps its own completion history. Two ways to get "multiple per day":

- **Distinct slots** — medication morning and evening = two windows, two independent density grids.
- **Counted** — "drink water 8×" = **one** window with `targetCount = 8`; the user increments a stepper and the window is complete when the count reaches the target. (Eight windows for eight glasses would give eight meaningless grids.)

| Field               | Type    | Default  | Notes |
| ------------------- | ------- | -------- | ----- |
| `id`                | `UUID`  | `UUID()` | |
| `label`             | `String`| `""`     | e.g. `"Morning"`; empty for a single-window habit. |
| `startMinute`       | `Int`   | `0`      | Minutes since midnight. See open question. |
| `endMinute`         | `Int`   | `1439`   | `1439` = no real window boundary. |
| `targetCount`       | `Int`   | `1`      | `1` = binary; `2+` = counted. |
| `effortMinutes`     | `Int?`  | `nil`    | How long one occurrence takes (e.g. 15 for a Qur'an reading window). Counts toward the day's committed time in the load check. For a counted window it is the time for the *whole* target, not per increment. Presets ship a sensible default; `nil` = unknown, counts as zero. |
| `reminderMinute`    | `Int?`  | `nil`    | Minutes since midnight; `nil` = no reminder. UI default when the toggle is switched on: 20:00. Reminders were per-habit in v2; per-window here because windows are the unit of completion history and timing. |

Relationship: `entries: [HabitEntry]?` (optional).

### `HabitEntry`

The per-day completion log the earlier draft was missing. Needed for the heatmap, the partial-completion display in Night Planning review ("2/3 water — shown honestly"), fatigue detection and wellbeing patterns.

| Field           | Type      | Default  | Notes |
| --------------- | --------- | -------- | ----- |
| `id`            | `UUID`    | `UUID()` | |
| `date`          | `Date`    | `.now`   | Day granularity. |
| `targetCount`   | `Int`     | `1`      | Snapshot of the window's target that day (so editing the target later doesn't rewrite history). |
| `completedCount`| `Int`     | `0`      | Incremented / decremented by the stepper (binary habits: 0 or 1). |
| `completedAt`   | `Date?`   | `nil`    | When the target was reached. |
| `skippedReason` | `String?` | `nil`    | Optional, user-supplied. |
| `window`        | `HabitTimeWindow?` | `nil` | Inverse of `entries`. |

Derived, not stored: `isComplete` (`completedCount >= targetCount`), `completionRatio`, `isPartial`, `remainingCount`.

### `HabitGroup`

Groups are **purely visual organisers** — no group-level score or history; each habit keeps its own density grid. Example: a "Morning routine" group. (Groups hold Habits only, never Anchors.)

| Field        | Type     | Default  | Notes |
| ------------ | -------- | -------- | ----- |
| `id`         | `UUID`   | `UUID()` | |
| `title`      | `String` | `""`     | |
| `emoji`      | `String` | `""`     | Single emoji. |
| `sortOrder`  | `Int`    | `0`      | |
| `isExpanded` | `Bool`   | `false`  | Default collapsed. |
| `isArchived` | `Bool`   | `false`  | Archiving a group never deletes its habits (`deleteRule: .nullify`). |
| `createdAt`  | `Date`   | `.now`   | |

Relationship: `habits: [Habit]?` (optional).

Collapsed card: completion ring (% complete today), emoji, name, "4/5 today" badge, 14-day aggregate heatmap. Expanded card: habit rows with check button and completion time. The Today strip shows a group pill with proportional ring and count.

## Density, not streaks

Habits are tracked by **density**, not streaks. There is no streak counter, no "best", and nothing that resets or "breaks" — a missed day is one unfilled cell in a grid, not the loss of everything before it. (Decided when reviewing the design project; supersedes the earlier per-window `currentStreak` / `longestStreak` model.)

- **Completion** — completing a window's target on a due day fills that day's cell fully. A **partial** counted day (2 of 3 glasses) is recorded and shown honestly as a partial shade and "2/3" — it is neither a break nor a full completion.
- **The read** — the grid is accompanied by a plain-language sentence generated from the numbers ("Missed 9 of the last 21. Five a week may be more than this season allows — try three?"), phrased in the companion's voice and never as praise or blame.
- **Unscheduled days** neither fill nor count against the habit.
- **History is data, not a score** — everything density and the read need comes from `HabitEntry`, so nothing extra is stored; a streak could still be *derived* from entries later without a schema change, but none is shown.

## Density states

Each due day is one cell in the habit's grid, shaded by how much was done. Binary habits use `empty`, `missed`, `complete`; counted habits add two partial steps: `partialLow` (1–49%) and `partialHigh` (50–99%). Days the habit isn't scheduled stay `empty` (unfilled), never `missed`. A gradient is only justified for counted habits.

Colours come from the design's density tokens — three fill steps plus a miss colour (`d1`, `d2`, `d3`, `missed`) — which ThreadsKit doesn't have yet; see [threadskit-usage](../design/threadskit-usage). Grid rules from the design: cells never hold a numeral (a label goes beside the grid, not in it), the grid fills from the trailing edge so right-to-left layouts reverse correctly, and cell size is 18 pt with a 3 pt gap and 3 pt radius.

## Presets

`presetKey` identifies a built-in (Qur'an reading, dhikr, exercise, running). Whether presets need bundled config (default windows, target counts, labels) that ships with the app rather than as user data is still open.

## CloudKit constraints applied

- All properties have defaults or are optional.
- No unique constraints.
- All relationships are optional.

## Open questions

- **`HabitTimeWindow` time representation**: `startMinute`/`endMinute` is a placeholder — simple and CloudKit-safe, but doesn't handle timezone travel gracefully. Anchor uses concrete `Date`s for its windows; keep the two consistent in the rules-engine implementation.
- **Weekly-target habits** (`targetPerWeek > 0`): the grid still shows individual days, but the plain-language read should speak in weeks ("3 of 3 this week"). Exact wording is a copy/design task for the custom-recurrence and habit-detail screens.
- **Plain-language read**: the engine emits a typed `.densityRead` signal (completed / due over a rolling window, plus a suggestion when the rate is low); the message layer phrases it. Templates and thresholds (e.g. when to suggest a lighter cadence) still need writing.
- **Presets**: is `presetKey` enough, or do presets need bundled config?
- **Derived habit intelligence** (fatigue: >50% missed over 3 weeks; new-habit realism: 4+ new habits in a week) reads `HabitEntry` history at evaluation time; nothing extra is stored here. Whether a fatigue warning was already shown lives in the nudge log (see [rules-engine.md](../architecture/rules-engine)).
