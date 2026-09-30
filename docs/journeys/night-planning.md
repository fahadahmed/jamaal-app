# Night Planning

> **Status: reshaped to the design's five steps — draft, needs review.** Review today → Carry forward → Build tomorrow → Check the load → Close the day. Session state machine and supporting models are in [rules-engine.md](../architecture/rules-engine) (module 4).

A guided end-of-day flow: look back at the day, decide what happens to what's unfinished, build tomorrow around its fixed commitments, check the load, close the day. It's a **state machine**, and its session is **persisted** (synced via CloudKit), so closing the app mid-flow resumes at the same step — even on another device.

On phone the five steps are five screens in a full-screen modal with a progress bar; Back is available from step 2 onward and Close is always available. On wide layouts (iPad, Mac, Duo unfolded) they are five stops on **one canvas** — a step rail beside a working area — so the user always sees where they are without losing the step they're on.

## Triggers

- The fixed **evening notification** (user-set time, default 20:00), set up during onboarding.
- User-opened any time from Today.
- If notifications are denied: an in-app banner at planning time ("Start evening planning →").

If opened after midnight, it plans for the next working day from the user's point of view — exact rule for "tonight" vs. "tomorrow" at odd hours is open (see below).

## Steps

### 1. Review today

What happened today, read-only: tasks completed vs. incomplete, habit windows completed / partial / missed (counted habits shown honestly, e.g. "2/3 water"), Anchor attendance, and time actually spent against what was estimated (from focus sessions), stated plainly with no praise or blame.

At the end sits one **optional mood line**: a 1–5 tap and an optional free-text note ("How was today?"). It can be ignored without blocking anything; a night with no mood just contributes none. It feeds the wellbeing score as one input alongside behaviour.

On a user's first day the review is minimal (see [app-flow.md](app-flow)).

### 2. Carry forward

Each incomplete task gets one of:

| Choice | Effect |
| ------ | ------ |
| **Keep** | Moves to tomorrow. Counts as a deferral (`deferralCount += 1`, `DeferralRecord`). |
| **Later** | Opens the date picker — Later this week / Next week / Someday / a specific date. Counts as a deferral. Someday is hidden for `medium`/`high` tasks. |
| **Drop** | `droppedAt` set. The task leaves Today for good; history is kept. |

From a task's **3rd** deferral onwards, Keep also opens the date picker with reason chips (Too much on / Not ready / No longer relevant) and the companion says "This one keeps slipping. Pick a day that actually works." If the task was `medium`/`high`, it is first eased to `low` (and the companion says so), which also makes Someday available. From the 5th, the companion suggests dropping it. Choices apply immediately and are undoable until the day is closed.

The wide layout uses the same three choices per task — leftovers are *not* silently sent to the backlog. Skipped automatically when there is nothing incomplete.

### 3. Build tomorrow

The step **opens on the shape of tomorrow**, before any task is offered:

- **Tomorrow's working day** (start to the day's end, default 19:00) with its **fixed commitments** drawn in — recurring Anchors and one-offs, such as the school run or an appointment. An **Add one-off Anchor** action is available, since planning often surfaces "dentist at 3".
- The **free gaps** between them, **named by what surrounds them**: "before the school run · 2h 40m free", "between the school run and Maghrib · 3h 05m", "after Maghrib". With no fixed commitments the day is one gap. Phone shows the gaps as a list; wide layouts show a proportional timeline so the size of each gap is visible. Only commitments inside the working day count, so prayers after the day's end don't create gaps.

Below that, **select, reorder and add Tasks and Habits** for tomorrow (paused habits don't appear). Tasks are *not* assigned to gaps: they are a plain ordered list, and the planner **flags any task that won't fit** in any gap ("the 90-minute review is longer than tomorrow's longest gap"). It is a flag, never a block.

**This is where importance gets set**: each task starts at `low` and can be raised to `medium` or `high`; choosing `medium` or `high` reveals a due date pre-filled with tomorrow. If the plan has five or more tasks and fewer than two are `medium`/`high`, the companion prompts the user to pick one or two that matter most (a prompt, not a block). Suggested candidates come from the hidden Eisenhower lens — important-but-not-urgent (`schedule`) tasks are surfaced, since this is the moment to schedule them.

### 4. Check the load

Set tomorrow's capacity — `low` / `medium` / `high`. The step shows what tomorrow leaves (total free time and the longest gap) and the engine may suggest a level ("about 2 hours free — low might suit"); the user decides. It then shows **budget used** ("2h 15m of 3h", with the load state light / balanced / full / overloaded / exhausting) and, only when relevant, **overflow** past the day's end ("40 min past 19:00").

When the day is overfull the companion offers one specific move — "Groceries could wait until Wednesday. Want me to move it?" — with **Move** and **Keep as planned**. Overflow is soft: named, never blocked, one tap to move. It only ever suggests deferring *tasks* (fixed commitments and habits can't be). If some items have no duration, a quiet note says how many. Never blocks.

### 5. Close the day

Locks tomorrow's plan, writes the `DayPlan` (capacity, planned task minutes, free minutes, load score) and schedules tomorrow's notifications. The done screen says plainly what was planned ("Tomorrow is ready. Three tasks, 3h exactly. Put the phone down."), with a plain count of nights planned (not a streak) and a "Good night" button.

## Skip tonight

**Skip tonight** is available at every step. It closes the flow without a plan:

- Nothing is lost: incomplete dated tasks auto-defer at rollover as usual (see [task.md](../schema/task)), and carry-forward choices already made stay applied.
- No `DayPlan` is written; tomorrow simply uses the user's default level.
- **If no plan was confirmed for today**, the morning list shows **one quiet card** — "No plan for today — two minutes to pick?" — that opens a shortened Build tomorrow for today. No guilt, no missed-night count, no streak, and the card doesn't repeat if dismissed.

## State machine

`review → carry → build → load → close`, plus a `skipped` end state. Each step's answers persist as the user moves forward, so backing up doesn't lose data.

## Skipping

- The mood line is optional; everything else is required *unless the whole night is skipped* (above).
- Steps with nothing to do (no incomplete tasks in *Carry forward*) are passed through.
- Not doing Night Planning at all never loses a task.

## Open questions

- **"Tonight" vs. "tomorrow" at odd hours**: if the user opens Night Planning at 00:30, is the plan for today or tomorrow? Proposal: before the working day's start (default 08:00) the plan is for *today's date*, otherwise tomorrow. This interacts with midnight being the hard rollover for auto-deferral (a session run at 00:30 sees tasks that may already have auto-deferred, and a Keep would count twice); the fix belongs with the day-boundary decision.
- **Gap naming at the edges**: how to name the first gap when the day starts with a commitment, and what to show when many small commitments create many small gaps (proposal: hide gaps under about 20 minutes).
- **Mood note visibility**: whether the free-text note is ever shown back to the user (e.g. in Wellbeing history) is a design question.
- **Undo scope**: carry-forward choices are undoable until the day is closed; confirm this persists if the wizard is closed but not finished (it should — they're already applied to tasks).
