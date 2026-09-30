# Rules Engine

> **Status: reconciled with master summary v2 — draft, needs review.** The six modules confirmed in issue #7 are kept (numbering is stable, other docs refer to it) a seventh, **Capacity & load**, and an eighth, **Focus sessions**, are added. v2's hidden Eisenhower, deferral escalation, load states, pattern detection and during-day guidance are folded in. See [ADR 0002](decisions/0002-reconcile-master-summary-v2).

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

- **Capacity** stays an enum — `low` / `medium` / `high` — as the *user-facing* setting. It is the user's own call about how much they have in them; it is not computed. Each level maps to a **minute budget for focused tasks**: the user sets what a *normal day* is (onboarding and Settings, default 180 minutes — v2's baseline; it is the `medium` level), `low` is ⅔ of that (120) and `high` is 4⁄3 (240). The app never changes that number by itself: it **suggests** a new one from the last four weeks of actual focus time, and the user accepts or ignores it. Weekday default levels (weekends `low`) are stored in `UserSettings`.
- **Two measures, kept apart.** The **energy budget** counts *tasks only* — the design defines a normal day as focused work outside meetings and life admin. **Free time** is the working day (from a start time to a user-set end time) minus fixed Anchors, which cut it into blocks, and the minutes of flexible Anchors and habits, which just subtract. A plan has to fit both: task minutes within the budget, and each task within a free block. Anchors and habits therefore no longer eat the energy budget; they shrink the time.
- **The day ends at a user-set time, not midnight** (proposal: 19:00). It is a *soft* planning boundary: overflow is named, never blocked, and one tap moves it to tomorrow. The **day rollover** — by default midnight, user-set — stays the hard boundary (auto-deferral, session auto-close, `DayPlan` close); see [The day boundary](#the-day-boundary).
- **Deferral replaces rollover.** A task moving to a later day, by the user or automatically, is a deferral with a count and a record (see [task.md](../schema/task)). 3rd deferral = stale + date picker (and a medium/high task is eased to `low`); 5th = suggest removal.
- **Importance**: three levels (`low` default, `medium`, `high`), set mainly in Night Planning; medium/high require a due date and can't be Someday; `low` tasks always sort after medium/high.
- **Night Planning is five steps** — Review today → Carry forward → Build tomorrow → Check the load → Close the day — and its session is **persisted** (CloudKit sync means a session can resume on another device). Build tomorrow opens on tomorrow's fixed commitments with named free gaps; tasks are not placed into gaps. **Skip tonight** closes the flow without a plan.
- **Mood** is one optional line at the end of the Review step: a numeric mood (1–5) and an optional free-text note. There is no separate Reflect step; wellbeing also derives from behaviour.
- **Night Planning triggers** via a fixed evening notification (user-set time, default 20:00) in addition to being openable any time. Module 6 is therefore a hard dependency of module 4.
- **Focus sessions** (the task timer) follow the design's locked decisions: an ambient chip on every tab (Live Activity deferred to v1.1), count-up overrun with no alarm or nudge, one timer at a time settled with Done / Defer / Drop, abandon logs partial time, auto-close at midnight (the day rollover). See [task.md](../schema/task#focus-sessions-begin--pause--finish) and module 8.
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
| `plannedTaskMinutes`     | `Int`     | `0`        | Minutes of tasks planned for the day, snapshotted when the day is closed (step 5). Counts against the energy budget. |
| `freeMinutes`            | `Int`     | `0`        | Free time in the working day when the day is closed, after fixed and flexible commitments. |
| `committedMinutes`       | `Int`     | `0`        | Minutes of fixed Anchors, flexible Anchors and habit windows inside the working day — what can't be deferred. |
| `completedEffortMinutes` | `Int`     | `0`        | Updated as tasks complete: actual focus time from sessions where there is one, else the estimate. |
| `loadScore`              | `Int`     | `0`        | `plannedTaskMinutes / budget × 100`, snapshotted when the day is closed. |
| `wasOverloaded`          | `Bool`    | `false`    | Load state was `overloaded` or worse when the day was closed. |
| `completionRate`         | `Double`  | `0`        | 0–1, finalised at day close. |
| `planningCompletedAt`    | `Date?`   | `nil`      | When Night Planning confirmed this day's plan. |

### `NightPlanningSession`

Persists wizard progress so closing the app mid-flow resumes correctly.

| Field            | Type      | Default        | Notes |
| ---------------- | --------- | -------------- | ----- |
| `id`             | `UUID`    | `UUID()`       | |
| `forDate`        | `Date`    | `.now`         | The day being planned *for* (tomorrow at session start). |
| `currentStep`    | `String`  | `"review"`     | One of `review` / `carry` / `build` / `load` / `close`. |
| `mood`           | `Int?`    | `nil`          | 1–5, from the optional mood line on the Review step. |
| `moodNote`       | `String?` | `nil`          | |
| `isComplete`     | `Bool`    | `false`        | `true` once the day is closed (step 5). |
| `skippedAt`      | `Date?`   | `nil`          | Set by **Skip tonight**; the session ends without a plan and no `DayPlan` is written. |
| `createdAt`      | `Date`    | `.now`         | |
| `completedAt`    | `Date?`   | `nil`          | |

Carry-forward choices are **not** stored on the session: Keep/Later/Drop apply to the task immediately (`deferralCount`, `DeferralRecord`, `droppedAt`) and are undoable until the day is closed. On *Close the day* the session upserts the `DayPlan` for `forDate`.

### `NudgeLog`

Lets a deterministic engine enforce "one nudge a day" and "don't repeat a warning" without hidden state.

| Field         | Type      | Default    | Notes |
| ------------- | --------- | ---------- | ----- |
| `id`          | `UUID`    | `UUID()`   | |
| `kind`        | `String`  | `""`       | `wellbeing` / `guidance` / `fatigue` / `windowClosing` / `overload` / `morningPlanCard` (the once-only "No plan for today" card; `subjectKey` is the date) / `habitPromotion` (v1.1 — `subjectKey` is the declined title) / `normalDaySuggestion` (`subjectKey` is the suggested minutes; logged when shown, and again if dismissed). |
| `subjectKey`  | `String?` | `nil`      | The habit/task the nudge was about (UUID string), if any. |
| `sentAt`      | `Date`    | `.now`     | |
| `dismissedAt` | `Date?`   | `nil`      | |

### `UserSettings`

The few settings that change *computed* results, so they must be identical on every device. A single row, synced via CloudKit. (Notification and appearance preferences stay per-device below.)

| Field              | Type   | Default | Notes |
| ------------------ | ------ | ------- | ----- |
| `id`               | `UUID` | `UUID()`| |
| `mediumDayMinutes` | `Int`  | `180`   | The user's *normal day* of focused work; the `medium` budget. `low` = ⅔, `high` = 4⁄3. Set in onboarding, editable in Settings. |
| `dayStartMinute`   | `Int`  | `480`   | Minutes since midnight when the working day starts (08:00). Free time for tomorrow's plan starts here; for today it starts at the later of now and this. |
| `dayEndMinute`     | `Int`  | `1140`  | Minutes since midnight when the working day ends (19:00; users pick, typically 19:00–20:00). The soft planning boundary. |
| `rolloverMinute`   | `Int`  | `0`     | Minutes since midnight when the app's day rolls over (00:00 by default; the UI offers 00:00–06:00, for people who are up late or work nights). Must be earlier than `dayStartMinute`. See [The day boundary](#the-day-boundary). |
| `weekdayLevels`    | `String` | `"{\"6\":\"low\",\"7\":\"low\"}"` | JSON map of ISO weekday (Mon=1 … Sun=7) → default capacity level (`low` / `medium` / `high`); a weekday not listed is `medium`. Weekends default to `low`. The level a day uses when no `DayPlan` was confirmed (for example after *Skip tonight*), and the one Night Planning pre-selects. Editable in Settings. |
| `firstLaunchAt`    | `Date?`| `nil`   | When the app was first launched; the synced fallback for the trial start date if StoreKit's original-download date is unavailable. Set once, by the first device. |
| `createdAt`        | `Date` | `.now`  | |

CloudKit has no unique constraints, so two devices can each seed a row. The engine keeps the earliest-created row and deletes the rest.

### Preferences (not SwiftData)

Planning time (default 20:00), morning nudge on/off and time (default 08:00), during-day guidance on/off, wellbeing nudges on/off, appearance, larger text, auto-reorder — kept in `UserDefaults`/`@AppStorage`. These are per-device, which suits notification times; if cross-device sync of preferences is wanted later, `NSUbiquitousKeyValueStore` is the CloudKit-friendly upgrade.

## The day boundary

**The app's day rolls over at `UserSettings.rolloverMinute`** (default 00:00). Before that time the app still treats it as the previous day, everywhere.

**Logical date.** `logicalDate(t) = calendar date of (t − rolloverMinute)`, in the device's current time zone. "Today" always means the logical date: Today's list, which day a habit log or an Anchor counts for, which day a session belongs to. With the default it is the ordinary calendar day.

**Calendar dates are floating.** Every day-granularity field — `Task.dueDate`, `HabitEntry.date`, `Anchor.occurrenceDate`, `DayPlan.date`, `NightPlanningSession.forDate`, and the dates inside rule `startDate` / `endDate` / `exceptions` and habit `pausesData` — is a *calendar date*, not an instant. Store it as a `Date` at **12:00 UTC** of that date, so every device shows the same day whatever its time zone. Times of day (Anchor windows, session start and end) are real instants; Anchor start times are local wall-clock. After travelling across time zones the logical date is simply recomputed from now, so a day can briefly repeat or skip an hour, which is accepted.

**Rollover is lazy and idempotent.** The engine can't rely on running at the boundary — the app may be closed or the device asleep. On launch, foreground, background refresh and when synced data arrives, it processes every logical day that has ended since it last ran (tracked locally per device), oldest first. For each ended day *D*:

1. **Auto-defer** each live, dated task due on or before *D* that wasn't completed, dropped or already deferred that day — a deferral with reason `unspecified` (see [task.md](../schema/task#deferral-behaviour)).
2. **Finalise `DayPlan(D)`**: completion rate and completed minutes.
3. **Close live focus sessions** at the boundary instant (`autoClosed`, `endedAt` = the rollover time, *not* "now"), so a device that slept through midnight never invents phantom hours.
4. **End an unfinished Night Planning session** for *D* as skipped, so the morning card can offer the plan (already-applied carry-forward choices stay).

Habit entries, Anchor attendance and avoid-habit days need no rollover writes: they are attributed by logical date when logged or derived when read.

**Idempotent keys make two devices converge.** Each step is keyed so repeating or racing it changes nothing: auto-deferral by `(task, logicalDate)`, `DayPlan` by date, session closing by the session itself.

**At most one deferral per task per logical day.** Whichever path gets there first — the automatic one at rollover, or the user's Keep / Later / Defer — writes the deferral; a later user choice that same day **refines** the existing record (its reason and `deferredTo`) instead of adding a second. So running Night Planning at 00:30 after a midnight rollover never double-counts.

**Night Planning's target day.** The plan is for the **first date whose working-day start (`dayStartMinute`) is still in the future**; the day it reviews is that date minus one. At 23:00 that is tomorrow. At 00:30 with a midnight rollover it is *today's* new date — the morning the user is about to wake into — and the review is yesterday. With a 03:00 rollover, at 00:30 it is tomorrow, because the logical day hasn't ended yet.

**Attribution by logical date.** An Anchor's `occurrenceDate` is `logicalDate(windowStart)`; a habit entry's `date` is the logical date of the log; a session's day is `logicalDate(startedAt)`. A night owl with a 03:00 rollover logging a habit at 01:00 counts it for the day they are still living.

## Modules

### 1. Task scheduling & prioritisation

- **Input**: today's date, all live tasks (not completed, not dropped), their deferral history.
- **Behavior**:
  - Derives urgency, importance and the hidden **Eisenhower quadrant** per task (rules in [task.md](../schema/task)). The quadrant is never shown to the user.
  - Orders tasks for Today by quadrant (`doFirst`, then `schedule`, `fitIn`, `letGo`), then `dueDate`, then `createdAt` — so `low` tasks, which are never important, naturally follow all medium/high tasks. Manual drag ordering is an open question.
  - Enforces the importance rules from [task.md](../schema/task): medium/high need a due date and never Someday; a medium/high task's 3rd deferral eases it to `low`.
  - Runs the automatic deferral at day rollover for dated tasks the user never handled (lazily and idempotently — see [The day boundary](#the-day-boundary)); at most one deferral per task per logical day.
  - Creates the next instance of a repeating task when the live one is completed or dropped (rules in [task.md](../schema/task#repeating-tasks)); dedups by `(seriesID, dueDate)`.
  - Escalation: `deferralCount >= 3` → stale and urgency raised; `>= 5` → suggest removal.
- **Signals**: `.taskOrder`, `.stale(task)`, `.suggestRemoval(task)`, `.importanceEased(task)` (medium/high → low on 3rd deferral), `.nextInstanceDue(series)`, `.pickPriorities` (5+ tasks in a plan and fewer than two `medium`/`high` → "pick one or two that matter most"), `.multipleDoFirst` (two or more `doFirst` tasks → companion asks "which matters most?").

### 2. Habit density & intelligence

- **Input**: `HabitEntry` history, `HabitTimeWindow` targets and schedule, the habit's `kind` and `pausesData`, focus sessions on habit windows, current date.
- **Behavior**: derives each window's **density** — the per-day completion grid and rolling completion rate — per the rules in [habit.md](../schema/habit#density-not-streaks). There are no streaks: nothing resets or breaks, and a partial counted or timed day is recorded as a partial, not a miss. Behaviour by kind (rules in [habit.md](../schema/habit#habit-kinds)):
  - **Timed**: a habit session's `actualSeconds` becomes minutes on that day's entry; the window completes when minutes reach the target.
  - **Avoid**: a day is `missed` when slips exceed the allowance, `complete` only when slips are within it **and** the user engaged that day (any recorded activity or an explicit *Held today* tap), otherwise `empty` — silence is never success. Derived when read, not stored as a default success.
  - **Pauses**: paused days are unscheduled — no cell, not counted, out of denominators, no reminders, hidden from Today and Night Planning.
  From density it produces the plain-language read shown beside the grid, and detects:
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

- **Input**: today's tasks (completed / incomplete), Habit entries, Anchor attendance, focus-session time, tomorrow's Anchors, user input per step.
- **Behavior**: drives `NightPlanningSession` through `review → carry → build → load → close`, or to `skipped`:
  1. **Review today** — read-only look back at the day (tasks done, habit windows incl. partials, Anchor attendance, time spent against estimates), ending in one optional mood line (`mood`, `moodNote`).
  2. **Carry forward** — each incomplete task gets Keep (→ tomorrow) / Later (date picker, `Someday` hidden for `medium`/`high`) / Drop. Applies the deferral rules from [task.md](../schema/task): the 3rd+ deferral opens the date picker with reason chips, and eases a `medium`/`high` task to `low`. Passed through when nothing is incomplete.
  3. **Build tomorrow** — opens on tomorrow's working day: fixed commitments drawn in, free gaps named by what surrounds them (`before the school run`, `between … and …`, `after …`) with their sizes, from module 7's free-block calculation. Then the user selects, reorders and adds tasks and habits (importance is set here; due date pre-filled with tomorrow for medium/high; `.pickPriorities` when the plan has 5+ tasks and fewer than two `medium`/`high`); `schedule`-quadrant tasks are suggested; a one-off Anchor can be added. Tasks are **not** assigned to gaps; `.taskDoesNotFit` flags any longer than the longest gap.
  4. **Check the load** — set tomorrow's capacity (`low`/`medium`/`high`) with the engine's suggested level; shows budget used, the load state, and any overflow past the day's end from module 7; the companion offers one specific move (defer a task) and never blocks.
  5. **Close the day** — locks the plan, upserts `DayPlan`, hands off to module 6 to schedule tomorrow's notifications. Done screen: what was planned, plus a plain count of nights planned ("12 nights planned" — derived from completed sessions, not a streak).
  - **Skip tonight** (any step): sets `skippedAt`, writes no `DayPlan`, leaves already-applied carry-forward choices in place. If no plan was confirmed for today, module 6 shows one quiet morning card ("No plan for today — two minutes to pick?"), once.
- **Depends on module 6** (evening trigger, notifications, morning card) and **module 7** (free blocks, load check).
- **Output**: a completed or skipped `NightPlanningSession`, and a `DayPlan` for tomorrow unless skipped.

### 5. Wellbeing (scoring and pattern detection)

- **Input**: `NightPlanningSession.mood` history (optional), `DayPlan` history (`wasOverloaded`, `completionRate`), `HabitEntry` history, `DeferralRecord`s.
- **Behavior**: purely derived — no stored wellbeing model.
  - **Score**: shows "gathering data" until at least 7 days of `DayPlan` history exist, then a rolling score (window 7 or 14 days, TBD). Behaviour (completion, load) drives it; mood, where given, is one extra input, so skipping the mood line never delays or breaks the score.
  - **Pattern detection** over a rolling 7–14 days: `heavyRun` (3+ overloaded days in a row), `habitNeglect` (a habit missed 3+ days), `completionCollapse`, `avoidance` (a task deferred 4+ times), `weekendOverplan`.
  - At most **one** wellbeing nudge per day (checked against `NudgeLog`).
- **Signals**: `.wellbeingScore`, `.gatheringData`, `.pattern(kind)`.

### 6. Notification, nudge & guidance logic

- **Input**: habit windows nearing their end, upcoming Anchor windows, the planning time, capacity/load, `NudgeLog`.
- **Behavior**: schedules local notifications (`UNUserNotificationCenter`):
  - the **evening Night Planning prompt** (fixed, user-set time);
  - an optional **morning nudge**, which — if no plan was confirmed for today (Night Planning was skipped or missed) — carries a single quiet in-app **morning card** ("No plan for today — two minutes to pick?"), shown once and never repeated if dismissed;
  - per-window **habit reminders** and a light **window-closing** nudge as a window's end approaches;
  - **during-day guidance** — a highlighted task ("Start here" / "Good now") plus one companion card, max one per day. Chosen deterministically from time of day, remaining effort vs. remaining free time, a lighter-tasks-in-the-early-afternoon curve, and open habit windows.
- **Trial and subscription**: when the trial ends unsubscribed, the evening Night Planning notification and habit/guidance nudges are cancelled and only a small number of trial-end reminders are sent (proposal: day 12, 14 and 15); everything returns on subscribing.
- **Permission** is requested during onboarding, framed around the evening planning reminder.
- **Fallback if notifications are denied**: an in-app banner at planning time ("Start evening planning →") and a warning card in Settings with a deep link to iOS Settings.
- **Output**: scheduled notifications and in-app cards; `NudgeLog` rows.

### 7. Capacity & load

Two independent measures, deliberately kept apart.

**Energy budget (the user's call).** `low` / `medium` / `high` sets a budget of *focused-task minutes*: `budget = minutes(level)` (medium = `UserSettings.mediumDayMinutes`, low = ⅔, high = 4⁄3). Only **tasks** count: `loadScore = plannedTaskMinutes / budget × 100`. Items with no duration count as zero, and the engine reports how many so the UI can nudge gently. State thresholds (from v2):

  | Load score | State | Response |
  | ---------- | ----- | -------- |
  | < 70%      | `light`      | none |
  | 70–90%     | `balanced`   | none |
  | 90–110%    | `full`       | subtle |
  | 110–140%   | `overloaded` | gentle warning |
  | > 140%     | `exhausting` | strong suggestion to defer something |

**Free time (the physical day).** The working day runs from `dayStartMinute` to `dayEndMinute`; for today it starts at the later of now and `dayStartMinute`. Subtract:

- **fixed Anchors** (`placement: fixed`): each is a busy block from `windowStart` for `effortMinutes`, and it **cuts** the day into free blocks;
- **flexible Anchors** (`placement: flexible`, and every `afterLast` Anchor) and **habit windows**: their minutes come off the total free time but don't cut it, because their position within the day isn't fixed.

Only busy time inside the working day counts, so an Anchor after the day's end (Isha at 20:15) doesn't fragment it. `skipped` and `delegated` Anchors, and anything already done, stop counting. The result is `freeMinutes` (blocks minus flexible minutes, floor 0) and `longestFreeBlock`.

**A plan has to fit both:**

- **Energy** — the load state above.
- **Time** — if `plannedTaskMinutes > freeMinutes`, the overflow is `plannedTaskMinutes − freeMinutes`, phrased "2h 10m past 19:00".
- **Fit** — a planned task with an estimate longer than `longestFreeBlock` gets a `.taskDoesNotFit` flag at planning time ("the 90-minute review doesn't fit before the school run"). Quiet, never blocking.

**Soft, never blocking.** Nothing is refused. Overflow is *named*: the meter turns terracotta and reads "N min past 19:00", with one tap to move the overflow to tomorrow — deterministically, taking tasks from the bottom of Today's order (quadrant, then due date) until the plan fits; the user can adjust. Adding a task that tips the day over shows "Day is full · offer tomorrow" at capture, never blocking. The **day's end is a planning boundary only**; midnight remains the hard rollover.

**Today visibility by level** (proposed, tunable): **low** — Anchors, `doFirst` tasks and habits whose window is closing and not yet done; **medium** — everything due except `letGo` tasks; **high** — everything due. Anything not shown appears under a collapsed "also today" section with a count — nothing silently disappears.

**Suggested capacity**: the highest level whose budget fits within `freeMinutes` (never below `low`) — for example, 2 hours free against a 3-hour normal day suggests `low`. The user always decides.

**Weekday defaults.** `UserSettings.weekdayLevels` gives each weekday a default level (weekends `low`, otherwise `medium`). It is what a day uses when no plan was confirmed, and what Night Planning pre-selects before the free-time suggestion above is shown.

**Learning the normal day — suggest only.** The engine never changes `mediumDayMinutes` by itself. It *suggests* a new value, deterministically:

- **Data**: the last 28 days of `DayPlan.completedEffortMinutes` (actual focus time from sessions where there is one, else the estimate), counting only days with at least one completed task or session, and only once **14 such days** exist.
- **Suggestion**: the median of those days, rounded to the nearest 15 minutes and kept within the slider's range (30 min – 6 h). It is offered only if it differs from the current value by **30 minutes or more**.
- **Delivery**: one quiet line in Settings next to the normal-day setting, and at most once in Night Planning's load step — "You usually do about 2h 40m — set your normal day to that?" — with *Set it* and *Not now*. It is logged in `NudgeLog` (`normalDaySuggestion`) when shown and again if dismissed, and is not offered again for 28 days, nor if the same value was already declined.
- Weekday differences are *not* learned; they are the user's per-weekday defaults.

- **Signals**: `.loadState`, `.timeOverflow(minutes)`, `.taskDoesNotFit(task)`, `.freeBlocks`, `.suggestedCapacity`, `.normalDaySuggestion(minutes)`, `.missingDurations(count)`, `.todayVisibility`.

### 8. Focus sessions (state machine)

- **Input**: `WorkSession` rows, the current time, today's and tomorrow's Anchors.
- **Behavior**: a small deterministic state machine over `WorkSession` (for a task or a timed habit's window; one live session across both) (`Idle → Running → Overrun`, `Paused` only by explicit pause; outcomes `finished` / `deferred` / `dropped` / `abandoned` / `autoClosed` — full rules in [task.md](../schema/task#focus-sessions-begin--pause--finish)).
  - Derives elapsed time from `startedAt`, so a killed or backgrounded app never loses or invents time.
  - Enforces **one live session**: a second Begin is refused until the first is settled (Done / Defer / Drop); on a cross-device conflict the later-started is closed as `abandoned`.
  - **Auto-closes at the day rollover** (default midnight, user-set; `autoClosed`, `endedAt` = the boundary instant; the softer working-day end doesn't stop a session), carries the task to tomorrow without counting a deferral, and emits a pick-it-back-up signal for tomorrow's list.
  - **Approaching edge**: while a session runs, finds the next Anchor whose window opens soon (threshold proposal: 30 minutes, tunable) and emits a signal the chip phrases as "Maghrib in 12 min". It never blocks or interrupts.
  - **Overrun** is a state, not an event: it emits no notification, colour change or nudge.
- **Signals**: `.sessionState`, `.sessionAutoClosed(task)`, `.pickUpRow(task)`, `.anchorApproaching(anchor, minutes)`.
- **Output**: session transitions written to `WorkSession`, task effects from the settle sheet (done / deferral / drop), and no scheduled notifications — sessions never nag. The Lock Screen Live Activity (v1.1) is driven locally by the same state, not by a push.

## Open questions

- **Numbers are proposals**: the medium-day default (180), the ⅔ / 4⁄3 multipliers for low/high, the working day defaults (08:00–19:00), the load thresholds, the rollover-to-stale threshold (3), removal suggestion (5), the wellbeing window (7 vs. 14), and the normal-day suggestion thresholds (28 days of history, 14 data days, a 30-minute difference, 15-minute rounding) are all constants, easy to tune.
- **Missing durations** count as zero, so load can be understated until durations are filled in. Current proposal: Night Planning's capacity step gently notes how many items have no duration, rather than guessing. Habit presets and the built-in anchor types ship default durations to keep this rare.
- **Wellbeing score composition**: v2's Wellbeing screen showed a single 0–100 score; this doc now derives it from behaviour (completion, load, patterns) with the optional mood as one extra input. The exact weighting is still to be decided — and X-04 in the design ("what makes 78 a 78") is the same open question.
- **Prayer-time library**: `configData` fixes the settings, not the implementation. Choose a well-tested prayer-time library (or implementation) at build time and check its method list against the `method` values offered, plus its high-latitude handling.
- **Notification limits**: iOS caps pending local notifications at 64 — confirm the reminder + nudge volume stays well under that. Habit reminders add up, and five prayers a day for several days ahead adds more if each gets a reminder.
- **Manual ordering** of Today (see [task.md](../schema/task)).
- **Avoid habits** are specified here as a proposal (the design has only a title); they need a design pass (H-06) before being treated as settled. **Detected habits** (offer to promote a repeating task) are v1.1.
