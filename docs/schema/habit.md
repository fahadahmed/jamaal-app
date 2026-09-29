# Habit

> **Status: reconciled with master summary v2 — draft, needs review.** The v1-resolved window/streak model is kept; v2's counted habits, groups, schedules, reminders and completion history are folded in. See [ADR 0002](../architecture/decisions/0002-reconcile-master-summary-v2).

Something the user **cultivates**. Created by the user, tracked via streaks. Islamic practice habits (Qur'an reading, dhikr) and general habits (exercise, running) are just different presets of this same engine — see CLAUDE.md.

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
| `isArchived`     | `Bool`    | `false`                | Soft-delete, so streak history isn't lost. |
| `createdAt`      | `Date`    | `.now`                 | |

## Relationships

- `windows: [HabitTimeWindow]?` (optional, CloudKit). Every habit has at least one window. Streaks live on the window, not on Habit, so streak granularity is always per-window.
- `group: HabitGroup?` (optional). `nil` = ungrouped.

### `HabitTimeWindow`

A window is one *occurrence slot* in the day that keeps its own streak. Two ways to get "multiple per day":

- **Distinct slots** — medication morning and evening = two windows, two independent streaks.
- **Counted** — "drink water 8×" = **one** window with `targetCount = 8`; the user increments a stepper and the window is complete when the count reaches the target. (Eight windows for eight glasses would give eight meaningless streaks.)

| Field               | Type    | Default  | Notes |
| ------------------- | ------- | -------- | ----- |
| `id`                | `UUID`  | `UUID()` | |
| `label`             | `String`| `""`     | e.g. `"Morning"`; empty for a single-window habit. |
| `startMinute`       | `Int`   | `0`      | Minutes since midnight. See open question. |
| `endMinute`         | `Int`   | `1439`   | `1439` = no real window boundary. |
| `targetCount`       | `Int`   | `1`      | `1` = binary; `2+` = counted. |
| `reminderMinute`    | `Int?`  | `nil`    | Minutes since midnight; `nil` = no reminder. UI default when the toggle is switched on: 20:00. Reminders were per-habit in v2; per-window here because windows are the unit of streak and timing. |
| `currentStreak`     | `Int`   | `0`      | |
| `longestStreak`     | `Int`   | `0`      | |
| `lastCompletedDate` | `Date?` | `nil`    | Used by the rules engine to detect a broken streak. |

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

Groups are **purely visual organisers** — no group-level streak logic, each habit streaks independently. Example: a "Morning routine" group. (Groups hold Habits only, never Anchors.)

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

Collapsed card: completion ring (% complete today), emoji, name, "4/5 today" badge, 14-day aggregate heatmap. Expanded card: habit rows with check button, streak badge, completion time. The Today strip shows a group pill with proportional ring and count.

## Streak rules

- Completing a window's target on a due day advances that window's `currentStreak`. A **partial** counted day does *not* advance the streak, but is recorded and shown honestly (partial heatmap shade, "2/3").
- A due day that passes with the target unmet resets `currentStreak` to 0.
- Days a habit isn't scheduled neither advance nor break the streak.

## Heatmap states

Binary habits: `empty`, `missed`, `complete`. Counted habits: `empty`, `missed`, `partialLow` (1–49%), `partialHigh` (50–99%), `complete`. A gradient is only justified for counted habits.

v2 assigned sage greens and a soft terracotta to these states. ThreadsKit has no sage, so the colour mapping is an open design decision — see [threadskit-usage](../design/threadskit-usage).

## Presets

`presetKey` identifies a built-in (Qur'an reading, dhikr, exercise, running). Whether presets need bundled config (default windows, target counts, labels) that ships with the app rather than as user data is still open.

## CloudKit constraints applied

- All properties have defaults or are optional.
- No unique constraints.
- All relationships are optional.

## Open questions

- **`HabitTimeWindow` time representation**: `startMinute`/`endMinute` is a placeholder — simple and CloudKit-safe, but doesn't handle timezone travel gracefully. Anchor uses concrete `Date`s for its windows; keep the two consistent in the rules-engine implementation.
- **Streaks for "N times a week" habits** (`targetPerWeek > 0`): a daily-streak definition doesn't fit. Options: count consecutive *weeks* that hit the target, or show weekly progress only. Decide before the custom-recurrence screen is designed.
- **Presets**: is `presetKey` enough, or do presets need bundled config?
- **Derived habit intelligence** (fatigue: >50% missed over 3 weeks; new-habit realism: 4+ new habits in a week; streak protection) reads `HabitEntry` history at evaluation time; nothing extra is stored here. Whether a fatigue warning was already shown lives in the nudge log (see [rules-engine.md](../architecture/rules-engine)).
