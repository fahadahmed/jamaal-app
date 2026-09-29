# Task

> **Status: reconciled with master summary v2 — draft, needs review.** Builds on the v1-resolved schema and folds in v2's effort estimates, deferral behaviour and hidden Eisenhower. See [ADR 0002](../architecture/decisions/0002-reconcile-master-summary-v2) for what changed and why.

Something the user **does**. Created by the user, tracked via completion (not streaks or attendance — see [Habit](habit) and [Anchor](anchor) for those).

Tasks live in **one flat list** — no projects, no tags, no sub-lists. `category` is a label and optional filter, never a grouping axis.

## Fields

| Field           | Type      | Default   | Notes |
| --------------- | --------- | --------- | ----- |
| `id`            | `UUID`    | `UUID()`  | Stable identity across CloudKit sync. |
| `title`         | `String`  | `""`      | |
| `notes`         | `String?` | `nil`     | Optional lightweight markdown (checklists, bold/italic, links, inline code) — surfaced as a tappable checklist in the task detail. |
| `dueDate`       | `Date?`   | `nil`     | Day granularity. `nil` = backlog / "Someday". |
| `effortMinutes` | `Int?`    | `nil`     | Optional estimate: 15 / 30 / 60 / 120. `nil` = unestimated (counts as zero toward load). |
| `priority`      | `String`  | `"none"`  | One of `none` / `low` / `medium` / `high`. **This is the *importance* axis** of the hidden Eisenhower lens (see below). Raw `String` for CloudKit-safe simplicity. |
| `isCompleted`   | `Bool`    | `false`   | |
| `completedAt`   | `Date?`   | `nil`     | Set when `isCompleted` flips true; cleared if un-completed. |
| `droppedAt`     | `Date?`   | `nil`     | Set when the user drops a task (Night Planning carry-forward "Drop", or delete-from-detail). Soft-delete so history/wellbeing detection keep working. A dropped task never appears on Today. |
| `deferralCount` | `Int`     | `0`       | Times this task has been pushed to a later day — by the user (Keep/Later at night, defer from Today) or automatically (see below). Replaces the earlier `rolloverCount`. |
| `createdAt`     | `Date`    | `.now`    | |

## Relationships

- `category: TaskCategory?` — optional (CloudKit). `nil` renders as no label.
- `deferrals: [DeferralRecord]?` — optional (CloudKit). One record per deferral; drives reason history and avoidance detection.

### `TaskCategory`

An editable list, seeded on first launch with three defaults. Refines the earlier fixed `personal`/`family`/`work` strings.

| Field        | Type      | Default    | Notes |
| ------------ | --------- | ---------- | ----- |
| `id`         | `UUID`    | `UUID()`   | |
| `name`       | `String`  | `""`       | User-renamable. |
| `presetKey`  | `String?` | `nil`      | `"personal"` / `"family"` / `"work"` for the seeded defaults, `nil` for user-created. Mirrors `Habit.presetKey`. |
| `colorKey`   | `String`  | `"accent"` | Key into a small fixed set of ThreadsKit-derived colours — never a free colour picker. See open questions. |
| `sortOrder`  | `Int`     | `0`        | |
| `isArchived` | `Bool`    | `false`    | Soft-delete; tasks keep their label. Defaults can be renamed or archived but not hard-deleted. |
| `createdAt`  | `Date`    | `.now`     | |

Rules: one category per task; categories are labels + an optional Today filter only; they never create sections, never nest, never carry their own settings. That is what keeps this compatible with "no projects, no tags — ever".

### `DeferralRecord`

| Field        | Type      | Default        | Notes |
| ------------ | --------- | -------------- | ----- |
| `id`         | `UUID`    | `UUID()`       | |
| `deferredOn` | `Date`    | `.now`         | When the user (or the engine) deferred it. |
| `deferredTo` | `Date?`   | `nil`          | `nil` = Someday. |
| `reason`     | `String`  | `"unspecified"`| One of `tooMuch` / `notReady` / `noLonger` / `reschedule` / `unspecified`. Reason chips in the UI: Too much on / Not ready / No longer relevant. `unspecified` is used for automatic deferrals. |
| `task`       | `Task?`   | `nil`          | Inverse of `Task.deferrals`. |

## Deferral behaviour

A task is *deferred* whenever it moves to a later day without being completed. `deferralCount` increments and a `DeferralRecord` is written each time.

| Deferral # | What happens |
| ---------- | ------------ |
| 1st, 2nd   | Instant: task moves to tomorrow, no prompt. |
| 3rd onwards | A date picker opens (quick options: Later this week / Next week / Someday, plus calendar) with reason chips. Companion copy: "This one keeps slipping. Pick a day that actually works." |
| 5th onwards | Rules engine also raises a *suggest removal* signal. |

Where it happens:

- **Night Planning step 1 (carry-forward):** each incomplete task gets Keep (→ tomorrow, counts as a deferral) / Later (date picker) / Drop. See [night-planning.md](../journeys/night-planning).
- **Today:** a task can be deferred directly from its detail sheet.
- **Automatic:** if a dated task is still incomplete at day rollover and the user never handled it (skipped Night Planning), the engine defers it to today-again as an overdue item: `deferralCount += 1`, reason `unspecified`. So skipping planning never loses a task, and the 3-deferral rule still applies.

## Derived, never stored

These are computed by the rules engine at read time (module 1), not persisted:

- **Urgency** — a task is *urgent* if `dueDate` is tomorrow or earlier (overdue included), or `deferralCount >= 3`. The "tomorrow" window is a tunable constant.
- **Importance** — *important* if `priority` is `medium` or `high`.
- **Eisenhower quadrant** — from those two booleans. **Never shown to the user** as a matrix or label; it only drives ordering, capacity filtering and prompts.

  | | Important | Not important |
  |---|---|---|
  | **Urgent** | `doFirst` | `fitIn` |
  | **Not urgent** | `schedule` | `letGo` |

  (`doFirst` is from the v2 design; the other three names are proposals.)
- **Stale** — `deferralCount >= 3`.

## CloudKit constraints applied

- All properties have defaults or are optional.
- No `@Attribute(.unique)`.
- All relationships are optional.

## Open questions

- **Start / finish tracking**: only `completedAt` exists. Proposal: add `startedAt: Date?`, set by a **Start** action in the task detail that opens a focus view showing the markdown checklist; duration is derived from `startedAt`→`completedAt`, with no pause, no live timer and no penalty for overrunning, and it feeds Night Planning's review step. Needs confirmation before the task-detail screen is designed.
- **Category colours**: ThreadsKit has only `accent` and `terra` as accents. User-created categories need a small palette (a few extra ThreadsKit tokens, or tints of existing ones) — a design/tokens decision, see [threadskit-usage](../design/threadskit-usage).
- **Manual ordering**: v2 let the user drag to override the engine's order (`isManuallyOrdered`, `autoReorderEnabled`). Not modelled yet; decide alongside Today's sort rules (see [today-list.md](../journeys/today-list)).
- **Effort of Anchors and Habits**: only Tasks carry effort today, so only Tasks count toward load. Whether Anchor windows should reduce the available budget is open (see [rules-engine.md](../architecture/rules-engine)).
- **Sharing/referral**: deferred to v1.1 (see CLAUDE.md), no schema impact for now.
