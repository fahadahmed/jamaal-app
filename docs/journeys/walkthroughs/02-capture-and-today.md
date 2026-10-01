# Journey 2 — Capture a task, and living in Today

> **Status: done — gaps G-11 … G-20 raised, decided and applied** (see the [gap log](overview#gap-log)). The text below is the walkthrough as first written, with the proposals it raised. Register flows **F03** (capture) and **F04** (complete, defer, drop), on **TD-01 Today**. Behaviour is in [Today](../today-list) and [Task](../../schema/task); this page tests it against the schema and engine.

**In one line:** the user adds a task in a couple of taps, sees where it lands on Today, and through the day ticks things off, opens one, defers or drops it, and watches the capacity meter respond.

**Preconditions:** Journey 1 is done: a `UserSettings` row, the three default `TaskCategory` rows, today's `DayPlan` (capacity only), and a few items on Today. Examples below continue that day (normal day 3 h, working day ends 19:00, level *medium*).

---

## Part A — Capture (F03)

### TD-04 → the Add sheet (chooser removed)

- **Sees:** tapping **Add** on Today opens the add sheet already on **Task**, with a small **Task | Anchor** switch at the top. (An earlier draft put a separate chooser screen first; **G-17** removes it: a task is the overwhelming case, so capture costs one tap, not two.)
- **Does:** types a title, or switches to *Anchor* to reach `AN-08`.
- **Assumes:** one-offs belong to the same entry point — ✓ (the Add button is the only creation entry on Today; `NP-03` offers the same Anchor action).

### TK-01 Add task

- **Sees:** a title field; **effort** chips (15m · 30m · 1h · 2h+) with *30m* preselected (**G-12**) and an *Other…* option (**G-11**); **importance** (low · medium · high, *low* selected); **category** chips (optional); **schedule** — Today (selected) · Tomorrow · Later this week · Next week · Someday · a date; a **repeat** row (Never); an optional **note**; one filled button, **Add to today**.
- **Does:** types "Call the clinic back", leaves the defaults, taps Add.
- **Writes:** a `TaskItem` — `title`, `effortMinutes`, `importance`, `dueDate`, optional `category`, `notes`, and for a repeat `repeatKind` / `repeatWeekdays` / `seriesID`; `createdAt`.
- **Reads:** today's load (module 7), to decide whether to show *"Day is full · offer tomorrow"*.
- **States and rules:**
  - **Medium or high importance** → the date row becomes required (pre-filled with the day being planned, not clearable) and **Someday is hidden**.
  - **Repeat chosen** → a date is required and Someday is hidden; the weekday defaults to the date's weekday (`repeatWeekdays` empty = same weekday as `dueDate`).
  - **Day is full** → an inline line above the button: *"Day is full — put it on tomorrow?"* with *Tomorrow* and *Add anyway*. Never blocks.
  - **No importance change and no date** (Someday) → a backlog task.
- **Assumes:**
  - effort can express any task — **✗ G-11** ("2h+" stores what? a 3-hour task can't be said);
  - most tasks will carry an effort, so load and "Day is full" work — **✗ G-12** (missing estimates count as zero, so the warnings silently never fire for unestimated tasks);
  - which tasks count toward "today's load" is defined — **✗ G-13** (module 7 says "tasks planned for the day", not which ones, while the day is under way);
  - quick dates are deterministic — **✗ G-16** ("Later this week" / "Next week" have no rule);
  - importance is three levels — **✗ G-20** (Design draws "Matters 4 of 5", a 1–5 scale).
- **Copy to respect:** *"Day is full — put it on tomorrow?"* (no blame); the importance control is labelled for people ("How much does this matter?"), not "priority" or "Eisenhower".

### TK-05 Repeat picker

- **Sees:** Never · Daily · Weekly (day chips, defaulting to the due date's weekday) · Monthly (same day of the month, clamped to month end).
- **Writes:** `repeatKind`, `repeatWeekdays`.
- **Assumes:** a repeating task needs only those fields — ✓ (`seriesID` is assigned on creation; one live instance per series).

### TK-06 Category picker

- **Sees:** the three default categories (and any the user added) as chips, plus *None*. A category is a small coloured label.
- **Writes:** `TaskItem.category`.
- **Assumes:** categories are always available — ✓ (seeded); chip colours exist — **✗ G-08** (closed in Journey 11, G-84).

### TK-04 Note editor

- **Sees:** a short markdown field (checklists, bold, italic, links, inline code); no headings, tables or images.
- **Writes:** `TaskItem.notes`.
- **Assumes:** ticking a checklist item is just an edit of the note text — ✓ (last writer wins per record, which is fine for one person).

---

## Part B — Living in Today (F04)

### TD-01 Today

- **Sees (top to bottom):** the capacity slider and **meter** (*"2h 15m of 3h"* and a quiet load state); a companion card (at most one a day); **Anchors**; **Habits**; **Tasks** (each row: title, meta such as *"Slipped twice"* or *"Start here · 60 min"*, category label); **Also today** (collapsed, with a count); **Add**.
- **Reads:** the ordered task list (module 1: quadrant, then due date, `low` after medium/high); today's load and free time (module 7); which items the current level hides; the guidance pick (module 6, logged in `NudgeLog`).
- **Does:** ticks a check, taps a row, moves the capacity slider, filters by category, opens Add.
- **Writes:** *moving the slider* upserts today's `DayPlan.capacity`; *ticking* writes the task (below).
- **Assumes:**
  - the engine's order is good enough with no manual drag — **working hypothesis, ✗ G-18** (not yet validated; adding `TaskItem.sortOrder` later is additive);
  - the meter's "used" number is defined — **✗ G-13**;
  - hidden items are findable — ✓ (*Also today* with a count, never silently dropped);
  - the category filter needs no storage — ✓ (local UI state).

### Completing a task (the check)

- **Does:** taps the check.
- **Writes:** `TaskItem.isCompleted = true`, `completedAt`; the meter updates; quiet completion feedback. For a **repeating** task the engine creates the next instance (one live instance per series, dedup key `(seriesID, dueDate)`).
- **Undo:** tapping the check again un-completes it (`isCompleted = false`, `completedAt = nil`).
- **Assumes:** un-completing a repeating task is harmless — **✗ G-14** (the next instance already exists, so two live instances would appear).

### TK-02 Task detail

- **Sees:** title, the note as a tappable checklist, category, effort, importance, due date, deferral history (*"Deferred twice · 15 min"*), *Added 9 May*; actions **Begin**, **Mark done**, **Defer**, **Drop**, and **Stop repeating** for a repeating task.
- **Reads:** the task and its `DeferralRecord`s.
- **Does:** edits fields (autosaving), or takes an action.
- **Assumes:**
  - the detail never invents a state — ✓ (*Slipped twice* is `deferralCount`);
  - Drop is reversible enough — **✗ G-19** (Design draws **Delete**; we have a soft *Drop*, but with no History screen a dropped task can't be found again after the 5-second undo);
  - the importance control is three-level — **✗ G-20**.

### TK-03 Defer

- **Does:** taps **Defer**. The **1st and 2nd** deferral is instant: the task moves to tomorrow (toast). From the **3rd**, a sheet opens: *"This one keeps slipping. Pick a day that actually works."* with **Later this week · Next week · Someday · Pick a date**, and reason chips **Too much on · Not ready · Not relevant**. A `medium`/`high` task is first eased to `low` (with a plain message), which makes Someday available.
- **Writes:** `TaskItem.dueDate` (or `nil` for Someday), `deferralCount += 1`, a `DeferralRecord` (`day`, `deferredTo`, `reason`); `TaskItem.importance → low` when eased. A second deferral on the same logical day *refines* the existing record rather than adding one.
- **Assumes:**
  - a reason is always stored — **✗ G-15** (an instant deferral has no chip, yet `reason` has five values; which one?);
  - the quick dates resolve — **✗ G-16**;
  - easing happens exactly once — ✓ (on the 3rd deferral, only for medium/high).

### Drop and the undo toast (SY-03)

- **Does:** taps **Drop**. The task leaves Today; a quiet toast offers **Undo** for 5 seconds.
- **Writes:** `TaskItem.droppedAt`. Undo clears it. For a repeating task, Drop skips only this occurrence and the next instance is created.
- **Assumes:** nothing else needs the dropped task — ✓ (history is kept in the data) but see **G-19**.

### TD-03 Category filter

- **Sees:** a filter control in the Today header narrowing the whole list to one category; never creates sections.
- **State:** local UI state, not synced. ✓

---

## What Today shows afterwards

After adding *"Call the clinic back"* (30 min, low, due today) to Journey 1's day: a new row in **Tasks**; the meter moves from *"0m of 3h"* to *"30m of 3h"* (the new task counts, **G-13**); if the capacity were already reached, *"Day is full — put it on tomorrow?"* would have appeared first. Ticking it moves the row to a done state; the meter keeps its used value (completed work still counts toward the day) and, once a focus session exists, uses the actual time instead of the estimate.

## Data that exists afterwards (end-state check)

| Model | Change |
|---|---|
| `TaskItem` | + 1 (and +1 next instance when a repeating task is completed) |
| `DeferralRecord` | + 1 per deferral, with `day` and `reason` |
| `DayPlan` | today's row: `capacity` updated when the slider moves |
| `NudgeLog` | + 1 when a guidance card is shown (and `dismissedAt` when dismissed) |
| `TaskCategory` | unchanged (referenced) |

All storable with the current schema. No new fields are needed by this journey; the gaps below are rules, UI decisions and copy.

## Rules and changes this journey implies

If the proposals are accepted:

1. **Effort:** the four chips are shortcuts; *Other…* is a 15-minute stepper up to 8 hours; *30m* is preselected; *No estimate* remains available (G-11, G-12).
2. **Today's load** counts live tasks due on or before today plus tasks completed today, using actual focus time where a session exists and the estimate otherwise (G-13). Written into module 7.
3. **Un-completing a repeating task** removes the spawned next instance if it is untouched, and otherwise refuses with *"This one already repeated"* (G-14).
4. **Deferral reasons:** a user deferral with no chip is `reschedule`; with a chip it is that chip's value; an automatic deferral is `unspecified` (G-15).
5. **Quick dates** use the user's calendar's first weekday: *Later this week* is three days from now if that is still in the same week (otherwise not offered); *Next week* is the first day of next week (G-16).
6. **The Add sheet** opens on Task with a Task | Anchor switch; the separate chooser screen is dropped (G-17).
7. **No manual ordering in v1**, recorded as a working hypothesis to check in real use (G-18).
8. **A dropped task is not recoverable** after the 5-second undo in v1 — accepted because there is no History screen (G-19, **decided**).
9. **Design fixes:** importance drawn as low / medium / high (not "Matters 4 of 5"); *Drop*, not *Delete* (G-20).
