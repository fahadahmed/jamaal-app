# Today List

> **Status: reconciled with master summary v2 — draft, needs review.** Layout grouped by primitive is kept; v2's guidance highlight, capacity filtering, deferral gestures and habit strip are folded in.

The single unified list spanning every category — the app's home screen ("One list. Just today. Beautifully ordered."). Replaces bouncing between separate reminder/task/calendar apps.

## Layout

Top to bottom:

1. **Capacity slider** — today's `low` / `medium` / `high`.
2. **Companion card** (when there is one) — at most one guidance card per day, inline-dismissible.
3. **Anchors** — today's Anchors (those whose `occurrenceDate` is today: generated from rules, plus any one-offs), sorted by `windowStart`. Each shows its window state (upcoming / open / closing soon / closed) as a window bar, plus its `attendanceStatus`. Tapping marks `attended` — **only while the window is open**; while upcoming the control is disabled and says when it opens. "Not today" marks `skipped` and "Someone else did it" marks `delegated`, both any time before the window closes and neither a miss. `missed` is set automatically once the window closes with the Anchor still pending. An `afterLast` Anchor (plants) has a multi-day window and shows on every day it is open, rather than only on the day it opened.
   - **Grouped row per rule.** A rule that yields more than one Anchor today (five prayers, drop-off and pick-up) shows as **one collapsed row** — the rule's title, a count of attended out of those still counting (skipped and delegated excluded, e.g. "Salah 3/5"), and the next pending window ("Asr · until 17:58"). Tapping expands it into the individual Anchors, each tappable as above. A rule with a single Anchor today, and every one-off, is a plain row. Grouping is display-only, like a habit group: no state of its own, and everything else (load, wellbeing, Night Planning review) reads the individual instances. Groups sort by their earliest window start; when everything in a group is decided, the row shows a quiet done state.
4. **Habits** — today's due `HabitTimeWindow` occurrences (no streak counters — density lives on the habit detail). Groups appear as a pill with proportional ring, emoji, name and count ("4/5"); tapping opens the group. Counted habits use an increment/decrement stepper in place of a single check; **timed** habits show minutes so far ("12 of 20 min") with **Begin** (the same ambient chip as a task) or a way to add minutes by hand; **avoid** habits show a quiet **Log a slip** action and a **Held today** tap, with no fill until the day resolves. Paused habits are hidden.
5. **Tasks** — due today or overdue, plus a collapsed backlog. Tapping toggles complete; the row opens the task detail sheet. Each row shows its category as a coloured label.
6. **Also today** — collapsed section for anything the current capacity hides, with a count.
7. **Add** — opens a choice of **Task** (the add-task sheet) or **One-off Anchor** (title, date, window start/end, optional duration). Recurring Anchors are created and managed in the Habits tab's Anchors segment.

Tasks are grouped by primitive, not by category. Within Tasks, order comes from the rules engine: hidden Eisenhower quadrant, then due date, which puts `low` tasks after `medium`/`high` — see [rules-engine.md](../architecture/rules-engine), module 1. The quadrant is never displayed. When the list has five or more tasks and fewer than two are `medium`/`high`, the companion may suggest picking one or two that matter most.

An optional **category filter** narrows the whole list to one category; it never creates sections.

## Capacity slider

Sets today's capacity; the engine uses it to decide visibility (module 7):

- **low** — Anchors, urgent-and-important tasks, and habits whose window is closing and not yet done. Everything else is under "also today".
- **medium** — everything due except the least important, least urgent tasks.
- **high** — everything due today.

Nothing disappears silently: hidden items sit under a collapsed "N more at higher capacity" affordance.

Set two ways: from Night Planning the evening before, or directly here if the day changes. The **capacity meter** (a thin pill under the slider) shows **budget used** — "2h 15m of 3h" — counting tasks only, plus a quiet load state (light / balanced / full / overloaded / exhausting). It turns terracotta when the day is overloaded or runs **past the day's end** (a user-set time, default 19:00) and then reads "40 min past 19:00", with one tap to move the overflow to tomorrow. Nothing is blocked. If a planned task is longer than the longest free block, a quiet flag says so. Capacity is the user's own call, not computed from the day's contents; the engine only *suggests* a level. Adding a task that tips the day over shows "Day is full · offer tomorrow" and never refuses it.

