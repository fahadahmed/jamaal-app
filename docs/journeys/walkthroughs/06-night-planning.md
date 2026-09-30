# Journey 6 — Night Planning

> **Status: done — gaps G-45 … G-53 raised, decided and applied** (see the [gap log](overview#gap-log)). The text below is the walkthrough as first written, with the proposals it raised. Register flow **F09**, screens **NP-01 … NP-07**, plus **TD-07**. Behaviour is in [Night Planning](../night-planning) and [Rules engine → module 4](../../architecture/rules-engine); this page tests it against the schema and engine, and against everything the first five journeys decided.

**In one line:** in the evening the user looks back at the day, settles what is unfinished, sees the shape of tomorrow, builds it around what is fixed, checks the load, and closes the day — or skips it without penalty.

**Preconditions:** Journeys 1–5 done. Example: it is 20:05 on a weekday; today had three tasks done and two left, a counted habit at 2 of 3, prayers attended; tomorrow has a school run at 08:15, a dentist appointment at 15:00 and the usual prayers.

---

## Entry

- **Sees:** the evening notification at `UserSettings.planningMinute` (on devices whose *Send reminders* switch is on), or the in-app banner (notifications denied), or an entry on Today.
- **Reads:** `planningTarget(at: now, dayStartMinute:)` → `forDate` (the first date whose working-day start is still in the future) and `reviewDate` (`forDate − 1`).
- **Writes:** a `NightPlanningSession` (`forDate`, `currentStep = review`) — or resumes the existing one for that `forDate`.
- **Assumes:**
  - the user can *start* it from Today — **✗ G-45** (the docs say "entry to Night Planning", but `TD-01` lists no such element);
  - the same date can be planned twice — **✗ G-46** (what happens if a plan for `forDate` is already closed, or was skipped, and the user comes back?);
  - tonight's prompt doesn't fire after they've already planned — **✗ G-52**.

## NP-01 Review today

- **Sees:** the day in plain counts (*"3 done · 2 left · 6/7 habits"*); the done items; habit windows complete, partial (*"Water 2 of 3"*) or missed; Anchor outcomes; **time spent against estimates**. *(The optional mood line first drafted here was removed in Journey 8.)*
- **Reads:** tasks completed on `reviewDate` and live tasks due on or before it; `HabitEntry`s for that date; Anchors whose `occurrenceDate` is that date; sessions whose `day` is that date.
- **Writes:** `currentStep`.
- **Assumes:**
  - the review reads the day *so far*: an Anchor still open at 20:05 (Isha) shows as open, not missed — ✓ (window state is derived; it resolves later);
  - a day with no data reads gently — ✓ (first day, or days the app wasn't opened: minimal, no blame).

## NP-02 Carry forward

- **Sees:** each still-incomplete task with **Keep · Later · Drop**; from a 3rd deferral the reason chips and the easing message (*"This one keeps slipping…"*). Skipped when nothing is incomplete.
- **Writes:** **Keep** → `dueDate = forDate`; **Later** → the chosen date or `nil` (Someday, low only); **Drop** → `droppedAt`; each applies immediately and is undoable until the day is closed. Deferral bookkeeping (`deferralCount`, `DeferralRecord`, the easing of `medium`/`high`) follows [the deferral rules](../../schema/task#deferral-behaviour).
- **Assumes:**
  - these moves are deferrals — ✓ (the task's due day has arrived);
  - a repeating task behaves — ✓ (Keep moves this instance; Drop skips only this occurrence and the next is created);
  - planning after a midnight rollover doesn't double-count — ✓ (at most one deferral per task per logical day; the user's choice refines the automatic record).

## NP-03 Build tomorrow

- **Sees:** it **opens on the shape of tomorrow**: the working day, its fixed commitments drawn in (the school run, the dentist, the prayers), and the **named gaps** between them with their sizes (*"before the school run · 2h 40m free"*) — a list on compact, a proportional timeline on regular width. Below, tomorrow's **tasks** and **habits**, suggestions (important-but-not-urgent tasks, backlog candidates), flags on any task longer than the longest gap, and **Add** (a task, or a one-off Anchor).
- **Reads:** Anchors for `forDate` (generated, plus one-offs) and their placement; due habits for that weekday; tasks due `forDate`; the engine's free-block calculation.
- **Writes:** pulling a task in sets `dueDate = forDate`; raising importance (with its required date); a new task or one-off Anchor defaulting to `forDate`; a task pushed out of tomorrow gets a new date.
- **Assumes:**
  - habits are something you select — **✗ G-47** (habits are *scheduled*, not chosen; and "reorder" contradicts the decision that Today has no manual ordering);
  - pushing a task out of tomorrow is a deferral — **✗ G-48** (it hasn't reached its due day, so counting it would punish planning and push tasks toward "stale");
  - the gaps read well — **✗ G-49** (tiny gaps, and a day that begins or ends with a commitment, have no naming rule);
  - tomorrow's Anchors exist — ✓ (generation covers today and tomorrow; one-offs are stored when created).

## NP-04 Check the load

- **Sees:** tomorrow's level slider **pre-selected to that weekday's default**; the **suggested level** from free time; **budget used** (*"2h 15m of 3h"*); any **overflow** past the day's end (*"40 min past 19:00"*); and one specific suggestion (*"Groceries could wait until Wednesday. Want me to move it?"* — **Move** / **Keep as planned**). A quiet line may offer to update the normal day from real use.
- **Reads:** the plan's task minutes (module 7), free minutes and longest gap, `UserSettings`, the normal-day suggestion.
- **Writes:** the chosen level into `DayPlan(forDate).capacity`; a **Move** re-dates the suggested task.
- **Assumes:**
  - the chosen level survives leaving the app mid-flow — **✗ G-51** (`NightPlanningSession` has no capacity field, so it would reset to the default on resume);
  - "move it to Wednesday" is computable — **✗ G-50** (which task, and which day, isn't defined);
  - the move isn't a deferral — **✗ G-48**.

## NP-05 Close the day

- **Sees:** *"Tomorrow is ready. Three tasks, 3h exactly. Put the phone down."*, a plain count of nights planned (*"12 nights planned"*), and **Good night**.
- **Writes:** `DayPlan(forDate)` — `plannedTaskMinutes`, `freeMinutes`, `committedMinutes`, `loadScore`, `wasOverloaded`, `planningCompletedAt`; `NightPlanningSession.isComplete`, `completedAt`; the notification planner re-plans tomorrow's reminders.
- **Assumes:** the count is derived — ✓ (completed sessions, one per date); the snapshot can be rewritten — ✓ (an upsert by date).

## NP-06 Skip tonight, and TD-07 the morning card

- **Skip tonight** (any step): `NightPlanningSession.skippedAt`; no `DayPlan` is written; moves already made stay. Nothing is lost — incomplete dated tasks auto-defer at rollover, as usual.
- **Next morning**, if no plan was confirmed for today: one quiet card — *"No plan for today — two minutes to pick?"* — shown once (logged in `NudgeLog`).
- **Assumes:** the morning card opens *something* — **✗ G-53** (the docs say "a shortened Build tomorrow for today", but which steps remain, and which session it uses, isn't spelled out).

## NP-07 The wide canvas

- **Sees:** the same five steps as one canvas with a step rail, the timeline in the working area.
- **Assumes:** nothing differs in data — ✓ (same session, same writes).

---

## What the user sees afterwards

Tomorrow's Today opens already shaped: the school run and dentist as fixed rows, the day's tasks in the engine's order, the meter at *"2h 15m of 3h"*, and no planning card. The next morning there is nothing to do but live it. Had they skipped, Today would carry one quiet card and the leftovers would already have been handled at rollover.

## Data that exists afterwards (end-state check)

| Model | Change |
|---|---|
| `NightPlanningSession` | + 1 for `forDate`: `isComplete` / `skippedAt`, `completedAt` |
| `DayPlan` | `forDate`: `capacity` (as soon as chosen), then the planning snapshot and `planningCompletedAt` on close |
| `Task` | re-dated by Keep, Later, Move or pulling in; `droppedAt` by Drop; importance raised |
| `DeferralRecord` | + 1 per **real** deferral only (a task moved after its due day arrived) |
| `Anchor` | + one-offs added during planning |
| `NudgeLog` | + 1 when the morning card is shown |

No new fields are needed; the gaps are rules, UI and definitions.

## Rules and changes this journey implies

If the proposals are accepted:

1. **Entry on Today (G-45):** a **Plan tomorrow** action in Today's toolbar (visible after *Add*), a quiet row after the planning time if tonight isn't planned or skipped, and the action on the all-done state. The banner remains if notifications are denied.
2. **Re-opening (G-46):** opening Night Planning for a `forDate` that already has a session resumes that session — a closed one at **Build** (so the user can adjust), a skipped one clears `skippedAt` and starts at Review. Re-closing upserts `DayPlan` again.
3. **Build is not a chooser of habits or an orderer (G-47):** tomorrow's due habits are shown **read-only** (their minutes count in free time); tasks have no manual reorder. The night-planning doc's "select, reorder and add Tasks and Habits" is corrected to: *pull in and push out tasks, add tasks and one-off Anchors, see habits*.
4. **What counts as a deferral (G-48):** a deferral is a task moved to a later day **when its current due day has already arrived** (its `dueDate` is on or before the logical date). Moving a task that is due later (pushing tomorrow's task to Thursday, or the overload **Move**) is **rescheduling**, not a deferral: no count, no `DeferralRecord`, no easing. The 1st/2nd instant and 3rd-picker rules apply only to real deferrals.
5. **Gap naming (G-49):** gaps under **20 minutes** aren't shown (they still count as free time); a day that **begins** with a commitment has no "before" gap, and one that **ends** with a commitment has no "after" gap; names use the composed Anchor titles; the free-time figure shown is the sum of the gaps the day has, the longest gap is the one used for fit checks.
6. **The overload suggestion (G-50):** the engine suggests moving the **lowest-ordered movable task** (bottom of the engine's order, not `doFirst`) to the **nearest of the next seven days whose load would stay under 100%**; if none, it asks the user for a date. It is a rescheduling (G-48).
7. **Chosen level is written immediately (G-51):** picking a level in step 4 upserts `DayPlan(forDate).capacity` straight away; Close fills in the snapshot. Today's slider already works this way.
8. **The prompt stops (G-52):** the planner cancels tonight's planning notification once that night's session is closed or skipped, and never repeats it (nothing nags); the banner on Today remains until planned or skipped.
9. **Morning flow (G-53):** the morning card opens a **shortened flow for today** — a session with `forDate = today`, starting at **Build**, then **Load**, then **Close** (Review and Carry are skipped: the day's leftovers were already settled at rollover).
