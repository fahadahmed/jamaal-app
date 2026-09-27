# Night Planning

> **Status: draft, needs review.** First-pass proposal for the 5-step wizard named in CLAUDE.md's rules-engine module 4 ("Night Planning orchestration — 5-step wizard state machine").

A guided end-of-day flow: review the day, reflect, set tomorrow's capacity, plan tomorrow, confirm. Because it's a **state machine** (per CLAUDE.md), progress persists if the user closes the app mid-flow and resumes later the same night.

## Steps

### 1. Review today

Summarizes what happened: Tasks completed vs. rolled over, Habit windows completed vs. missed (per streak), Anchor `attendanceStatus` for the day. Read-only — no editing here, just a look back before reflecting.

### 2. Reflect

A brief wellbeing check-in. Feeds the wellbeing score (rules-engine module 5) and the Today List's sparkline. Exact input shape (a 1–5 scale? free text? both?) is an open question — no schema exists yet for a persisted "reflection" entry.

### 3. Set capacity

Sets tomorrow's capacity value, consumed by the Today List's capacity slider (see [today-list.md](today-list)) to filter/reprioritize what's shown. Same open question on representation (enum vs. numeric) as in that doc.

### 4. Plan tomorrow

Select/reorder/add `Task`s and `Habit`s for tomorrow. **Anchors are not planned here** — they're generated from `AnchorRule`, not user-scheduled per-day, so this step only surfaces already-generated Anchors for tomorrow as read-only context (e.g. "you have Fajr and the school run tomorrow"), not something the user adds to.

### 5. Confirm

Locks in tomorrow's plan. This is likely also where notification/nudge scheduling (rules-engine module 6) gets triggered for tomorrow's confirmed items — worth confirming when that module's design happens.

## State machine

Each step's answer should persist as the user moves forward, so backing up doesn't lose data, and closing the app mid-wizard resumes at the same step later. No schema drafted yet for this persisted wizard state — needs its own model (e.g. `NightPlanningSession` with a `currentStep` field) once the rules-engine module design (#7) settles the exact shape.

## Open questions

- **Reflection data shape**: numeric mood scale, free-text journal, both, or neither (just a capacity number with no separate reflection input)? Affects whether a new schema model is needed.
- **Wizard state persistence**: needs its own model, not drafted here — see rules-engine module design (#7).
- **When does this run**: a fixed time prompt (e.g. evening notification), user-initiated only, or both? Affects notification/nudge logic (module 6) more than this doc, but worth settling since it changes what "today" vs. "tomorrow" means if triggered at odd hours.
- **Skipping**: can a step be skipped (e.g. skip reflection, just set capacity and plan)? If so, which steps are optional vs. required?
