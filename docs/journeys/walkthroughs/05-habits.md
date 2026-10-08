# Journey 5 — Habits: create, log, pause

> **Status: done — gaps G-37 … G-44 raised, decided and applied** (see the [gap log](overview#gap-log)). The text below is the walkthrough as first written, with the proposals it raised. Register flow **F08**, screens **HB-01 … HB-09** and the Habits section of **TD-01**. Behaviour is in [Habit](../../schema/habit) and [Rules engine → module 2](../../architecture/rules-engine); this page tests it against the schema and engine.

**In one line:** the user creates a habit of one of four kinds, logs it day by day from Today, reads how it is going from a grid that never "breaks", and can pause it when life gets in the way.

**Preconditions:** Journeys 1–4 done. Examples: the onboarding habit *Qur'an reading* (timed, 15 min), plus *Water* (counted, 8), *Morning run* (timed, three times a week), *Reading before bed* (binary, daily) and *No sugary drinks* (avoid).

---

## HB-01 The Habits overview

- **Sees:** the **Habits | Anchors** segmented control (Habits selected). **Groups** as cards — name, "4/5 today", a completion ring, a 14-day aggregate grid — collapsed by default and expandable into their habits; ungrouped habits; paused habits muted with *"Paused — resumes 19 Oct"*; **Add** at the top; an empty state (*"No habits yet — they'll appear as patterns do."*).
- **Reads:** non-archived `Habit`s and `HabitGroup`s, their windows, today's and the last 14 days' `HabitEntry`s, `pausesData`.
- **Does:** expands a group (local UI state), opens a habit, adds one.
- **Assumes:**
  - the ring and the aggregate grid need no storage — ✓ (derived: complete windows ÷ due windows today; paused habits excluded);
  - archived habits can be found again — **✗ G-41** (archiving hides a habit, and nothing brings it back).

## HB-03 Add or edit a habit

- **Sees:** first a **type picker** with plain descriptions — *Did I do it?* (binary) · *Did I do it N times?* (counted) · *Did I do it for N minutes?* (timed) · *Did I avoid it?* (avoid). Then a form for that kind: **title**; the kind's target (a count, minutes, or an allowance of slips); the **schedule** (daily · weekdays · custom → `HB-04`); **times of day**; a **reminder** per time; a **group**; an optional note. Presets pre-fill it (the [catalogue](../../schema/habit#presets)).
- **Writes:** a `Habit` (`kind`, `presetKey`, `frequency`, `scheduledDays`, `targetPerWeek`, `notes`), its `HabitTimeWindow`s (`label`, `startMinute`, `endMinute`, `target`, `effortMinutes`, `reminderMinute`), and the optional `group` link.
- **Assumes:**
  - several times a day are possible — **✗ G-37** (the schema supports multiple windows, but no screen lets the user add a second one: a medication taken morning and evening can't be made);
  - the kind can be changed later — **✗ G-42** (history is interpreted by kind — `amount` is a count, minutes or slips — so changing the kind would silently reinterpret every past day);
  - editing a target later is safe — ✓ (each entry snapshots its `target`).

## HB-04 Custom recurrence

- **Sees:** seven day chips *or* a *"N times a week"* stepper (*"Which days suit you?"* / *"Target a week"*).
- **Writes:** `scheduledDays` (fixed days, `targetPerWeek = 0`) or `targetPerWeek` (1–7, any days).
- **Assumes:** "N times a week" is well defined — **✗ G-38** (which days does Today show such a habit on, and can a day be *missed* when the week is still open?).

## HB-05 Groups

- **Sees:** a name, the habits in it, and the collapsed preview.
- **Writes:** `HabitGroup` (`title`, `sortOrder`), `Habit.group`.
- **Assumes:** a group is purely a visual bundle — ✓ (no score or history of its own; archiving never deletes its habits).

## TD-01 Logging from Today

- **Sees:** a habit section (*"Habits · 4 of 7"*): groups as pills, then habits. A **binary** habit has a check; a **counted** one a stepper (*"3 / 8"*); a **timed** one shows minutes so far with **Begin**; an **avoid** one shows **Log a slip** and **Held today**. Paused habits are hidden.
- **Writes:** a `HabitEntry` for the window and the day (created on first log, with its `target` snapshot): binary `amount` 0 or 1; counted the count; timed the minutes recomputed from sessions; avoid the slips, with `completedAt` set when the user confirms **Held today**. Completing the target sets `completedAt`.
- **Assumes:**
  - the day is the logical date — ✓;
  - un-checking is harmless — ✓ (the entry goes back to `amount = 0`);
  - the section has a stable order — **✗ G-44** (nothing says how habits are ordered);
  - a reminder doesn't fire for something already done — **✗ G-43** (repeating local notifications can't skip a day).

## HB-02 Habit detail

- **Sees:** the **density grid** (filled by how much was done; a miss in its own colour; unscheduled, paused and pre-creation days empty), a **plain-language read** (*"Missed 9 of the last 21. Five a week may be more than this season allows — try three?"*), and per-kind figures. Actions: Edit · Pause · Archive. A habit with several times a day has one grid per time.
- **Reads:** `HabitEntry`s over the window, `createdAt`, `pausesData`; the engine's `.densityRead`.
- **Does:** taps a past cell to correct it.
- **Assumes:**
  - the grid states are fully derived — ✓ (module 2: a due past day with no entry or `amount` 0 is *missed*; partial shades at 1–49% and 50–99%; complete at 100%);
  - a forgotten day can be put right — **✗ G-39** (nothing says whether past days are editable, or how far back);
  - the read never scolds — ✓ (plain numbers, no praise or blame).

## HB-06 Pause with a reason

- **Sees:** dates (from today; an end, or *until I resume*) and a reason — travel, illness, cycle, other.
- **Writes:** an entry in `Habit.pausesData`. Paused days become unscheduled: no cell fills, nothing counts against the habit, no reminders, hidden from Today and Night Planning. *Resume* edits the end date.
- **Assumes:** ✓ (defined in habit.md; past days keep their entries).

## HB-07 Edit and archive

- **Does:** edits fields (not the kind — **G-42**), or archives: `isArchived = true`; history is never deleted.
- **Assumes:** archived items stay recoverable — **✗ G-41**.

## HB-08 Avoid habits

- **Sees:** **Log a slip** (undoable), **Held today**, and the allowance; a day stays unresolved until it ends.
- **Writes:** `HabitEntry.amount` (slips); `completedAt` on **Held today**.
- **Rules:** `missed` if slips exceed the allowance; `complete` only if within it **and** the user engaged that day; otherwise `empty`. There is no "days since the last slip" counter.
- **Assumes:** "engaged that day" can be computed — **✗ G-40** (the docs say "any recorded activity" but don't list which records count, and opening the app leaves no record).
- **Note:** **Settled 8 Oct 2026: Option A** (*Say it: two actions on the row*), as drawn in the v4 `HB-08` frame. Option B (inferring the hold from the day) is dropped. Built: the three moments on the Today row, and the detail's grid and read.

## HB-09 Minutes by hand

- **Does:** a timed habit's *"Add minutes"*.
- **Writes:** a finished `WorkSession` with `outcome = manual` (no timing of its own); the day's entry is recomputed. ✓ (decided in Journey 3).

---

## What the user sees over time

Week one: a few cells filled, the read saying nothing yet. After three weeks of mostly doing it: a dense grid, a read that simply states the numbers. After a holiday: a paused stretch of empty cells, not a run of misses, and no drop in the read. A weekly-target habit (*Morning run*, three times a week) shows on Today each day until the week's three are done, then quietly stays done; its read says *"2 of 3 this week"*.

## Data that exists afterwards (end-state check)

| Model | Change |
|---|---|
| `Habit` | + 1 per habit (`kind` fixed at creation) |
| `HabitTimeWindow` | ≥ 1 per habit (one all-day by default; more with G-37) |
| `HabitEntry` | one per window per day logged, with its `target` snapshot and `amount` |
| `HabitGroup` | + 1 per group |
| `WorkSession` | timed habits: sessions, and `manual` ones for minutes added by hand |
| `Habit.pausesData` | pauses |

Every row is storable now; no new fields are proposed. The gaps are UI, rules and definitions.

## Rules and changes this journey implies

If the proposals are accepted:

1. **Times of day (G-37):** the form has a *Times of day* section: one all-day window by default, **Add another time** (up to four) adds a labelled window with an optional start, end and reminder. Each window has its own target, entries and grid.
2. **Weekly-target habits (G-38):** Today shows the habit **every day of the week until the week's target is met**, then as done. Its days are **never `missed`** (nothing breaks, no red): filled days and empty days only, and the read speaks in weeks. A day counts toward the week when its own day target is met. The week follows the calendar's first weekday.
3. **Past days (G-39):** the last **14 days** in the grid are tappable to correct (binary toggle, counted stepper, timed minutes, avoid slips / *Held*); older days are read-only. A correction is an explicit engagement for an avoid habit.
4. **Engagement (G-40):** a logical day is **engaged** if any of these exist for it: a `TaskItem` completed that day; a `HabitEntry` with `amount > 0` for any habit, or an avoid entry with `completedAt` set (*Held today*); an `Anchor` whose `resolvedAt` falls on that day; a `WorkSession` with that `day`; a `NightPlanningSession` for that date that was closed or skipped. Opening the app alone doesn't count.
5. **Archived items (G-41):** each list — habits, Anchor rules, categories (and groups) — ends with a collapsed **Archived** section with **Restore**.
6. **Kind is fixed (G-42):** a habit's `kind` can't change after creation; to change it, archive the habit and create a new one. Every other field is editable (a changed `target` affects the future only).
7. **Reminders skip what's done (G-43):** habit reminders are planned by the notification planner as near-term individual notifications, and cancelled when the habit is logged, paused, archived or its time is edited.
8. **Order on Today (G-44):** groups first (as pills), then ungrouped habits by window start (all-day last), then title.
