# v1 enhancements: reconciliation

Design's "Jamaal v1 enhancements" handoff (November 2026) answers three pieces of beta feedback: there is no way to look back at a day, future-dated tasks are invisible until the night before, and it isn't clear how to edit a task. The frames and sources are in [`mockups/screens/10-v1-enhancements/`](../../mockups/screens/10-v1-enhancements/) (index in the [mockups README](../../mockups/screens/README#10-v1-enhancements-november-2026)) and the handoff's own README is kept there as `HANDOFF.md`. This page records what was decided when it was set against the repo, as [v4 reconciliation](v4-reconciliation) did for v4. Work is tracked in #382 (slices #383 to #389).

**The behaviour is in** [Coming up and Day review](../journeys/coming-up-and-day-review) **and the updated** [Today list](../journeys/today-list), [Task](../schema/task) **and** [rules engine](../architecture/rules-engine). **Styling comes from the frames**, unless it conflicts with something locked here.

## Decisions

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | The handoff wants a **scheduled day** separate from the **due date**. | **No new field in v1.** A task's `dueDate` is the day it is scheduled for, as it already is: Today shows tasks due on or before today, so a future-dated task is already off Today and out of today's capacity. The handoff's "Due {weekday}" line, shown when the two differ, is dropped. | It is a visibility problem, not a data one. A second date would touch every engine query, the deferral rules and the repeat dedup key, and add a CloudKit schema change (permanent once deployed) for a distinction nobody has asked for. It can be added later, additively. |
| 2 | The title's "editable" affordance (handoff open question 1). | A **persistent faint tinted box** behind the title, not only after a tap. | Discoverability is what the beta feedback was about. |
| 3 | Yesterday row after an unplanned day (Q2). | **"Yesterday · not planned"**, still tappable. Hidden only when there is no data at all (the first day). | Hiding it would bring back the feeling of no way to look back. |
| 4 | How far back Day review goes (Q3). | **To the first day with data, uncapped.** | A cap adds a limit nobody asked for. |
| 5 | Move to today over capacity (Q4). | The **existing "Day is full" handling** (TK-01) only. | A second warning is noise. |
| 6 | Undo toast duration: handoff says about 4 s, the register (SY-03) says 5 s. | **5 seconds, everywhere.** SY-03 keeps its ID and gains the edit-undo use. | One undo duration across the app (a drop, a finish and an edit). |
| 7 | Effort picker offers 15 min to 2 h, "two hours is the maximum". | The six options **plus the existing Other… stepper**, up to 8 hours as now. The picker's helper line suggests splitting a very big task. | The schema allows up to 8 hours and existing tasks must stay editable. |
| 8 | "Not done · carried to {date}" and "Deferred to {date}" are two states in Day review. | Both read the day's `DeferralRecord`: an **automatic** one (`reason` is `unspecified`) is "carried to", one the user made is "Deferred to". | The data is already kept per day. |
| 9 | The Mark done fix inside two days, for a task or habit. | **Tasks only** get the two-day window (Day review draws Mark done on tasks only). A task ticked this way gets `completedAt` set to **the end of that day** (not now), so the day's record, `DayPlan.completedEffortMinutes` and wellbeing attribute it to the day it belongs to; if it was carried it leaves the later day. **Habits keep their existing 14-day correction** (`HabitLogging.canCorrect`, from the heatmap), and **Anchors keep their own rule** ("Mark as done after all" until the end of the day). The footer therefore reads *"Past days are read-only. A missed task can be ticked for two days."* | Without this a late tick would count on the wrong day. |
| 10 | Day review needs a per-day record. | **Derived, not stored.** `DayPlan` (capacity, planned and completed minutes, `planningCompletedAt` as the close time), tasks by `completedAt`, `droppedAt` and `DeferralRecord.day`, Anchor instances by `occurrenceDate`, habit entries by day. Slice 2 checks nothing the screen needs has been pruned, and the schema stays unchanged. | Keeps the CloudKit schema as it is. |
| 11 | Coming up count and rows. | Counts **tasks due after today within 14 days plus one-off Anchors**; recurring Anchor rules never appear (they are generated two days ahead, and listing them would drown the list). A repeating task shows its **one live instance**. Backlog tasks (no date) are not in Coming up. | Matches the one-live-instance rule and the Backlog section. |
| 12 | Where the screens open. | As the handoff: **Coming up takes the list column, Day review takes the detail column** on wide layouts; pushes on iPhone and Duo folded. | Kept. |

## What this adds to the register

New IDs `UP-01` (Coming up) and `DY-01` (Day review); `TK-02a`, `TK-02b`, `TK-02c` (effort, due and title editing inside `TK-02`) and `TK-07` (repeat scope). Changed: `TD-01` (two rows), `TD-07` (also scheduled tasks), `TK-02` (the editor), `SY-03` (edit undo). See [the register](../journeys/screens#4-screen-register).

## What it does not change

The tab bar, the sidebar and the Duo bar (no new destination), the palette and fonts, and the rule that terracotta is the only filled button on a surface. Nothing here is a project, a tag or a grouping axis: Coming up is the same flat list, seen later.

## Still open

- **Duo point sizes** in the frames are estimates, as in v4.
- The **Mac pointer targets** (28 to 32 pt) follow v4.
