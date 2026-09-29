# Today List

> **Status: reconciled with master summary v2 — draft, needs review.** Layout grouped by primitive is kept; v2's guidance highlight, capacity filtering, deferral gestures and habit strip are folded in.

The single unified list spanning every category — the app's home screen ("One list. Just today. Beautifully ordered."). Replaces bouncing between separate reminder/task/calendar apps.

## Layout

Top to bottom:

1. **Capacity slider** — today's `low` / `medium` / `high`.
2. **Companion card** (when there is one) — at most one guidance card per day, inline-dismissible.
3. **Anchors** — today's generated instances, sorted by `windowStart`. Each shows its window and `attendanceStatus`; tapping marks `attended` / `missed`.
4. **Habits** — today's due `HabitTimeWindow` occurrences with streak per window. Groups appear as a pill with proportional ring, emoji, name and count ("4/5"); tapping opens the group. Counted habits use an increment/decrement stepper in place of a single check.
5. **Tasks** — due today or overdue, plus a collapsed backlog. Tapping toggles complete; the row opens the task detail sheet. Each row shows its category as a coloured label.
6. **Also today** — collapsed section for anything the current capacity hides, with a count.
7. **Add a task** — opens the add-task sheet.

Tasks are grouped by primitive, not by category. Within Tasks, order comes from the rules engine: hidden Eisenhower quadrant, then due date, which puts `low` tasks after `medium`/`high` — see [rules-engine.md](../architecture/rules-engine), module 1. The quadrant is never displayed. When the list has five or more tasks and fewer than two are `medium`/`high`, the companion may suggest picking one or two that matter most.

An optional **category filter** narrows the whole list to one category; it never creates sections.

## Capacity slider

Sets today's capacity; the engine uses it to decide visibility (module 7):

- **low** — Anchors, urgent-and-important tasks, and habits with a streak at risk. Everything else is under "also today".
- **medium** — everything due except the least important, least urgent tasks.
- **high** — everything due today.

Nothing disappears silently: hidden items sit under a collapsed "N more at higher capacity" affordance.

Set two ways: from Night Planning the evening before, or directly here if the day changes. The slider also shows the day's load state (light / balanced / full / overloaded / exhausting) as a quiet indicator (counting tasks, habit windows and anchors), and the companion offers a gentle prompt when the day is overloaded. Capacity is the user's own call, not computed from the day's contents.

## Task interactions

- **Complete**: tap the check.
- **Detail sheet** (bottom sheet): title, notes as a tappable markdown checklist, category, effort estimate, importance, due date, deferral history; actions — Defer, Drop, and (pending decision) Start/Finish (see [task.md](../schema/task) open questions).
- **Defer**: 1st and 2nd deferral moves the task to tomorrow instantly; from the 3rd a date picker opens with reason chips.
- **Add task** (bottom sheet): title, effort (15 / 30 / 60 / 120 min), notes, importance (`low` by default), category, schedule (today / tomorrow / Later this week / Next week / Someday / pick a date). Choosing `medium`/`high` importance makes the date required (pre-filled with today, not clearable) and hides Someday. A `low` task with no date is a backlog task.

## During-day guidance

At most one card per day. The engine highlights a task with a "Start here" or "Good now" pill and shows a companion card explaining why (heavier tasks in the morning, lighter ones in the early afternoon, open habit windows, remaining time vs. remaining effort). Tapping the card dismisses it inline.

## Wellbeing

A compact **sparkline** near the capacity slider shows the wellbeing score over recent days ("gathering data" until seven days exist). Tapping it opens the Wellbeing tab. It is fed by Night Planning's reflection step and the engine's derived signals, not by Today interactions directly.

## Empty and edge states

- Nothing due at all: an encouraging empty state ("Your day is blank"), not a blank screen. When everything is done: a quiet celebration.
- Notifications denied: an in-app banner at planning time — "Start evening planning →".
- All sections hidden by capacity: a visible "N more at higher capacity" affordance.

## Open questions

- **Backlog tasks (no `dueDate`)**: always visible in a collapsed "Backlog" section, or surfaced only in Night Planning's plan step?
- **Manual ordering**: may the user drag to override the engine (v2 had a manual-order flag)? Affects whether a per-task order field is needed.
- **Multi-day Anchors**: none of the current examples span days; confirm that's a hard invariant before relying on a simple date filter for "today's Anchors".
- **Anchors under capacity**: Anchors are always shown at every capacity level (external, can't be deferred); confirm they never fold into "also today".
- **Where the category filter lives** (Today header vs. filter sheet) is a design-pass decision.
