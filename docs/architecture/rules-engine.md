# Rules Engine

> **Status: draft, needs review.** Confirms/revises the 6 modules CLAUDE.md proposed as a first draft, against the now-resolved [schema](../schema/task) and [journey](../journeys/today-list) docs. This doc also resolves several open questions those docs deferred (capacity representation, reflection data shape, rollover threshold, Night Planning trigger).

Deterministic — same state + inputs always produce the same output, no ML/heuristics (per CLAUDE.md). Lives in `JamaalCore/Sources/JamaalCore/RulesEngine/`, no UI imports.

## Decisions resolved here

- **Capacity** is an enum: `low` / `medium` / `high` (not numeric).
- **Night Planning's Reflect step** captures both a numeric mood (1–5) and an optional free-text note.
- **Overdue tasks** get flagged after a threshold, not left to roll forward indefinitely.
- **Night Planning triggers via a fixed evening notification** (in addition to being user-openable any time) — this makes module 6 a hard dependency of module 4, not just a nice-to-have.

Two new supporting models fall out of these decisions (not primitives — engine-state, so documented here rather than in `docs/schema/`):

### `DailyCapacity`

The capacity-of-record for a given day. Written by Night Planning (module 4) for tomorrow, and directly editable on the Today List if the user adjusts it mid-day (per `today-list.md`).

| Field   | Type     | Default   | Notes                              |
| ------- | -------- | --------- | ------------------------------------ |
| `id`    | `UUID`   | `UUID()`  |                                       |
| `date`  | `Date`   | `.now`    | Day granularity (time component ignored/normalized to midnight). |
| `value` | `String` | `"medium"`| One of `low` / `medium` / `high`.     |

### `NightPlanningSession`

Persists wizard progress so closing the app mid-flow resumes correctly (CLAUDE.md calls this out explicitly as a state machine).

| Field            | Type      | Default    | Notes                                                                 |
| ---------------- | --------- | ---------- | ------------------------------------------------------------------------ |
| `id`             | `UUID`    | `UUID()`   |                                                                            |
| `forDate`        | `Date`    | `.now`     | The day being planned *for* (i.e. tomorrow, at the time the session starts). |
| `currentStep`    | `String`  | `"review"` | One of `review` / `reflect` / `capacity` / `plan` / `confirm`.             |
| `reflectionMood` | `Int?`    | `nil`      | 1–5.                                                                       |
| `reflectionNote` | `String?` | `nil`      |                                                                            |
| `isComplete`     | `Bool`    | `false`    |                                                                            |
| `createdAt`      | `Date`    | `.now`     |                                                                            |
| `completedAt`    | `Date?`   | `nil`      |                                                                            |

On step 5 (Confirm), the session upserts a `DailyCapacity` row for `forDate` from whatever was set in step 3 — capacity-of-record lives in `DailyCapacity`, not duplicated permanently on the session.

## Modules

### 1. Task scheduling (due dates, rollover)

- **Input**: current date, all incomplete `Task`s with a `dueDate`.
- **Behavior**: increments `rolloverCount` once per day a dated task remains incomplete past its `dueDate`. Once `rolloverCount >= 3`, the task is considered **stale** — surfaced differently on the Today List (exact treatment is a UI concern, not this module's). Staleness is *derived* from `rolloverCount` at read time, not a separate stored flag.
- **Output**: updated `rolloverCount`.

### 2. Habit streak tracking

- **Input**: `HabitTimeWindow` completion events, current date.
- **Behavior**: on completion within a window's active period, increments that window's `currentStreak` and updates `lastCompletedDate`; updates `longestStreak` if exceeded. If a window's day passes with no completion, `currentStreak` resets to 0. Per-window, not per-habit (confirmed in schema review).
- **Output**: updated `currentStreak` / `longestStreak` / `lastCompletedDate` on the relevant `HabitTimeWindow`.

### 3. Anchor generation (window-bound instances, attendance)

- **Input**: all enabled `AnchorRule`s, a generation horizon (e.g. today + tomorrow).
- **Behavior**: decodes each rule's `configData` per `sourceKey` and generates concrete `Anchor` instances with `windowStart`/`windowEnd`/`title` set, linked back via `rule`. Proposed `configData` shapes (still placeholders — first pass, not locked):
  - `prayerWindow`: `{ "calculationMethod": "ISNA", "latitude": 0.0, "longitude": 0.0, "prayers": ["fajr","dhuhr","asr","maghrib","isha"] }`
  - `schoolRun`: `{ "weekdays": [1,2,3,4,5], "time": "08:15", "label": "dropoff" }`
  - `binNight`: `{ "weekdays": [3], "time": "19:00" }` (or `"intervalDays"` for a fortnightly rotation)
  - `plantWatering`: `{ "intervalDays": 3, "time": "09:00" }`
  - `custom`: unstructured for now — deliberately left underspecified until a real custom-anchor use case shows up.
- **Output**: new `Anchor` rows, `attendanceStatus` defaulted to `pending`.

### 4. Night Planning orchestration (5-step wizard state machine)

- **Input**: today's completed/missed Tasks, Habit windows, Anchor attendance (for step 1); user input at each step.
- **Behavior**: drives `NightPlanningSession` through `review → reflect → capacity → plan → confirm`, persisting after each step so the app can resume mid-flow. On `confirm`, upserts `DailyCapacity` for `forDate` and hands off to module 6 to schedule tomorrow's notifications for confirmed items.
- **Depends on module 6**: since the trigger is a fixed evening notification, module 6 must be able to schedule that recurring local notification — this module can't ship notification-triggered without it.
- **Output**: a completed `NightPlanningSession`, a `DailyCapacity` row for tomorrow.

### 5. Wellbeing scoring ("gathering data" → active score)

- **Input**: `NightPlanningSession.reflectionMood` over recent days.
- **Behavior**: purely computed/derived — no new persisted model. Shows a "gathering data" placeholder state until at least 7 days of `reflectionMood` values exist; after that, computes a rolling average (window size TBD — 7 or 14 days) as the active score.
- **Output**: a computed score (or the gathering-data state), consumed by the Today List's wellbeing sparkline.

### 6. Notification/nudge logic (streak-protection, during-day guidance)

- **Input**: `HabitTimeWindow` streaks at risk (window closing soon, not yet completed), upcoming `Anchor` windows, the fixed evening Night Planning time.
- **Behavior**: schedules local notifications (`UNUserNotificationCenter`) for: the evening Night Planning prompt, streak-protection nudges as a window's end approaches, and during-day guidance for upcoming Anchors. Requires notification permission — **resolves onboarding's open question**: permission is requested during onboarding (alongside baseline capacity), framed around Night Planning's evening reminder, rather than deferred to first use.
- **Output**: scheduled local notifications; no new persisted model beyond what's needed to know what to schedule (derived from existing `HabitTimeWindow` / `Anchor` / `DailyCapacity` state).

## Open questions

- **Rollover threshold (3 days)** and **wellbeing rolling window (7 vs. 14 days)** are proposed defaults, not confirmed — easy to tune later since they're just constants, not schema.
- **`AnchorRule.configData` shapes above** are a first pass — worth revisiting once the generated-vs-user-created Anchor positioning (flagged in `anchor.md`) is settled, since that could change what configuration even needs to be captured.
- **Notification scheduling limits**: iOS caps pending local notifications (64 at a time) — worth confirming the nudge/reminder volume stays well under that as this module gets built out.
