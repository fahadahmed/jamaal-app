# Task

> **Status: reconciled with master summary v2 — draft, needs review.** Builds on the v1-resolved schema and folds in v2's effort estimates, deferral behaviour and hidden Eisenhower. See [ADR 0002](../architecture/decisions/0002-reconcile-master-summary-v2) for what changed and why.

Something the user **does**. Created by the user, tracked via completion (not streaks or attendance — see [Habit](habit) and [Anchor](anchor) for those).

Tasks live in **one flat list** — no projects, no tags, no sub-lists. `category` is a label and optional filter, never a grouping axis.

## Fields

| Field           | Type      | Default   | Notes |
| --------------- | --------- | --------- | ----- |
| `id`            | `UUID`    | `UUID()`  | Stable identity across CloudKit sync. |
| `title`         | `String`  | `""`      | |
| `notes`         | `String?` | `nil`     | Optional lightweight markdown (checklists, bold/italic, links, inline code) — one note per task. Shown as a tappable checklist in the task detail and beneath the timer during a focus session. The finish and defer sheets can **append** an optional timestamped line ("Left a voicemail, call back Tuesday") rather than overwrite, so the note becomes the record of the attempts. No headings, tables or images. |
| `dueDate`       | `Date?`   | `nil`     | Day granularity. `nil` = backlog / "Someday". **Required when `priority` is `medium` or `high`.** |
| `effortMinutes` | `Int?`    | `nil`     | Optional estimate: 15 / 30 / 60 / 120. `nil` = unestimated (counts as zero toward load). |
| `priority`      | `String`  | `"low"`   | One of `low` / `medium` / `high` — there is no "none"; `low` is the baseline. **This is the *importance* axis** of the hidden Eisenhower lens (see below). Medium and high carry extra rules — see [Importance rules](#importance-rules). Raw `String` for CloudKit-safe simplicity. |
| `isCompleted`   | `Bool`    | `false`   | |
| `completedAt`   | `Date?`   | `nil`     | Set when `isCompleted` flips true; cleared if un-completed. |
| `droppedAt`     | `Date?`   | `nil`     | Set when the user drops a task (Night Planning carry-forward "Drop", or delete-from-detail). Soft-delete so history/wellbeing detection keep working. A dropped task never appears on Today. |
| `deferralCount` | `Int`     | `0`       | Times this task has been pushed to a later day — by the user (Keep/Later at night, defer from Today) or automatically (see below). Replaces the earlier `rolloverCount`. |
| `repeatKind`    | `String`  | `"none"`  | One of `none` / `daily` / `weekly` / `monthly`. See [Repeating tasks](#repeating-tasks). |
| `repeatWeekdays`| `String`  | `""`      | For `weekly`: ISO weekdays (Mon=1 … Sun=7), e.g. `"5"` for Fridays. Empty = same weekday as `dueDate`. |
| `seriesID`      | `UUID?`   | `nil`     | Shared by every instance of a repeating task; `nil` for one-off tasks. |
| `createdAt`     | `Date`    | `.now`    | |

## Relationships

- `category: TaskCategory?` — optional (CloudKit). `nil` renders as no label.
- `deferrals: [DeferralRecord]?` — optional (CloudKit). One record per deferral; drives reason history and avoidance detection.
- `sessions: [WorkSession]?` — optional (CloudKit). The focus sessions run on this task; their time sums into the task's actual time (derived, not stored).

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

## Importance rules

Importance has three levels — `low` (the default and the baseline), `medium`, `high` — and is chosen by the user, mainly set during **Night Planning's plan step** (it can also be set when adding a task or from the detail sheet).

1. **Medium and high require a due date.** Choosing either reveals a due-date row, pre-filled with the day being planned (today when adding on Today; tomorrow when prioritising in Night Planning), which cannot be cleared. Invariant: `priority ∈ {medium, high}` ⇒ `dueDate != nil`. Enforced in the engine/view-model (SwiftData can't express it), and normalised on read.
2. **No "Someday" for medium/high.** The Someday option is hidden in every date picker for these tasks, with a line such as "Important tasks need a day. Lower its importance to park it."
3. **Important tasks can't keep slipping.** On a medium/high task's **3rd** deferral its `priority` is set to `low`, and the companion says so plainly ("This one keeps slipping, so I've eased it to low. Raise it again when it's real."). Never silent. Once it is `low`, the date requirement and the Someday restriction no longer apply.
4. **Prioritisation prompt.** If a day's plan has **five or more tasks** and fewer than two of them are `medium`/`high`, the companion prompts the user to pick one or two that matter most. It's a prompt, not a block. This appears in Night Planning's plan step (and can appear on Today).
5. **Ordering.** By quadrant (`doFirst`, `schedule`, `fitIn`, `letGo`), then due date, then `createdAt`. Because `low` tasks are never important, they always fall in `fitIn`/`letGo` and so sort after every `medium`/`high` task. A `low` task with no date is a backlog task.

## Focus sessions (Begin / pause / finish)

A task can be worked in a **focus session**: the user taps **Begin**, a running chip appears on every tab, and the app stays fully usable. The session records real time so the day can be reviewed honestly and estimates can be learned from.

### `WorkSession`

| Field             | Type      | Default     | Notes |
| ----------------- | --------- | ----------- | ----- |
| `id`              | `UUID`    | `UUID()`    | |
| `startedAt`       | `Date`    | `.now`      | When Begin was tapped. Elapsed time is **always derived from this**, never accumulated in memory, so a killed app rebuilds the session exactly. |
| `endedAt`         | `Date?`   | `nil`       | `nil` while the session is live. |
| `pausedSeconds`   | `Int`     | `0`         | Total time spent in completed pauses. |
| `pausedAt`        | `Date?`   | `nil`       | Non-`nil` while an explicit pause is in progress. Backgrounding the app does **not** pause. |
| `estimateMinutes` | `Int?`    | `nil`       | Snapshot of `Task.effortMinutes` at Begin, so later edits don't rewrite what was estimated. |
| `outcome`         | `String`  | `"running"` | One of `running` / `finished` / `deferred` / `dropped` / `abandoned` / `autoClosed`. |
| `actualSeconds`   | `Int`     | `0`         | Written when the session closes: elapsed minus pauses. |
| `task`            | `Task?`   | `nil`       | Inverse of `Task.sessions`. |

Derived, not stored: `elapsed = (endedAt ?? now) − startedAt − pausedSeconds − (pausedAt.map { now − $0 } ?? 0)`; a session is *paused* when `pausedAt != nil`, and *overrun* when `elapsed` passes `estimateMinutes`. The model is subject-agnostic on purpose: a habit relationship can be added later for timed habits (additively, so it is CloudKit-safe) once the habit-types decision is made.

### States and outcomes

`Idle → Running → Overrun`, with `Paused` reachable only by an explicit pause from Running or Overrun.

- **Overrun counts up and says nothing.** No alarm, no colour change, no nudge, no haptic. The estimate is a guess we learn from, not a contract; "75 of 60" is shown neutrally.
- **Finish** (from the chip, the focus screen, or later the Lock Screen): a finish sheet shows actual against estimate and offers one optional note line; the task is marked done (`isCompleted`, `completedAt = endedAt`). A quiet toast offers **undo for 5 seconds**, which reopens the session and un-completes the task.
- **One timer at a time.** Tapping Begin on a second task, while one is live, raises a **settle sheet** naming the running task: **Done** (finished), **Defer to tomorrow** (`deferred` — a normal deferral with its count and record), or **Drop** (`dropped` — sets `droppedAt`). The new session only starts after the user chooses, and the elapsed time is logged whichever they pick.
- **Abandon** ends the session as `abandoned`: the partial time is kept, the task stays live and undone. "Abandoning is not failing."
- **The midnight wall**: a session still running at local midnight auto-closes as `autoClosed` with its partial time. The task is carried to tomorrow **without** counting a deferral (it was in progress), and tomorrow's list opens with a single row offering to pick it back up. The wall is a constant (00:00); the capacity decision may make it a user-set bedtime, and either way the auto-close rule is the same.
- **Multi-device**: at most one live session. If two devices each Begin, the later-started one is closed as `abandoned` (its time is logged) and the user sees the settle sheet on next open. (Proposal.)

Only tasks with time worth recording need a session; **Mark done** without one still works, and a task with no session simply has no actual time.

## Repeating tasks

A simple repeat for recurring "do" items ("submit timesheet every Friday", "pay rent monthly"). Recurring things that are *self-paced* stay Habits, and things *externally timed and attendance-based* stay Anchors; a repeating Task is the completion-based case neither covers.

- **Kinds**: daily; weekly on chosen days; monthly (same day-of-month as `dueDate`, clamped to month end). No end dates and no per-occurrence exceptions in v1.
- **Requires a due date.** `repeatKind != none` ⇒ `dueDate != nil`. Someday is hidden for repeating tasks.
- **One live instance per series.** Only one incomplete instance exists at a time, so a neglected weekly task never piles up into a backlog of copies.
- **Next instance**: when the live instance is completed **or dropped**, the next is created with the next occurrence strictly after `max(dueDate, completion day)`. So finishing a weekly Friday task on a Sunday schedules the *next* Friday, not the one already passed.
- **Copied to the next instance**: `title`, `notes`, `category`, `effortMinutes`, `priority`, repeat fields and `seriesID`. **Reset**: `isCompleted`, `deferralCount`, deferral records, `droppedAt`.
- **Drop skips only this occurrence** — the series continues. A separate **Stop repeating** action in the detail sheet ends it (sets `repeatKind` to `none` on the live instance).
- **Deferral rules apply per instance** (the 3rd-deferral easing of `medium`/`high` importance included). Moving an instance with Keep/Later changes only that instance's date; the following instance still follows the pattern.
- **Idempotency**: two devices may both try to create the next instance. The engine treats `(seriesID, dueDate)` as its dedup key and removes duplicates (CloudKit has no unique constraints).

## Deferral behaviour

A task is *deferred* whenever it moves to a later day without being completed. `deferralCount` increments and a `DeferralRecord` is written each time.

| Deferral # | What happens |
| ---------- | ------------ |
| 1st, 2nd   | Instant: task moves to tomorrow, no prompt. |
| 3rd onwards | A date picker opens (quick options: Later this week / Next week / Someday, plus calendar) with reason chips. Companion copy: "This one keeps slipping. Pick a day that actually works." If the task was `medium`/`high`, its priority is first eased to `low` (see [Importance rules](#importance-rules)), which is what makes Someday available in this picker. |
| 5th onwards | Rules engine also raises a *suggest removal* signal. |

Where it happens:

- **Night Planning step 1 (carry-forward):** each incomplete task gets Keep (→ tomorrow, counts as a deferral) / Later (date picker) / Drop. See [night-planning.md](../journeys/night-planning).
- **Today:** a task can be deferred directly from its detail sheet.
- **Automatic:** if a dated task is still incomplete at day rollover and the user never handled it (skipped Night Planning), the engine defers it to today-again as an overdue item: `deferralCount += 1`, reason `unspecified`. So skipping planning never loses a task, and the 3-deferral rule still applies.

## Derived, never stored

These are computed by the rules engine at read time (module 1), not persisted:

- **Urgency** — a task is *urgent* if `dueDate` is tomorrow or earlier (overdue included), or `deferralCount >= 3`. The "tomorrow" window is a tunable constant.
- **Importance** — *important* if `priority` is `medium` or `high`. Because those levels always have a due date, urgency is always defined for important tasks.
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

- **Learning from actuals**: sessions record actual time against the estimate, but how that feeds back (suggested estimates on new tasks, calibrating the medium-day length) is part of the still-open capacity-model decision.
- **Category colours**: ThreadsKit has only `accent` and `terra` as accents. User-created categories need a small palette (a few extra ThreadsKit tokens, or tints of existing ones) — a design/tokens decision, see [threadskit-usage](../design/threadskit-usage).
- **Re-raising after an auto-downgrade**: if the user raises a downgraded task back to medium/high, its `deferralCount` is still 3+, so its next deferral downgrades it again immediately. Probably right ("keeps slipping"), but confirm — the alternative is to reset the count used for this rule when importance is re-raised.
- **Prioritisation prompt**: soft (dismissible) as written. Should Night Planning instead require at least one priority task before Confirm when the threshold is hit?
- **Manual ordering**: v2 let the user drag to override the engine's order (`isManuallyOrdered`, `autoReorderEnabled`). Not modelled yet; decide alongside Today's sort rules (see [today-list.md](../journeys/today-list)).
- **Sharing/referral**: deferred to v1.1 (see CLAUDE.md), no schema impact for now.
