# Habit

> **Status: reviewed, resolved for v1.** Fields below reflect decisions made in review. See "Open questions" for what's still unsettled (mainly `HabitTimeWindow`'s exact time representation).

Something the user **cultivates**. Created by the user, tracked via streaks. Islamic practice habits (Qur'an reading, dhikr) and general habits (exercise, running) are just different presets of this same engine — see CLAUDE.md.

Salah is **not** modeled here — it's an [Anchor](anchor) instead, since prayer timing is externally fixed rather than self-paced. See CLAUDE.md's "What Jamaal is" section.

## Fields

| Field           | Type       | Default   | Notes                                                                                   |
| --------------- | ---------- | --------- | ------------------------------------------------------------------------------------------ |
| `id`            | `UUID`     | `UUID()`  |                                                                                              |
| `title`         | `String`   | `""`      |                                                                                              |
| `presetKey`     | `String?`  | `nil`     | Identifies a built-in preset (e.g. `"quran"`, `"dhikr"`) vs. `nil` for a fully custom habit. |
| `isArchived`    | `Bool`     | `false`   | Soft-delete, so streak history isn't lost.                                                  |
| `createdAt`     | `Date`     | `.now`    |                                                                                              |

## Relationships

- `windows: [HabitTimeWindow]?` (optional, per CloudKit relationship constraint). Every habit has at least one window — a simple daily habit has exactly one (effectively "anytime today"); a multi-occurrence habit (e.g. "take medication 3x/day", "drink water 8x/day") has one window per occurrence. Streaks live on the window, not on Habit itself, so the model handles both cases uniformly and streak granularity is always per-window (confirmed in review — a 3x/day habit tracks 3 independent streaks, not one combined daily streak).

### `HabitTimeWindow`

| Field              | Type      | Default  | Notes                                                                 |
| ------------------ | --------- | -------- | ---------------------------------------------------------------------- |
| `id`               | `UUID`    | `UUID()` |                                                                        |
| `label`            | `String`  | `""`     | e.g. `"Morning"`, `"Afternoon"`; empty for a single-window habit.       |
| `startMinute`      | `Int`     | `0`      | Minutes since midnight. See open question on time representation.      |
| `endMinute`        | `Int`     | `1439`   | Minutes since midnight (`1439` = 23:59, i.e. no real window boundary).  |
| `currentStreak`    | `Int`     | `0`      |                                                                        |
| `longestStreak`    | `Int`     | `0`      |                                                                        |
| `lastCompletedDate`| `Date?`   | `nil`    | Used by the rules engine to detect a broken streak.                     |

## CloudKit constraints applied

- All properties have defaults.
- No unique constraints.
- The `windows` relationship is optional.

## Open questions

- **`HabitTimeWindow` time representation**: `startMinute`/`endMinute` (minutes since midnight) is a placeholder — simple and CloudKit-safe, but doesn't handle timezone travel gracefully. Worth confirming against how Anchor represents its windows (`docs/schema/anchor.md` uses `Date` for `windowStart`/`windowEnd`, since those are concrete instants, not daily-recurring times) before implementing.
- **Presets**: is `presetKey` enough, or do presets need their own bundled config (e.g. default window count/labels) that ships with the app rather than being user data?
