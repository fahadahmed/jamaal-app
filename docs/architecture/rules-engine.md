# Rules Engine

> **Status: reconciled with master summary v2 — draft, needs review.** The six modules confirmed in issue #7 are kept (numbering is stable, other docs refer to it) and a seventh, **Capacity & load**, is added. v2's hidden Eisenhower, deferral escalation, load states, pattern detection and during-day guidance are folded in. See [ADR 0002](decisions/0002-reconcile-master-summary-v2).

Deterministic — same state + inputs always produce the same output, no ML/heuristics (per CLAUDE.md). Lives in `JamaalCore/Sources/JamaalCore/RulesEngine/`, no UI imports.

## Architecture

Every module conforms to one protocol:

```swift
protocol RuleModule {
    func evaluate(_ context: DayContext) -> [RuleSignal]
}
```

- Modules output **typed signals** (`RuleSignal`), never strings.
- A separate **message-template layer** turns signals into language in Jamaal's companion voice — calm, supportive, non-judgmental (see [app-flow.md](../journeys/app-flow)). The engine stays testable and language-free; a language model could later slot in at the message layer without touching the engine, but that is a future option, not a plan.

## Decisions resolved here

- **Capacity** stays an enum — `low` / `medium` / `high` — as the *user-facing* setting. It is the user's own call about how much they have in them; it is not computed. Each level maps to a **minute budget**: the user sets what a *medium day* is (Settings, default 180 minutes — v2's baseline), `low` is ⅔ of that (120) and `high` is 4⁄3 (240).
- **Load counts everything that takes time.** Tasks, habit windows and anchor rules each carry an optional duration (`effortMinutes`). The load check sums all three against the budget. Anchor and habit minutes are **committed** (can't be deferred); only task minutes are **movable**, so overload suggestions only ever propose deferring tasks.
- **Deferral replaces rollover.** A task moving to a later day, by the user or automatically, is a deferral with a count and a record (see [task.md](../schema/task)). 3rd deferral = stale + date picker (and a medium/high task is eased to `low`); 5th = suggest removal.
- **Importance**: three levels (`low` default, `medium`, `high`), set mainly in Night Planning; medium/high require a due date and can't be Someday; `low` tasks always sort after medium/high.
- **Night Planning is 5 steps** with a Keep/Later/Drop carry-forward folded into step 1, and its session is **persisted** (CloudKit sync means a session can resume on another device).
- **Reflect step** captures a numeric mood (1–5) and an optional free-text note.
- **Night Planning triggers** via a fixed evening notification (user-set time, default 20:00) in addition to being openable any time. Module 6 is therefore a hard dependency of module 4.
- **Nudge limits**: at most one wellbeing nudge and one during-day guidance card per day.

## Supporting models

Not primitives — engine state, documented here rather than in `docs/schema/`.

### `DayPlan`

The per-day record. Replaces the earlier `DailyCapacity`, widened because wellbeing pattern detection (runs of heavy days, completion collapse) needs a history of how each day actually went, and that can't be reconstructed from tasks once their due dates have been deferred.

| Field                    | Type      | Default    | Notes |
| ------------------------ | --------- | ---------- | ----- |
| `id`                     | `UUID`    | `UUID()`   | |
| `date`                   | `Date`    | `.now`     | Day granularity, normalised to midnight. |
| `capacity`               | `String`  | `"medium"` | `low` / `medium` / `high`. Written by Night Planning step 4 for tomorrow; editable on Today. |
| `plannedEffortMinutes`   | `Int`     | `0`        | Total planned minutes for the day (tasks + habit windows + anchors), snapshotted at Night Planning confirm. |
| `committedMinutes`       | `Int`     | `0`        | The part of that total that can't be deferred (habit windows + anchors). |
| `completedEffortMinutes` | `Int`     | `0`        | Updated as tasks complete. |
| `loadScore`              | `Int`     | `0`        | `plannedEffortMinutes / budget × 100`, snapshotted at confirm. |
| `wasOverloaded`          | `Bool`    | `false`    | Load state was `overloaded` or worse at confirm. |
| `completionRate`         | `Double`  | `0`        | 0–1, finalised at day close. |
| `planningCompletedAt`    | `Date?`   | `nil`      | When Night Planning confirmed this day's plan. |

### `NightPlanningSession`

Persists wizard progress so closing the app mid-flow resumes correctly.

| Field            | Type      | Default        | Notes |
| ---------------- | --------- | -------------- | ----- |
| `id`             | `UUID`    | `UUID()`       | |
| `forDate`        | `Date`    | `.now`         | The day being planned *for* (tomorrow at session start). |
| `currentStep`    | `String`  | `"reviewCarry"`| One of `reviewCarry` / `reflect` / `plan` / `capacity` / `confirm`. |
| `reflectionMood` | `Int?`    | `nil`          | 1–5. |
| `reflectionNote` | `String?` | `nil`          | |
| `isComplete`     | `Bool`    | `false`        | |
| `createdAt`      | `Date`    | `.now`         | |
| `completedAt`    | `Date?`   | `nil`          | |

Carry-forward choices are **not** stored on the session: Keep/Later/Drop apply to the task immediately (`deferralCount`, `DeferralRecord`, `droppedAt`) and are undoable until Confirm. On Confirm the session upserts the `DayPlan` for `forDate`.

### `NudgeLog`

Lets a deterministic engine enforce "one nudge a day" and "don't repeat a warning" without hidden state.

| Field         | Type      | Default    | Notes |
| ------------- | --------- | ---------- | ----- |
| `id`          | `UUID`    | `UUID()`   | |
| `kind`        | `String`  | `""`       | `wellbeing` / `guidance` / `fatigue` / `windowClosing` / `overload`. |
| `subjectKey`  | `String?` | `nil`      | The habit/task the nudge was about (UUID string), if any. |
| `sentAt`      | `Date`    | `.now`     | |
| `dismissedAt` | `Date?`   | `nil`      | |

### Preferences (not SwiftData)

Planning time (default 20:00), morning nudge on/off and time (default 08:00), during-day guidance on/off, wellbeing nudges on/off, appearance, larger text, auto-reorder — kept in `UserDefaults`/`@AppStorage`. These are per-device, which suits notification times; if cross-device sync of preferences is wanted later, `NSUbiquitousKeyValueStore` is the CloudKit-friendly upgrade.

## Modules

### 1. Task scheduling & prioritisation

- **Input**: today's date, all live tasks (not completed, not dropped), their deferral history.
- **Behavior**:
  - Derives urgency, importance and the hidden **Eisenhower quadrant** per task (rules in [task.md](../schema/task)). The quadrant is never shown to the user.
  - Orders tasks for Today by quadrant (`doFirst`, then `schedule`, `fitIn`, `letGo`), then `dueDate`, then `createdAt` — so `low` tasks, which are never important, naturally follow all medium/high tasks. Manual drag ordering is an open question.
  - Enforces the importance rules from [task.md](../schema/task): medium/high need a due date and never Someday; a medium/high task's 3rd deferral eases it to `low`.
  - Runs the automatic deferral at day rollover for dated tasks the user never handled.
  - Creates the next instance of a repeating task when the live one is completed or dropped (rules in [task.md](../schema/task#repeating-tasks)); dedups by `(seriesID, dueDate)`.
  - Escalation: `deferralCount >= 3` → stale and urgency raised; `>= 5` → suggest removal.
- **Signals**: `.taskOrder`, `.stale(task)`, `.suggestRemoval(task)`, `.priorityEased(task)` (medium/high → low on 3rd deferral), `.nextInstanceDue(series)`, `.pickPriorities` (5+ tasks in a plan and fewer than two `medium`/`high` → "pick one or two that matter most"), `.multipleDoFirst` (two or more `doFirst` tasks → companion asks "which matters most?").

### 2. Habit density & intelligence

- **Input**: `HabitEntry` history, `HabitTimeWindow` targets and schedule, current date.
- **Behavior**: derives each window's **density** — the per-day completion grid and rolling completion rate — per the rules in [habit.md](../schema/habit#density-not-streaks). There are no streaks: nothing resets or breaks, and a partial counted day is recorded as a partial, not a miss. From density it produces the plain-language read shown beside the grid, and detects:
  - **Fatigue** — more than 50% of due days missed over three weeks (counted habits use `completionRatio`, not binary) → suggest changing frequency.
  - **Window closing** — a due window still open and unfinished as it nears its end (a light reminder, never a warning about losing something).
  - **New-habit realism** — four or more habits created in one week → suggest starting with one or two.
- **Signals**: `.densityRead(habit)`, `.windowClosing(window)`, `.habitFatigue`, `.newHabitOverload`.

### 3. Anchor generation (window-bound instances, attendance)

- **Input**: all enabled `AnchorRule`s, a generation horizon (today + tomorrow).
- **Behavior**: decodes each rule's `configData` (two families, shapes in [anchor.md](../schema/anchor#configdata-shapes)) and generates concrete `Anchor` instances (`occurrenceDate`/`slotKey`/`windowStart`/`windowEnd`/`title`/`effortMinutes`, linked via `rule`, `attendanceStatus = pending`).
  - **Scheduled rules** (`schoolRun`, `binNight`, `plantWatering`, `custom`): for each date in the horizon that matches the recurrence, one instance per slot, with the window at local wall-clock `start` for `windowMinutes` (or the whole day if `allDay`), until `endDate`. Dates inside an `exceptions` range produce nothing.
  - **`afterLast` rules** (plants): not date-driven. Generates one live instance per slot; when it is resolved (`attended` / `skipped` / `delegated`) the next window opens `minDays` later and closes at the end of day `maxDays`, and after a `missed` one it opens the next day. An exception pauses the interval clock. These are *floating* Anchors: they count toward the day's minutes but don't split the day (see module 7).
  - **Prayer rules**: for each date, computes the day's prayer times on-device from date, location, `method`, `madhab`, `highLatitude` and per-prayer adjustments, then builds windows Fajr → sunrise, Dhuhr → Asr, Asr → Maghrib, Maghrib → Isha, Isha → `ishaEnds`. Deterministic for the same inputs.
  - **Idempotent**, keyed by `(rule, occurrenceDate, slotKey)` — *not* window start, because a rule edit or a recalculated prayer time can move the window without changing which occurrence it is. An existing instance — including a `skipped`, `attended` or `missed` one — is never recreated or duplicated; two devices generating at once dedup to one.
  - **Rule edits, disabling and location changes** update *pending* instances from today onward in place (matched by key), remove pending instances the rule no longer produces, and never rewrite attended, missed or skipped ones.
  - **Undecodable `configData`** (invalid, or a newer `version` than this build understands) → the rule is skipped, flagged "needs attention", and never deleted or partially generated.
  - One-off Anchors (no `rule`) need no generation but are finalised like any other.
- **Window state and logging**: derives each Anchor's window state (`upcoming` / `open` / `closingSoon` / `closed`) from the clock and enforces the logging rules in [anchor.md](../schema/anchor#window-state-and-logging-rules) — `attended` only while open, `skipped`/`delegated` any time before it closes, `closed` final. Signal: `.windowState(anchor)`.
- **Output**: new `Anchor` rows. Instances whose window has passed while still `pending` are finalised as `missed` at the next evaluation (`skipped` and `delegated` instances are left alone and never count as misses) — no consequence beyond the record; messaging is copy, not data.

### 4. Night Planning orchestration (5-step wizard state machine)

- **Input**: today's tasks (completed / incomplete), Habit entries, Anchor attendance, user input per step.
- **Behavior**: drives `NightPlanningSession` through `reviewCarry → reflect → plan → capacity → confirm`:
  1. **Review & carry forward** — read-only look back at the day (tasks done, habit windows incl. partials, Anchor attendance), then each incomplete task gets Keep (→ tomorrow) / Later (date picker, `Someday` allowed) / Drop. Applies the deferral rules from [task.md](../schema/task): 3rd+ deferral opens the date picker with reason chips.
  2. **Reflect** — mood 1–5 + optional note.
  3. **Plan tomorrow** — choose/reorder/add tasks and habits for tomorrow; tomorrow's Anchors shown read-only. This is where **importance is set** (due date pre-filled with tomorrow for medium/high); emits `.pickPriorities` when the plan has 5+ tasks and fewer than two are `medium`/`high`. Surfaces `schedule`-quadrant tasks as suggestions.
  4. **Capacity & load check** — set tomorrow's capacity (`low`/`medium`/`high`); shows the computed load state from module 7 and flags an overloaded day *before* confirming.
  5. **Confirm** — locks the plan, upserts `DayPlan`, hands off to module 6 to schedule tomorrow's notifications. Done screen: "Good night" plus a plain count of nights planned ("12 nights planned" — derived from completed sessions, not a streak).
- **Depends on module 6** (evening trigger) and **module 7** (load check).
- **Output**: a completed `NightPlanningSession`, a `DayPlan` for tomorrow.

### 5. Wellbeing (scoring and pattern detection)

- **Input**: `reflectionMood` history, `DayPlan` history (`wasOverloaded`, `completionRate`), `HabitEntry` history, `DeferralRecord`s.
- **Behavior**: purely derived — no stored wellbeing model.
  - **Score**: shows "gathering data" until at least 7 days of mood exist, then a rolling score (window 7 or 14 days, TBD).
  - **Pattern detection** over a rolling 7–14 days: `heavyRun` (3+ overloaded days in a row), `habitNeglect` (a habit missed 3+ days), `completionCollapse`, `avoidance` (a task deferred 4+ times), `weekendOverplan`.
  - At most **one** wellbeing nudge per day (checked against `NudgeLog`).
- **Signals**: `.wellbeingScore`, `.gatheringData`, `.pattern(kind)`.

### 6. Notification, nudge & guidance logic

- **Input**: habit windows nearing their end, upcoming Anchor windows, the planning time, capacity/load, `NudgeLog`.
- **Behavior**: schedules local notifications (`UNUserNotificationCenter`):
  - the **evening Night Planning prompt** (fixed, user-set time);
  - an optional **morning nudge**;
  - per-window **habit reminders** and a light **window-closing** nudge as a window's end approaches;
  - **during-day guidance** — a highlighted task ("Start here" / "Good now") plus one companion card, max one per day. Chosen deterministically from time of day, remaining effort vs. remaining free time, a lighter-tasks-in-the-early-afternoon curve, and open habit windows.
- **Trial and subscription**: when the trial ends unsubscribed, the evening Night Planning notification and habit/guidance nudges are cancelled and only a small number of trial-end reminders are sent (proposal: day 12, 14 and 15); everything returns on subscribing.
- **Permission** is requested during onboarding, framed around the evening planning reminder.
- **Fallback if notifications are denied**: an in-app banner at planning time ("Start evening planning →") and a warning card in Settings with a deep link to iOS Settings.
- **Output**: scheduled notifications and in-app cards; `NudgeLog` rows.

### 7. Capacity & load

- **Input**: `DayPlan.capacity` for the day; tasks planned for that day, the due habit windows and the day's anchors, each with `effortMinutes`; the user's medium-day minutes.
- **Behavior**: `budget = minutes(capacity)` (medium = the user's medium-day setting, low = ⅔ of it, high = 4⁄3 of it); `committedMinutes` = habit windows + anchors; `plannedEffortMinutes` = committed + task minutes; `loadScore = plannedEffortMinutes / budget × 100`. Items with no duration count as zero, and the engine reports how many so the UI can nudge gently. State thresholds (from v2):

  | Load score | State | Response |
  | ---------- | ----- | -------- |
  | < 70%      | `light`      | none |
  | 70–90%     | `balanced`   | none |
  | 90–110%    | `full`       | subtle |
  | 110–140%   | `overloaded` | gentle warning |
  | > 140%     | `exhausting` | strong suggestion to defer something |

  Also decides what Today shows at each capacity level (proposed, tunable): **low** — Anchors, `doFirst` tasks and habits whose window is closing and not yet done; **medium** — everything due except `letGo` tasks; **high** — everything due. Anything not shown appears under a collapsed "also today" section with a count — nothing silently disappears.
- **Anchors in the load**: `skipped` and `delegated` Anchors stop counting as committed minutes once set (nobody has to spend that time). `afterLast` Anchors count their minutes but are *floating* — they don't form the day's fixed spine. How fixed Anchors shape the day into free blocks belongs to the capacity-model decision, still open.
- **Suggested capacity**: from tomorrow's committed minutes the engine can suggest a level (e.g. committed minutes above half the medium budget → suggest `low`). The user always decides.
- **Signals**: `.loadState`, `.committedMinutes`, `.suggestedCapacity`, `.missingDurations(count)`, `.todayVisibility`.

## Open questions

- **Numbers are proposals**: the medium-day default (180) and the ⅔ / 4⁄3 multipliers for low/high, the load thresholds, the rollover-to-stale threshold (3), removal suggestion (5), and the wellbeing window (7 vs. 14) are all constants, easy to tune.
- **Missing durations** count as zero, so load can be understated until durations are filled in. Current proposal: Night Planning's capacity step gently notes how many items have no duration, rather than guessing. Habit presets and the built-in anchor types ship default durations to keep this rare.
- **Where the medium-day setting lives**: it changes computed load, so it should sync across devices. Preferences are per-device (`@AppStorage`); this one probably belongs in a small synced settings store (`NSUbiquitousKeyValueStore` or a `UserSettings` model). Decide before implementation.
- **Wellbeing score composition**: v2's Wellbeing screen showed a single 0–100 score; this doc derives it from mood only. Decide whether completion rate and load also contribute.
- **Prayer-time library**: `configData` fixes the settings, not the implementation. Choose a well-tested prayer-time library (or implementation) at build time and check its method list against the `method` values offered, plus its high-latitude handling.
- **Notification limits**: iOS caps pending local notifications at 64 — confirm the reminder + nudge volume stays well under that. Habit reminders add up, and five prayers a day for several days ahead adds more if each gets a reminder.
- **Manual ordering** of Today (see [task.md](../schema/task)).
