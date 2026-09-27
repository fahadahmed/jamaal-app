# Today List

> **Status: draft, needs review.** First-pass proposal grounded in the resolved [Task](../schema/task), [Habit](../schema/habit), and [Anchor](../schema/anchor) schemas.

The single unified list spanning personal, family, and work items — the app's home screen. Replaces bouncing between separate reminder/task/calendar apps.

## Layout

Grouped **by primitive type**, not by category, since each is tracked and interacted with differently:

1. **Anchors** — today's generated `Anchor` instances (from `AnchorRule`), sorted by `windowStart`. Each shows its window and current `attendanceStatus`. Tapping marks `attended` / `missed`.
2. **Habits** — today's `HabitTimeWindow` occurrences due today, with streak indicator (`currentStreak`) per window. Completing one advances that window's streak.
3. **Tasks** — due today (`dueDate` == today) or rolled over (`rolloverCount` > 0), plus undated backlog items surfaced separately or collapsed. Tapping toggles `isCompleted`. `category` (personal/family/work) shown as a tag/color per item, not as a grouping axis.

Within each section, `Task.priority` and `AnchorRule`/`Habit` ordering determine sort order below the primary time-based sort — exact tie-breaking rules are an open question below.

## Capacity slider

Sits at the top of the Today List. The user sets today's capacity (e.g. low/medium/high, or a numeric scale — exact representation TBD), and the rules engine uses it to **filter/reprioritize** what's surfaced:

- At low capacity: only Anchors (external, can't be deferred) and highest-`priority` Tasks/Habits show; everything else is collapsed into an "also today" section rather than hidden entirely (nothing should silently disappear).
- At full capacity: everything due today shows.

This is set two ways: from Night Planning the night before (see [night-planning.md](night-planning)), or adjusted directly on the Today List if the day changes.

## Wellbeing sparkline

Visible on the Today List (exact placement TBD — likely a compact strip near the capacity slider). Reflects the wellbeing score (rules-engine module 5) over recent days; feeds from Night Planning's reflection step, not from Today List interactions directly.

## Empty states

- No Anchors/Habits/Tasks today: encouraging empty state, not a blank screen — exact copy is a design-pass concern, not a schema one.
- All sections at capacity limit hidden something: show a subtle "N more at higher capacity" affordance rather than fully hiding the fact that items exist.

## Open questions

- **Capacity representation**: enum (`low`/`medium`/`high`) vs. numeric scale (e.g. 0–100, or a count of "slots"). Affects both this doc and `Habit`/`Task` schema if capacity ever needs to be stored per-day rather than transient UI state.
- **Sort order within a section**: by time only, or does `Task.priority` reorder within the same day? Needs a concrete tie-breaking rule before implementation.
- **Backlog tasks (no `dueDate`)**: always visible in a collapsed "Backlog" section, or only surfaced during Night Planning's "plan tomorrow" step?
- **Multi-day Anchors**: none of the current examples (prayer windows, school run, bin night, plant watering) span multiple days, but worth confirming that's a hard invariant before relying on "today's Anchors" as a simple date filter.