## Task interactions

- **Complete**: tap the check.
- **Detail sheet** (bottom sheet): title, notes as a tappable markdown checklist, category, effort estimate, importance, due date, deferral history; actions — Defer, Drop (for a repeating task, skips only this occurrence), Stop repeating, and **Begin**, which starts a focus session (see [Focus chip and sessions](#focus-chip-and-sessions)). Begin also appears on the "Start here" guidance card.
- **Defer**: 1st and 2nd deferral moves the task to tomorrow instantly; from the 3rd a date picker opens with reason chips.
- **Add task** (bottom sheet): title, effort (15 / 30 / 60 / 120 min), notes, importance (`low` by default), category, schedule (today / tomorrow / Later this week / Next week / Someday / pick a date), repeat (Never / Daily / Weekly + days / Monthly — needs a date, hides Someday). Choosing `medium`/`high` importance makes the date required (pre-filled with today, not clearable) and hides Someday. A `low` task with no date is a backlog task.

## Focus chip and sessions

Beginning a task starts a **focus session** ([task.md](../schema/task#focus-sessions-begin--pause--finish)). It is **ambient, never modal**: nothing blocks, and the whole app stays usable.

- **The chip** sits above the tab bar and is present on **every tab**, as global chrome. It shows the task title and a count-up timer (monospaced digits so the numerals don't jitter). It is filled only while a session is live, and it looks the same when overrun — no red, no alarm.
- **Tapping the chip** opens the **focus screen**: the timer, the task's note beneath it with tappable checkboxes, and **Pause** and **Finish**.
- **Finish** opens a sheet showing actual against estimate with one optional note line, then a quiet 5-second **undo** toast.
- **Timed habits** use the same chip: **Begin** on a timed habit row starts a session against that habit's window; the chip reads the same, and finishing adds the minutes to today's entry.
- **Beginning a second task** raises the settle sheet: Done, Defer to tomorrow, or Drop the running one first.
- **Near a fixed Anchor** the chip simply says "Maghrib in 12 min". It never blocks.
- **After the day rolls over** (default midnight), a session that was still running was auto-closed at the boundary; tomorrow's list opens with one row offering to pick that task back up.
- On wide layouts (iPad, Mac, Duo unfolded) the chip lives in the right-hand panel; see [app-flow.md](app-flow).
- The Lock Screen Live Activity and Dynamic Island version is **v1.1**.

## During-day guidance

At most one card per day. The engine highlights a task with a "Start here" or "Good now" pill and shows a companion card explaining why (heavier tasks in the morning, lighter ones in the early afternoon, open habit windows, remaining time vs. remaining effort). Tapping the card dismisses it inline.

## Wellbeing

A compact **sparkline** near the capacity slider shows the wellbeing score over recent days ("gathering data" until seven days exist). Tapping it opens the Wellbeing tab. It is fed by the engine's derived signals and the optional mood line on Night Planning's Review step, not by Today interactions directly.

## Empty and edge states

- Nothing due at all: an encouraging empty state ("Your day is blank"), not a blank screen. When everything is done: a quiet celebration.
- No plan was confirmed for today (Night Planning skipped or missed): one quiet card at the top, "No plan for today — two minutes to pick?", opening a shortened Build tomorrow for today. Shown once; no guilt, no count.
- Notifications denied: an in-app banner at planning time — "Start evening planning →".
- All sections hidden by capacity: a visible "N more at higher capacity" affordance.

## Open questions

- **Backlog tasks (no `dueDate`)**: always visible in a collapsed "Backlog" section, or surfaced only in Night Planning's plan step?
- **Manual ordering**: may the user drag to override the engine (v2 had a manual-order flag)? Affects whether a per-task order field is needed.
- **Anchors that end after midnight** (Isha in summer): resolved — an Anchor belongs to the day its window *starts* (`occurrenceDate`). So a pending Isha can still be open when Night Planning runs late; it isn't shown as tomorrow's. With a user-set rollover, "belongs to the day it starts" uses the logical date.
- **Anchors under capacity**: Anchors are always shown at every capacity level (external, can't be deferred); confirm they never fold into "also today".
- **Where the category filter lives** (Today header vs. filter sheet) is a design-pass decision.
