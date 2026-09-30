# Journey 8 — Wellbeing

> **Status: walked; gaps G-58 … G-66 raised, proposals waiting for a decision** (see the [gap log](overview#gap-log)). Register flow **F11**; screens **WB-01 … WB-03** (**WB-04** is v1.1) and the sparkline strip **TD-02** on Today. Behaviour is in [Rules engine → module 5](../../architecture/rules-engine); this page tests it against the data the first seven journeys actually leave behind.

**In one line:** after a week or two of real use, the user opens the Wellbeing tab and gets a plain, unjudged read of how their days have been going, and — when a pattern shows — one gentle suggestion they can take or leave.

**Preconditions:** Journeys 1–7 done. Example: three weeks of use; most days planned at night, a few skipped; the last three days overloaded; *Morning run* missed on its scheduled days; mood given on some nights.

---

## TD-02 The sparkline on Today

- **Sees:** a slim strip near the slider: a sparkline of the score over recent days, or *"Gathering data"* with a count. Tapping opens `WB-01`.
- **Reads:** the derived score series (module 5). **Writes:** nothing.
- **Assumes:**
  - "gathering data until seven days exist" is computable — **✗ G-59** (seven days of *what*: the docs say `DayPlan` history, but a `DayPlan` exists only for active days since G-55, and calendar days since install is a different number);
  - the series is computable per day — **✗ G-62** (nothing defines the score, so nothing can be plotted).

## WB-03 Gathering data

- **Sees:** *"Jamaal needs about a week of days to say anything useful"* and seven dots filled as days accumulate.
- **Reads:** the count of **active days** (G-59). Nothing is shown about mood or patterns.
- **Assumes:** ✓ once G-59 is defined; it never asks the user to do more than live normally (the mood line stays optional).

## WB-01 Steady

- **Sees:** the **score** (0–100), its **trend** against the previous period, a **plain read** in Jamaal's voice (*"Steady. Most days done, loads mostly light."*), **completion** for the window, and **heavy days** (a count or small strip). No colours that scold.
- **Reads:** `DayPlan`s for the window (`completionRate`, `loadScore`, `wasOverloaded`), `HabitEntry`s, `NightPlanningSession.mood`.
- **Assumes:**
  - the score has a recipe — **✗ G-62** (the docs list inputs but no weights; design's X-04 asks "what makes 78 a 78");
  - `completionRate` is meaningful — **✗ G-60** (tasks are re-dated when deferred, so "tasks due that day" can't be recounted afterwards; the denominator isn't defined);
  - `wasOverloaded` exists for days that weren't planned — **✗ G-61** (today it is written only when Night Planning closes a day, as a *planned* snapshot; a skipped night leaves a `DayPlan` with zero load, and a planned load isn't the load the day actually had);
  - mood belongs to the right day — **✗ G-58** (`mood` lives on the `NightPlanningSession` whose `forDate` is *tomorrow*, but the mood is about the reviewed day);
  - the mood note can be seen again — **✗ G-66** (the docs leave it open, and storing a note nothing ever shows is odd).

## WB-02 Strained, and the suggested action

- **Sees:** as WB-01, with a calm card naming one pattern and one action (*"The last three days were heavy. Lighten Saturday?"* — **Lighten Saturday** · **Not now**).
- **Reads:** the active pattern signals.
- **Writes:** the action's change (see below), and a `NudgeLog` (`wellbeing`, `subjectKey` = the pattern) when shown, and again if dismissed.
- **Assumes:**
  - the patterns are computable — **✗ G-63** (`heavyRun` is clear; `habitNeglect` ignores weekly-target and paused habits and avoid habits; `completionCollapse` has no threshold; `weekendOverplan` has no test; `avoidance` — a task deferred 4+ times — duplicates the 3rd-deferral easing message and the 5th-deferral suggestion the task already has);
  - each pattern has an action that writes something definite — **✗ G-64** (only "Lighten Saturday" is drawn; what it changes — the weekday default, or one day's level — isn't said, and nor is the action for any other pattern);
  - "at most one wellbeing nudge a day" has a home and respects *Not now* — **✗ G-65** (is the nudge a notification or a card? after *Not now*, would the same pattern be offered again tomorrow?).

## WB-04 "What makes this score"

- **v1.1** (register decision). The derivation in G-62 is written so this view can later read it straight off.

---

## What the user sees over time

Week one: the strip says *"Gathering data · 3 of 7"*. By the second week there is a number, a flat or gently moving line, and a plain read. After three heavy days the tab turns calm-strained: the read names it and offers one change. They tap *Not now*, and the same card doesn't come back for a week. Nothing ever scolds; a skipped night only lowers how much there is to say.

## Data that exists afterwards (end-state check)

| Model | Change |
|---|---|
| `DayPlan` | one per active day, finalised at rollover with lived completion and load (G-60, G-61) |
| `NightPlanningSession` | `mood` / `moodNote`, read against `forDate − 1` (G-58) |
| `NudgeLog` | + 1 per wellbeing card shown, + `dismissedAt` on *Not now* (G-65) |
| `UserSettings` | `weekdayLevels` or `mediumDayMinutes` when an action is taken (G-64) |

No stored wellbeing model and no new fields: everything is derived, which keeps devices converging.

## Rules and changes this journey implies

If the proposals are accepted:

1. **Mood belongs to the reviewed day (G-58):** mood is read as the mood for `forDate − 1` of its session (the day the Review step looked at). A shortened morning session has no Review and so no mood.
2. **Active days (G-59):** a logical day is **active** if it has a `DayPlan` (G-55 gives one to every day with activity). *Gathering data* lasts until **7 active days** fall inside the last 14 logical days; the dots count active days. A quiet stretch (travel, illness) simply lowers the count and the score pauses rather than falling.
3. **Completion (G-60):** at rollover, `completionRate` = tasks completed that day ÷ (tasks completed that day + tasks the rollover auto-deferred or the user deferred or dropped that day). Days with neither are not counted in the window.
4. **Lived load (G-61):** finalising `DayPlan(D)` at rollover also sets `plannedTaskMinutes`, `loadScore` and `wasOverloaded` from the day **as lived** (module 7's definition for today: live-due plus completed, actual minutes, that day's level — `DayPlan.capacity` or the weekday default). The Night Planning snapshot still serves the plan preview and the closing screen, and is overwritten at rollover.
5. **The score (G-62, X-04):** a whole number 0–100 over the **last 14 logical days**, from four parts, each 0–100, averaged over active days: **completion 45%** (mean `completionRate`), **load 25%** (share of active days that were not overloaded), **habits 20%** (mean density of due windows, paused habits excluded, weekly-target habits by week), **mood 10%** (mean of (mood − 1) ÷ 4, only over days with a mood). With no mood at all, the other three weights are scaled up to 100%; skipping mood never costs anything. The sparkline plots the score at each of the last 14 days, each over its own trailing 14 days, shown only where at least 7 active days exist. **Trend** = this score minus the score 14 days earlier, shown as *steadier / about the same / heavier*, never as a number with a colour. The page is **strained** when any pattern is active, otherwise **steady**.
6. **Patterns (G-63):**
   - `heavyRun` — 3 or more consecutive active days with `wasOverloaded`.
   - `habitNeglect` — a habit with 3 consecutive *scheduled* days missed; paused, archived, weekly-target and avoid habits are excluded.
   - `completionCollapse` — the mean `completionRate` of the last 3 active days is below half of the mean over the prior 14 days, and below 40%.
   - `weekendOverplan` — a weekend day overloaded on 2 of the last 3 weekends.
   - `avoidance` **is removed from module 5**: a task deferred 4+ times is already handled where it lives (the 3rd-deferral easing message, the 5th-deferral removal suggestion).
7. **Actions (G-64):** each pattern offers one change that writes a definite setting, always with *Not now*:
   - `heavyRun` → *"Make tomorrow a low day"* — `DayPlan(tomorrow).capacity = low`.
   - `weekendOverplan` → *"Lighten Saturday"* (or Sunday) — that weekday's `weekdayLevels` entry set to `low`.
   - `completionCollapse` → *"Lower your normal day to X"* — `mediumDayMinutes` set to the recent average, rounded to 15 minutes (the same change as the normal-day suggestion, never made on its own).
   - `habitNeglect` → *"Pause it, or make it smaller?"* — opens the habit's pause sheet (`HB-06`) or its edit form.
8. **Delivery and cooldown (G-65):** a wellbeing nudge is **an inline card**, on the Wellbeing tab and, at most once a day, on Today — **never a notification in v1** (nothing nags; there is already a per-device switch for other reminders). At most one per day; after *Not now* the same pattern isn't offered again for **7 days** (`NudgeLog.subjectKey` = pattern, plus the habit or weekday where relevant). The *Wellbeing nudges* preference turns the cards off, leaving the score.
9. **Mood note (G-66):** in v1 the mood number is used by the score and the note is **stored but not shown back**; the note is included in data export. Revisit with a History surface after launch.
