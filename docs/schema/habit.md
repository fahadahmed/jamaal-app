# Habit

> **Status: reconciled with master summary v2, then updated to density-not-streaks, four habit kinds and pauses — draft, needs review.** The v1-resolved window model is kept; v2's counted habits, groups, schedules, reminders and completion history are folded in; streaks are replaced by density. See [ADR 0002](../architecture/decisions/0002-reconcile-master-summary-v2).

Something the user **cultivates**. Created by the user, tracked by **density** (a grid of days shaded by how much was done) — not streaks. Islamic practice habits (Qur'an reading, dhikr) and general habits (exercise, running) are just different presets of this same engine — see CLAUDE.md.

Salah is **not** modeled here — it's an [Anchor](anchor) instead, since prayer timing is externally fixed rather than self-paced. (The v2 design modelled salah as five habits in a "Salah" group; that no longer applies.)

## Fields

| Field            | Type      | Default                | Notes |
| ---------------- | --------- | ---------------------- | ----- |
| `id`             | `UUID`    | `UUID()`               | |
| `title`          | `String`  | `""`                   | |
| `notes`          | `String?` | `nil`                  | |
| `presetKey`      | `String?` | `nil`                  | Built-in preset (e.g. `"quran"`, `"dhikr"`) vs. `nil` for custom. |
| `kind`           | `String`  | `"binary"`             | One of `binary` / `counted` / `timed` / `avoid`. Fixes what `target` and `amount` mean — see [Habit kinds](#habit-kinds). |
| `frequency`      | `String`  | `"daily"`              | One of `daily` / `weekdays` / `custom`. |
| `scheduledDays`  | `String`  | `"1,2,3,4,5,6,7"`      | ISO weekdays (Mon=1 … Sun=7) the habit is due. `weekdays` = `"1,2,3,4,5"`. Used when `targetPerWeek == 0`. |
| `targetPerWeek`  | `Int`     | `0`                    | `0` = fixed days from `scheduledDays`; `1…7` = "N times a week, any days" (custom recurrence's times/week stepper). |
| `pausesData`     | `String`  | `"[]"`                | JSON list of pauses (travel, illness, …) — see [Pauses](#pauses). |
| `isArchived`     | `Bool`    | `false`                | Soft-delete, so history isn't lost. Editing or archiving never deletes history. |
| `createdAt`      | `Date`    | `.now`                 | |

## Relationships

- `windows: [HabitTimeWindow]?` (optional, CloudKit). Every habit has at least one window. Completion history lives on each window's entries, so density is always per-window.
- `group: HabitGroup?` (optional). `nil` = ungrouped.

### `HabitTimeWindow`

A window is one *occurrence slot* in the day that keeps its own completion history. Two ways to get "multiple per day":

- **Distinct slots** — medication morning and evening = two windows, two independent density grids.
- **Counted** — "drink water 8×" = **one** window with `target = 8`; the user increments a stepper and the window is complete when the count reaches the target. (Eight windows for eight glasses would give eight meaningless grids.)

| Field               | Type    | Default  | Notes |
| ------------------- | ------- | -------- | ----- |
| `id`                | `UUID`  | `UUID()` | |
| `label`             | `String`| `""`     | e.g. `"Morning"`; empty for a single-window habit. |
| `startMinute`       | `Int`   | `0`      | Minutes since midnight. See open question. |
| `endMinute`         | `Int`   | `1439`   | `1439` = no real window boundary. |
| `target`       | `Int`   | `1`      | Meaning depends on `Habit.kind`: `binary` = 1; `counted` = N times; `timed` = N **minutes**; `avoid` = the allowance (most slips still fine), `0` = none. |
| `effortMinutes`     | `Int?`  | `nil`    | How long one occurrence takes (e.g. 15 for a Qur'an reading window). Counts as *flexible* time: it reduces the day's total free time but doesn't cut it into blocks (see [rules-engine.md](../architecture/rules-engine), module 7). For a counted window it is the time for the *whole* target, not per increment. Presets ship a sensible default; `nil` = unknown, counts as zero. |
| `reminderMinute`    | `Int?`  | `nil`    | Minutes since midnight; `nil` = no reminder. UI default when the toggle is switched on: 20:00. Reminders were per-habit in v2; per-window here because windows are the unit of completion history and timing. |

Relationship: `entries: [HabitEntry]?` (optional).

### `HabitEntry`

The per-day completion log the earlier draft was missing. Needed for the heatmap, the partial-completion display in Night Planning review ("2/3 water — shown honestly"), fatigue detection and wellbeing patterns.

| Field           | Type      | Default  | Notes |
| --------------- | --------- | -------- | ----- |
| `id`            | `UUID`    | `UUID()` | |
| `date`          | `Date`    | `.now`   | A floating calendar date: the **logical date** of the log (so a late-night log before the user's rollover counts for the day they're still living) — see [The day boundary](../architecture/rules-engine#the-day-boundary). |
| `target`   | `Int`     | `1`      | Snapshot of the window's target that day (so editing the target later doesn't rewrite history). |
| `amount`| `Int`     | `0`      | By kind: binary 0 or 1; counted the count so far (stepper); **timed the minutes so far**; **avoid the slips so far**. |
| `completedAt`   | `Date?`   | `nil`    | When the target was reached. |
| `window`        | `HabitTimeWindow?` | `nil` | Inverse of `entries`. |

Derived, not stored: for binary, counted and timed, `isComplete` (`amount >= target`), `completionRatio`, `isPartial`, `remainingCount`; for `avoid` the day's outcome follows the [avoid rules](#avoid-habits) instead.

### `HabitGroup`

Groups are **purely visual organisers** — no group-level score or history; each habit keeps its own density grid. Example: a "Morning routine" group. (Groups hold Habits only, never Anchors.)

| Field        | Type     | Default  | Notes |
| ------------ | -------- | -------- | ----- |
| `id`         | `UUID`   | `UUID()` | |
| `title`      | `String` | `""`     | |
| `emoji`      | `String` | `""`     | Single emoji. |
| `sortOrder`  | `Int`    | `0`      | |
| `isArchived` | `Bool`   | `false`  | Archiving a group never deletes its habits (`deleteRule: .nullify`). |
| `createdAt`  | `Date`   | `.now`   | |

Relationship: `habits: [Habit]?` (optional).

Collapsed card: completion ring (% complete today), emoji, name, "4/5 today" badge, 14-day aggregate heatmap. Expanded card: habit rows with check button and completion time. Whether a group is expanded is **local UI state** (per device, not synced) and defaults to collapsed. The Today strip shows a group pill with proportional ring and count.

## Habit kinds

Created from a type picker with plain-language descriptions. `Habit.kind` fixes the meaning of `target` and `HabitEntry.amount`:

| Kind | The question | `target` | `amount` | On Today |
| ---- | ------------ | ------------- | ---------------- | -------- |
| `binary` | Did I do it? | 1 | 0 or 1 | tap the check |
| `counted` | Did I do it N times? | N | times so far | stepper |
| `timed` | Did I do it for N minutes? | N minutes | minutes so far | **Begin** (focus chip), or add minutes by hand |
| `avoid` | Did I avoid it? | allowance (0 = none) | slips so far | **Log a slip** |

"Grouped set" from the design stays [`HabitGroup`](#habitgroup) (visual), and "time-windowed" is covered by habit windows and, for things timed by the world, [Anchors](anchor).

### Timed habits

- Reuse the **focus engine** ([task.md](task#focus-sessions-begin--pause--finish)): a `WorkSession` can point at a habit window. **The day's `HabitEntry.amount` is recomputed from that window's sessions** for the day — `round(total seconds ÷ 60)` over all of them, never per session — so nothing drifts and two devices converge by summing rows. **Minutes added by hand are stored as a finished session with `outcome = manual`** (no start or end time of its own), so everything that feeds the entry is a session and can be recomputed at any time. Stopping a session keeps the partial time.
- The day is complete when minutes reach the target; density shows partial shades as it accumulates, exactly like a counted habit. Time beyond the target doesn't over-fill.
- A running habit session shows in the same chip. If another Begin is tapped, the settle sheet offers **Log it** and **Stop for now** (there is no defer or drop for a habit).
- For a timed window, `effortMinutes` defaults to the target minutes, so it counts as flexible time in the day's free-time calculation.

### Avoid habits

> **Proposal — the design has only a title for this (H-06, "inverted logging"), so these semantics need a design pass before they are treated as settled.**

- **Inverted logging.** The default expectation is abstaining; the user logs a **slip** (each tap adds one to `amount`, undoable). Wording stays neutral — no praise, no guilt.
- **A day's outcome is derived when read, not stored as a default success:**
  - `missed` if slips exceed the allowance;
  - `complete` if slips are within the allowance **and the user engaged with the app that day** — any recorded activity: a task completed, a habit or Anchor logged, a focus session, Night Planning closed, or an explicit **Held today** tap;
  - otherwise `empty`. **Silence is never success:** a day when the app was never touched fills no cell.
  - The current day stays unresolved until it ends.
- **No "days since the last slip" counter** — that would be a streak in disguise. The plain-language read speaks in numbers ("3 slips in the last 21 days").
- An avoid habit has a single all-day window; reminders work as for any habit.

## Pauses

`Habit.pausesData` is a JSON list of date ranges when the habit is paused, with a reason: `[{ "from": "2026-10-12", "to": "2026-10-19", "reason": "travel" }]`. `to` may be `null` (open-ended, until the user resumes). `reason` is `travel`, `illness`, `cycle` or `other`, for display only.

- Paused days are **unscheduled**: no cell fills, nothing counts against the habit, they are left out of the density read's denominators, reminders don't fire, and the habit is hidden from Today and from Night Planning's habit list.
- The habit's detail shows "Paused — resumes 19 Oct" and lets the user end or edit the pause.
- Editing or ending a pause affects only the future; past days keep their entries.

## Density, not streaks

Habits are tracked by **density**, not streaks. There is no streak counter, no "best", and nothing that resets or "breaks" — a missed day is one unfilled cell in a grid, not the loss of everything before it. (Decided when reviewing the design project; supersedes the earlier per-window `currentStreak` / `longestStreak` model.)

- **Completion** — completing a window's target on a due day fills that day's cell fully. A **partial** counted day (2 of 3 glasses) is recorded and shown honestly as a partial shade and "2/3" — it is neither a break nor a full completion.
- **The read** — the grid is accompanied by a plain-language sentence generated from the numbers ("Missed 9 of the last 21. Five a week may be more than this season allows — try three?"), phrased in the companion's voice and never as praise or blame.
- **Unscheduled days** neither fill nor count against the habit.
- **History is data, not a score** — everything density and the read need comes from `HabitEntry`, so nothing extra is stored; a streak could still be *derived* from entries later without a schema change, but none is shown.

## Density states

Each due day is one cell in the habit's grid, shaded by how much was done. Binary and avoid habits use `empty`, `missed`, `complete`; counted and timed habits add two partial steps: `partialLow` (1–49%) and `partialHigh` (50–99%). Days the habit isn't scheduled stay `empty` (unfilled), never `missed`. A gradient is only justified for counted and timed habits.

Colours come from the design's density tokens — three fill steps plus a miss colour (`d1`, `d2`, `d3`, `missed`) — which ThreadsKit doesn't have yet; see [threadskit-usage](../design/threadskit-usage). Grid rules from the design: cells never hold a numeral (a label goes beside the grid, not in it), the grid fills from the trailing edge so right-to-left layouts reverse correctly, and cell size is 18 pt with a 3 pt gap and 3 pt radius.

## Presets

`presetKey` identifies a built-in. The catalogue is **bundled app data**, not user data; every preset uses one all-day window, and everything is editable after creation.

| Preset (`presetKey`) | `kind` | `target` | Schedule | `effortMinutes` |
| --- | --- | --- | --- | --- |
| Qur'an reading (`quran`) | `timed` | 15 min | daily | 15 |
| Dhikr (`dhikr`) | `counted` | 33 | daily | — |
| Exercise (`exercise`) | `timed` | 30 min | 3 times a week | 30 |
| Running (`running`) | `timed` | 30 min | 3 times a week | 30 |
| Something else | `binary` | 1 | daily | — |

The Qur'an and dhikr values are starting suggestions for the owner to correct. In onboarding, "Something else" is a binary daily habit with just a title; the other kinds come from the Habits tab.

## CloudKit constraints applied

- All properties have defaults or are optional.
- No unique constraints.
- All relationships are optional.

## Open questions

- **`HabitTimeWindow` time representation**: `startMinute`/`endMinute` is a placeholder — simple and CloudKit-safe, but doesn't handle timezone travel gracefully. Anchor uses concrete `Date`s for its windows; keep the two consistent in the rules-engine implementation.
- **Weekly-target habits** (`targetPerWeek > 0`): the grid still shows individual days, but the plain-language read should speak in weeks ("3 of 3 this week"). Exact wording is a copy/design task for the custom-recurrence and habit-detail screens.
- **Plain-language read**: the engine emits a typed `.densityRead` signal (completed / due over a rolling window, plus a suggestion when the rate is low); the message layer phrases it. Templates and thresholds (e.g. when to suggest a lighter cadence) still need writing.
- **Avoid habits** need a design pass (H-06): the *Held today* affordance, how a slip is logged and undone, what counts as engagement, and the allowance UI.
- **Detected habits** (the design's "second door": after three evenly spaced completions of a matching task title inside 21 days the app offers once to promote it, inheriting those completions as opening density) are **v1.1**. It needs no schema change — a `NudgeLog` kind and backdated `HabitEntry` rows — and in v1 habits are created by declaring them.
- **Timed habits**: how manual minutes are labelled in history (they are `manual` sessions).
- **Derived habit intelligence** (fatigue: >50% missed over 3 weeks; new-habit realism: 4+ new habits in a week) reads `HabitEntry` history at evaluation time; nothing extra is stored here. Whether a fatigue warning was already shown lives in the nudge log (see [rules-engine.md](../architecture/rules-engine)).
