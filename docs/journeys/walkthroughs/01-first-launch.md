# Journey 1 — First launch and onboarding

> **Status: walked; gaps G-01 … G-10 raised** (see the [gap log](overview#gap-log)). Register flow **F01**, screens **OB-01 → OB-09 → TD-01**. The behaviour is in [Onboarding](../onboarding); this page tests it against the schema.

**In one line:** a new user meets Jamaal, tells it what a normal day looks like, agrees when it may speak, creates one real Task, Habit and Anchor, and lands on a Today that is not empty.

**Preconditions:** a fresh install, possibly on an account that already has data on another device (G-01). Notifications not yet asked for.

**Side effects at first launch (before any screen):** the engine seeds one `UserSettings` row (defaults: 180-minute normal day, 08:00–19:00 working day, midnight rollover, weekends `low`) and the three default `TaskCategory` rows (`personal`, `family`, `work`; keyed by `presetKey` so a second device's duplicates are merged). `firstLaunchAt` is set once.

---

## OB-01 Meet Jamaal

- **Sees:** the companion's greeting and the tagline. *"Hello. I'm Jamaal. One list, just for today. I'll help you choose what belongs on it — and notice when it's too much."* One filled button (**Begin**).
- **Does:** taps Begin.
- **Writes:** `UserSettings.firstLaunchAt` (if `nil`) — the trial start fallback.
- **Assumes:**
  - first launch is detectable — **✗ G-01** (per-device flag re-runs onboarding on a second device);
  - trial start survives reinstall — ✓ (`firstLaunchAt` synced; StoreKit's original-download date is the primary source).

## OB-02 The idea

- **Sees:** *"One list. Just today."* What Jamaal is not (*Projects and boards · Streaks and guilt*) and what it is (*One day at a time · Planned the night before · Kept in your own iCloud*). Continue.
- **Reads/writes:** nothing.
- **Copy to respect:** Design's current copy says "Tags, labels, filters" and "Everything stays on device", both of which contradict how the app works (categories exist; sync is through iCloud) — see the [Claude Design brief](../../design/claude-design-brief) §3.

## OB-03 iCloud check

- **Sees:** nothing when iCloud is fine (the step is skipped). A plain explanation if not: signed out, restricted, or offline — *"Jamaal works without iCloud; your data just won't sync until you sign in."* One button to continue.
- **Reads:** the iCloud account status; whether an existing account's data has synced (a `UserSettings` row with `onboardingCompletedAt`).
- **Does:** continues, or (returning account) taps through **Welcome back** and skips to Today.
- **Assumes:**
  - we can tell iCloud is available — **✗ G-06** (the container identifier is missing, and CloudKit can't be provisioned on a free Personal Team);
  - a second device doesn't re-onboard — **✗ G-01**.

## OB-04 Your normal day

- **Sees:** *"How much is a normal day?"* — focused work outside meetings and life admin; a slider from 30 minutes to 6 hours, default 3 hours. *"When does your working day usually end?"* — default 19:00. The low / medium / high slider for **today**, with *"Weekends get less by default. You can change any day later."*
- **Does:** sets the three values.
- **Writes:** `UserSettings.mediumDayMinutes`, `UserSettings.dayEndMinute`; an upsert of today's `DayPlan` with only `capacity` set (all planning fields keep their defaults).
- **Assumes:**
  - a `DayPlan` can exist with only a capacity — ✓ (every field is defaulted; `planningCompletedAt` is `nil`);
  - today's level doesn't overwrite the weekday defaults — ✓ (`weekdayLevels` is separate);
  - the day's end and start can't contradict — **✗ G-07** (no validation rule).
- **Copy to respect:** Design's line *"I'll learn the real number"* promises silent learning. The app only **suggests** a number from real use later, never changes it itself. Suggested: *"A rough guess is fine. I can suggest a better number once I've seen a few weeks."*

## OB-05 Reminders and evening time

- **Sees:** *"Once at night to plan, once in the morning with your list. Anything else is yours to switch on."* The evening planning time (default 20:00) and the morning list time (default 08:00). **Allow notifications** and **Not now**.
- **Does:** picks times; taps Allow (the system prompt appears) or Not now.
- **Writes:** the times and the permission outcome — **✗ G-02** (today these are per-device preferences, so a second device starts from defaults and every device notifies). Schedules the evening planning notification.
- **Assumes:**
  - denying is safe — ✓ (the in-app banner at planning time, `SY-01`, takes over);
  - the planning time is sensible relative to the day's end — ✓ (independent; defaults are 19:00 and 20:00).

## OB-06 Your first task

- **Sees:** *"Something you need to do today."* A title field and the three default categories as chips (pre-selecting none), effort chips (optional). Continue.
- **Does:** types a title; optionally picks a category and an effort.
- **Writes:** a `Task` with `importance = low`, **`dueDate = today`**, optional `category` and `effortMinutes`.
- **Assumes:**
  - the categories exist already — ✓ (seeded at first launch; duplicates on a second device merge by `presetKey`);
  - the task will appear on Today — **✗ G-03** (as worded in the current doc, "this week" isn't due today, and a dateless task is backlog);
  - the category chips look right — **✗ G-08** (`colorKey` values aren't defined).

## OB-07 Your first habit

- **Sees:** a short list of presets — **Qur'an reading**, **Dhikr**, **Exercise**, **Running** — and **Something else**. Choosing one shows its cadence and target in one editable line. Continue.
- **Does:** picks a preset and optionally edits its target.
- **Writes:** a `Habit` (`kind`, `presetKey`, schedule), one `HabitTimeWindow` (`target`, optional `effortMinutes`, optional reminder), nothing in `HabitEntry` yet.
- **Assumes:**
  - presets are defined — **✗ G-04** (no catalogue); proposal below;
  - "Something else" is cheap — **✗ G-10** (the full type picker is too heavy here; proposal: a binary daily habit with just a title).
- **Preset catalogue (proposal for G-04).** Bundled app data; all use one all-day window; all editable afterwards.

  | Preset (`presetKey`) | `kind` | `target` | Schedule | `effortMinutes` |
  |---|---|---|---|---|
  | Qur'an reading (`quran`) | `timed` | 15 min | daily | 15 |
  | Dhikr (`dhikr`) | `counted` | 33 | daily | — |
  | Exercise (`exercise`) | `timed` | 30 min | 3 times a week | 30 |
  | Running (`running`) | `timed` | 30 min | 3 times a week | 30 |
  | Something else | `binary` | 1 | daily | — |

  The Qur'an and dhikr values are starting suggestions, since you know these practices better than I do.

## OB-08 Your first Anchor

- **Sees:** *"Things your life moves around."* The types — **Prayer times · School run · Bin night · Plant watering · Custom** — and **Not now**. Choosing one opens its short form (prayer: location, method, prayers, Isha end; scheduled: days, a named slot, duration).
- **Does:** picks a type and fills the form, or skips.
- **Writes:** an `AnchorRule` (`sourceKey`, `configData`, `effortMinutes`, `placement`); the engine immediately generates `Anchor` instances for today and tomorrow.
- **Assumes:**
  - generation needs only the rule — ✓ (module 3);
  - creating a rule at, say, 21:00 is harmless — **✗ G-05** (today's earlier prayer windows would be generated already closed and finalised as *missed* on day one);
  - prayer times can be computed — **✗ G-09** (no library chosen);
  - location and city search are available — ✓ (coarse location prompt only at this point; city search fallback).
  - Not now is fine — ✓ (Today's Anchors section explains what Anchors are and offers to add one).

## OB-09 Ready

- **Sees:** *"Let's plan tonight. At 20:00 I'll ask how today went and we'll set up tomorrow together."* A line about the trial (*14 days, everything included*). **Open my day**.
- **Writes:** `UserSettings.onboardingCompletedAt` (**G-01**); schedules tomorrow's notifications via module 6.
- **Assumes:** the "Tonight, we'll plan tomorrow" card needs no storage — ✓ (derived: shown while `onboardingCompletedAt` is on today's logical date and no Night Planning session exists yet).

---

## What Today shows afterwards (TD-01, day 0)

- **Capacity slider** at the level chosen; the **meter** reads *"0m of 3h"* (the first task has no effort unless one was picked, and the engine counts items without a duration as zero).
- **Anchors**: the rest of today's prayer windows as a grouped row (for example *"Salah 0/3 · Asr · until 17:58"*), because generation skips windows already closed (**G-05**), with their window bars.
- **Habits**: the chosen habit (for Qur'an reading, *"0 of 15 min · Begin"*).
- **Tasks**: the first task, with its category label.
- A quiet card: *"Tonight, we'll plan tomorrow."* No companion guidance yet, no wellbeing score (*"gathering data"*).

## Data that exists afterwards (end-state check)

| Model | Rows |
|---|---|
| `UserSettings` | 1 (normal day, day end, `onboardingCompletedAt`, `firstLaunchAt`) |
| `TaskCategory` | 3 (seeded) |
| `DayPlan` | 1 — today, capacity only |
| `Task` | 1 — low importance, due today |
| `Habit` / `HabitTimeWindow` | 1 / 1 |
| `AnchorRule` / `Anchor` | 0–1 / the remaining windows today and tomorrow's |
| Everything else (`DeferralRecord`, `WorkSession`, `HabitEntry`, `NightPlanningSession`, `NudgeLog`) | 0 |

Every row above is storable with the current schema, **except the synced fields the gaps add** (`onboardingCompletedAt`; `planningMinute` and `morningMinute` if G-02 is accepted).

## Schema and engine changes this journey implies

If the proposals are accepted:

1. `UserSettings.onboardingCompletedAt: Date?` (G-01).
2. `UserSettings.planningMinute: Int = 1200` and `morningMinute: Int = 480`, plus a per-device local "send reminders here" switch (G-02).
3. Engine rule: an Anchor is never generated for a window that ended before the rule's `createdAt` (G-05).
4. A bundled **preset catalogue** (G-04).
5. A documented settings validation: `rolloverMinute < dayStartMinute < dayEndMinute`, with at least two hours between start and end (G-07).
6. Wording fixes for OB-01 to OB-05 and the onboarding doc (first task "today"; "I can suggest…"; the three copy conflicts).

Two items are not schema questions and need a decision outside it: **G-06** (when to enrol in the paid developer programme) and the library choice **G-09**.
