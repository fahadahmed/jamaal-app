# Journey 7 — Capacity and day settings

> **Status: walked; gaps G-54 … G-57 raised, proposals waiting for a decision** (see the [gap log](overview#gap-log)). Register flow **F10**; screens **ST-02** (Capacity & day), the capacity slider and meter on **TD-01**, and the normal-day suggestion. Behaviour is in [Rules engine → module 7](../../architecture/rules-engine) and `UserSettings`; this page tests the screens that hold these numbers against how changing each one ripples through data that already exists.

**In one line:** the user tells Jamaal how much a normal day is, when their working day starts and ends, what each weekday is like, and — day by day — how much they have in them today; and the numbers behave sensibly when they change.

**Preconditions:** Journeys 1–6 done. `UserSettings` holds `mediumDayMinutes` (180), `dayStartMinute` (08:00), `dayEndMinute` (19:00), `rolloverMinute` (00:00), `weekdayLevels` (weekends `low`), `planningMinute`, `morningMinute`. Some `DayPlan`s and tasks already exist.

---

## The slider and meter on Today (TD-01)

- **Sees:** a **low · medium · high** control for *today*, each level labelled with its minutes (*"Low · 2h"*, *"Medium · 3h"*, *"High · 4h"*), and the **meter** under it (*"2h 15m of 3h"*, a quiet load state, terracotta if overloaded or past the day's end).
- **Reads:** today's level (`DayPlan(today).capacity`, else the weekday default), the budget for that level, today's task minutes (module 7), free minutes and the longest gap.
- **Does:** moves the slider.
- **Writes:** an upsert of `DayPlan(today).capacity`.
- **Effects:** the budget and the meter change at once; the set of items under **Also today** changes with the level (*low*: Anchors, `doFirst` tasks and closing habits stay; *medium*: all but `letGo`; *high*: everything); a full day prompts *"Day is full — put it on tomorrow?"* only when something is added.
- **Assumes:**
  - the level labels are whole, friendly numbers — **✗ G-56** (`low` is ⅔ and `high` is 4⁄3 of the normal day, so a 3h25m normal day would read *"Low · 2h 17m"*);
  - a level exists on a day nobody touched — ✓ (falls back to the weekday default);
  - *Overloaded* offers something to do — ✓ (the same suggestion as Night Planning: the lowest-ordered movable task to tomorrow; on **Today** that task's due day has arrived, so moving it *is* a deferral and follows the normal deferral rules).

## ST-02 Capacity & day

- **Sees:**
  1. **Your normal day** — a slider from 30 minutes to 6 hours in 15-minute steps (default 3 h), with the derived Low and High shown beneath it; a quiet **suggestion line** when the engine has one (*"You usually do about 2h 40m — set your normal day to that?"* — *Set it* · *Not now*).
  2. **Each weekday's default level** — seven rows, *low · medium · high* (weekends start at *low*).
  3. **Your working day** — a start (default 08:00) and an end (default 19:00).
  4. **Advanced → the day rolls over at** — 00:00 by default, offered from 00:00 to 06:00.
- **Reads:** `UserSettings`; the suggestion from the last 28 days of `DayPlan.completedEffortMinutes`.
- **Writes:** `UserSettings.mediumDayMinutes`, `weekdayLevels`, `dayStartMinute`, `dayEndMinute`, `rolloverMinute`; a `NudgeLog` (`normalDaySuggestion`) when a suggestion is shown or dismissed.
- **Validation:** `rolloverMinute < dayStartMinute < dayEndMinute`, with at least two hours between start and end; the pickers can't produce anything else.
- **Assumes:**
  - changing the normal day mid-day is harmless — ✓ (Today recomputes live; the frozen snapshots on past `DayPlan`s stay as they were, which is right for history);
  - the working day's start and end can change any time — ✓ (live recomputation);
  - the rollover can change any time — **✗ G-54** (moving it at 01:30 from midnight to 03:00 would flip "today" back to yesterday: things logged since midnight carry the new date while the logical date is the old one);
  - the suggestion has data to work from — **✗ G-55** (it reads `DayPlan.completedEffortMinutes`, but a `DayPlan` exists only for days that were planned or had the slider moved, so days the user skipped planning leave no record);
  - the settings agree with each other across the app — **✗ G-57** (nothing relates the planning prompt time to the end of the working day).

## Where the settings are read

| Setting | Read by |
|---|---|
| `mediumDayMinutes` | the budget for every level: meter, *Day is full*, Night Planning's load step, overload suggestions |
| `weekdayLevels` | the level on any day with no `DayPlan`; the level Night Planning pre-selects |
| `dayStartMinute` / `dayEndMinute` | free time, the gaps in *Build tomorrow*, overflow past the day's end, Night Planning's target date |
| `rolloverMinute` | the logical date everywhere: Today, logs, sessions, Anchor attribution, auto-deferral |

## What the user sees afterwards

Raising the normal day to 3h30 turns *"2h 15m of 3h"* into *"2h 15m of 3h 30m"* at once, and a day that read as full now reads as balanced; yesterday's record, frozen at the time, still says what it said. Setting Sunday's default to *medium* changes nothing on past Sundays and makes the next untouched Sunday start at *medium*. Moving the end of the working day from 19:00 to 18:00 pulls overflow and gaps in by an hour.

## Data that exists afterwards (end-state check)

| Model | Change |
|---|---|
| `UserSettings` | the single row is edited (synced to every device) |
| `DayPlan` | today's `capacity` when the slider moves; new rows for used days (G-55) |
| `NudgeLog` | + 1 per normal-day suggestion shown, + `dismissedAt` when declined |

No new fields are needed; the gaps are rules and one UI behaviour.

## Rules and changes this journey implies

If the proposals are accepted:

1. **Rollover changes are safe by construction (G-54):** the *day rolls over at* control can be changed only when the current time of day is **after both the old and the new rollover** (so both values give the same logical date right now); otherwise the control is disabled with *"Available after 03:00"*. The new value then applies from the next boundary. The working-day start, end and every other setting can change at any time.
2. **A `DayPlan` for every day that was used (G-55):** the day-rollover step **creates `DayPlan(D)` if it is missing**, for any ended day with activity (a completed task, a session, a decided Anchor, a habit entry, or a Night Planning session), then finalises it. Days with no activity get none. This gives wellbeing, the normal-day suggestion and the review a record for every day that mattered.
3. **Friendly budgets (G-56):** the derived Low and High are **rounded to the nearest 5 minutes**, for display *and* for the calculation, so the number shown is the number used (a 3h25m normal day gives Low 2h15m and High 4h35m).
4. **A gentle relation between times (G-57):** if the evening planning time is **earlier than the end of the working day**, Settings shows a quiet note (*"You'll be asked to plan at 18:30, before your day ends at 19:00"*); nothing is blocked, because some people do plan before finishing.
