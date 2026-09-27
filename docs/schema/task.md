# Task

> **Status: draft, needs review.** This is a first-pass proposal based on CLAUDE.md's primitives table and CloudKit constraints — not yet confirmed. See "Open questions" below.

Something the user **does**. Created by the user, tracked via completion (not streaks or attendance — see [Habit](habit) and [Anchor](anchor) for those).

## Fields

| Field         | Type       | Default        | Notes                                                                                     |
| ------------- | ---------- | -------------- | ------------------------------------------------------------------------------------------- |
| `id`          | `UUID`     | `UUID()`       | Stable identity across CloudKit sync.                                                       |
| `title`       | `String`   | `""`           |                                                                                               |
| `notes`       | `String?`  | `nil`          | Optional lightweight markdown (checklists, bold/italic, links, inline code) — see CLAUDE.md. |
| `dueDate`     | `Date?`    | `nil`          | Optional; undated tasks are backlog items.                                                   |
| `isCompleted` | `Bool`     | `false`        |                                                                                               |
| `completedAt` | `Date?`    | `nil`          | Set when `isCompleted` flips true; cleared if un-completed.                                  |
| `createdAt`   | `Date`     | `.now`         |                                                                                               |
| `rolloverCount` | `Int`    | `0`            | Incremented each day the rules engine rolls an incomplete dated task forward.                |
| `category`    | `String`   | `"personal"`   | One of `personal` / `family` / `work` — powers the unified Today List. Stored as `String`, not enum, per CloudKit-safe SwiftData patterns (see open question below). |

## Relationships

None currently — Task is a leaf primitive with no cross-links to Habit or Anchor.

## CloudKit constraints applied

- All properties have defaults (no bare `let`).
- No `@Attribute(.unique)` on `id` or any field.
- No relationships, so nothing to mark optional here — carried forward as a reminder for when relationships are added.

## Open questions

- **Category representation**: raw `String` (shown above) vs. a SwiftData-compatible enum wrapper vs. a separate `TaskCategory` model (would need a relationship, which must then be optional). Depends on whether categories become user-customizable later.
- **Priority**: not mentioned anywhere in CLAUDE.md — is priority in scope for v1, or deferred?
- **Rollover rules**: does an overdue task roll to "today" indefinitely, or does it get surfaced differently after N days? This is rules-engine module 1's job, but the field(s) needed here depend on the answer.
- **Sharing/referral**: CLAUDE.md notes this is in scope for v1 but not yet reflected in any primitive — likely adds fields here (e.g. shared task ownership) once [the sharing/referral design pass](https://github.com/fahadahmed/jamaal-app/issues/8) lands. Deliberately left out of this draft.
