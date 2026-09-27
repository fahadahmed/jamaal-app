# Habit

> **Status: draft, needs review.** This is a first-pass proposal based on CLAUDE.md's primitives table and CloudKit constraints — not yet confirmed. See "Open questions" below.

Something the user **cultivates**. Created by the user, tracked via streaks. Supports time-windowed occurrences — e.g. five daily prayers as a single Habit with five windows per day. Islamic practice habits (salah, Qur'an, dhikr) and general habits (exercise, running) are just different presets of this same engine, not separate models — see CLAUDE.md.

## Fields

| Field           | Type       | Default   | Notes                                                                                   |
| --------------- | ---------- | --------- | ------------------------------------------------------------------------------------------ |
| `id`            | `UUID`     | `UUID()`  |                                                                                              |
| `title`         | `String`   | `""`      |                                                                                              |
| `presetKey`     | `String?`  | `nil`     | Identifies a built-in preset (e.g. `"salah"`, `"quran"`, `"dhikr"`) vs. `nil` for a fully custom habit. |
| `occurrencesPerDay` | `Int`  | `1`       | `5` for salah-style habits with multiple daily windows; `1` for a simple daily habit.       |
| `currentStreak` | `Int`      | `0`       | In days, unless occurrence-level streak tracking is needed (see open question).             |
| `longestStreak` | `Int`      | `0`       |                                                                                              |
| `lastCompletedDate` | `Date?` | `nil`    | Used by the rules engine to detect a broken streak.                                          |
| `isArchived`    | `Bool`     | `false`   | Soft-delete, so streak history isn't lost.                                                   |
| `createdAt`     | `Date`     | `.now`    |                                                                                              |

## Relationships

- `timeWindows: [HabitTimeWindow]?` (optional, per CloudKit relationship constraint) — one entry per daily occurrence (e.g. Fajr/Dhuhr/Asr/Maghrib/Isha windows for a salah habit, or a single window for a simple daily habit). Whether this is its own SwiftData model or an embedded value type is an open question below.

## CloudKit constraints applied

- All properties have defaults.
- No unique constraints.
- The one relationship (`timeWindows`) is optional.

## Open questions

- **Streak granularity**: for a 5-occurrence-per-day habit like salah, is the streak "all 5 done today" (day-level) or per-window (e.g. separate Fajr streak vs. Isha streak)? This significantly changes the model shape.
- **`HabitTimeWindow` shape**: needs its own field list (start time, end time, label) if it becomes a related model — not drafted here, pending the streak-granularity answer above.
- **Presets**: is `presetKey` enough, or do presets need their own config (e.g. default window times) that ships with the app rather than being user data?
- **Anchor overlap**: prayer *windows* are explicitly called out as an Anchor example too ("prayer windows" in the Anchor row of CLAUDE.md's primitives table). Need to confirm the boundary: is the salah *habit* (streak, "did I pray today") a Habit, while each individual prayer-window *reminder/attendance event* is a separate generated Anchor? [ADR 0001](../architecture/decisions/0001-anchor-object-type) is referenced for this but is currently an empty stub — needs to be filled in before this is settled.
