# Night Planning

> **Status: reconciled with master summary v2 — draft, needs review.** Five steps, with the Keep/Later/Drop carry-forward folded into step 1. Session state machine and supporting models are defined in [rules-engine.md](../architecture/rules-engine) (module 4).

A guided end-of-day flow: look back at the day, decide what happens to what's unfinished, reflect, plan tomorrow, check the load, confirm. It's a **state machine**, and its session is **persisted** (synced via CloudKit), so closing the app mid-flow resumes at the same step — even on another device.

Presented as a full-screen modal with a progress bar; Back is available from step 2 onward and Close is always available.

## Triggers

- The fixed **evening notification** (user-set time, default 20:00), set up during onboarding.
- User-opened any time from Today.
- If notifications are denied: an in-app banner at planning time ("Start evening planning →").

If opened after midnight, it plans for the *next* day from the user's point of view — exact rule for "tonight" vs. "tomorrow" at odd hours is open (see below).

## Steps

### 1. Review & carry forward

Two parts on one step.

**Review (read-only):** what happened today — Tasks completed vs. incomplete, Habit windows completed / partial / missed (counted habits shown honestly, e.g. "2/3 water"), Anchor `attendanceStatus`, and time actually spent against what was estimated (from focus sessions), stated plainly.

**Carry forward:** each incomplete task gets one of:

| Choice | Effect |
| ------ | ------ |
| **Keep** | Moves to tomorrow. Counts as a deferral (`deferralCount += 1`, `DeferralRecord`). |
| **Later** | Opens the date picker — Later this week / Next week / Someday / a specific date. Counts as a deferral. Someday is hidden for `medium`/`high` tasks. |
| **Drop** | `droppedAt` set. The task leaves Today for good; history is kept. |

From a task's **3rd** deferral onwards, Keep also opens the date picker with reason chips (Too much on / Not ready / No longer relevant) and the companion says "This one keeps slipping. Pick a day that actually works." If the task was `medium`/`high`, it is first eased to `low` (and the companion says so), which also makes Someday available. From the 5th, the companion suggests dropping it. Choices apply immediately and are undoable until Confirm.

Skipped automatically when there's nothing incomplete; the review part is minimal on a user's first day (see [app-flow.md](app-flow)).

### 2. Reflect

A brief wellbeing check-in: a mood on a 1–5 scale plus an optional free-text note. Feeds the wellbeing score and the Today sparkline. This is the one **optional** step — it can be skipped without blocking the flow (a skipped night simply contributes no mood data).

### 3. Plan tomorrow

Select, reorder and add Tasks and Habits for tomorrow. **This is where importance gets set**: each task in the plan starts at `low` and can be raised to `medium` or `high`; choosing `medium` or `high` reveals a due date pre-filled with tomorrow. If the plan has five or more tasks and fewer than two are `medium`/`high`, the companion prompts the user to pick one or two that matter most (a prompt, not a block). Suggested candidates come from the hidden Eisenhower lens — important-but-not-urgent (`schedule`) tasks are surfaced, since this is the moment to schedule them. **Anchors are not scheduled here**: recurring ones come from `AnchorRule`s, so this step shows tomorrow's Anchors — generated and one-off — as read-only context ("you have Fajr and the school run tomorrow"). Planning tomorrow often surfaces a fixed-time thing ("dentist at 3"), so an **Add one-off Anchor** action is available here.

### 4. Capacity & load check

Set tomorrow's capacity — `low` / `medium` / `high`. The step first shows tomorrow's **working day** (start to the day's end, default 19:00) with its fixed commitments drawn in — the school run, an appointment — and what they leave: total free time and the longest free block. The engine may suggest a level from it ("about 2 hours free — low might suit"); the user decides. It then shows **budget used** ("2h 15m of 3h", with the load state light / balanced / full / overloaded / exhausting) and, only when relevant, two quiet flags: a task longer than the longest free block ("the 90-minute review doesn't fit before the school run"), and any **overflow** past the day's end ("40 min past 19:00 — move the groceries to Wednesday?"). Overflow is soft — named, never blocked, one tap to move it — and the companion only suggests deferring *tasks* (fixed commitments and habits can't be). If some items have no duration, a quiet note says how many. Never blocks.

### 5. Confirm

Locks tomorrow's plan, writes the `DayPlan` (capacity, planned effort, load score) and schedules tomorrow's notifications. The done screen: "Good night", and a plain count of nights planned (not a streak).

## State machine

`reviewCarry → reflect → plan → capacity → confirm`. Each step's answers persist as the user moves forward, so backing up doesn't lose data.

## Skipping

- Step 2 (Reflect) is optional; everything else is required.
- Steps with nothing to do (no incomplete tasks in step 1's carry-forward) are passed through.
- Not doing Night Planning at all never loses a task — incomplete dated tasks are auto-deferred at rollover (see [task.md](../schema/task)).

## Open questions

- **"Tonight" vs. "tomorrow" at odd hours**: if the user opens Night Planning at 00:30, is `forDate` today or tomorrow? Proposal: anything before a configurable "day starts" hour (e.g. 04:00) still counts as the previous evening.
- **Undo scope**: carry-forward choices are undoable until Confirm; confirm whether that persists after the wizard is closed but before Confirm (it should — they're already applied to tasks).
- **Reflection depth**: mood 1–5 + note is the resolved shape; whether the note ever appears back to the user (e.g. in Wellbeing history) is a design question.
