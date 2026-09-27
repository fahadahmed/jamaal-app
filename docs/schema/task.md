# Task

> **Status: reviewed, resolved for v1.** Fields below reflect decisions made in review; see CLAUDE.md's Git workflow / issue history for the discussion. Sharing/referral fields are still deliberately excluded — see "Open questions."

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
| `rolloverCount` | `Int`    | `0`            | Incremented each day the rules engine rolls an incomplete dated task forward. Exact rollover behavior (indefinite vs. surfaced differently after N days) is deferred to the rules-engine module design — see [issue #7](https://github.com/fahadahmed/jamaal-app/issues/7). |
| `category`    | `String`   | `"personal"`   | One of `personal` / `family` / `work` — powers the unified Today List. Raw `String` rather than an enum type or separate model, for CloudKit-safe SwiftData simplicity; a typed enum wrapper can sit on top in Swift. |
| `priority`    | `String`   | `"none"`       | One of `none` / `low` / `medium` / `high`. Raw `String`, same rationale as `category`.        |

## Relationships

None currently — Task is a leaf primitive with no cross-links to Habit or Anchor.

## CloudKit constraints applied

- All properties have defaults (no bare `let`).
- No `@Attribute(.unique)` on `id` or any field.
- No relationships, so nothing to mark optional here — carried forward as a reminder for when relationships are added.

## Open questions

- **Sharing/referral**: CLAUDE.md notes this is in scope for v1 but not yet reflected in any primitive — likely adds fields here (e.g. shared task ownership) once [the sharing/referral design pass](https://github.com/fahadahmed/jamaal-app/issues/8) lands. Deliberately left out of this draft.
