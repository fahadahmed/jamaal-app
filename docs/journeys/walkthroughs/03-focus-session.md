# Journey 3 — A focus session

> **Status: done — gaps G-21 … G-26 raised, decided and applied** (see the [gap log](overview#gap-log)). The text below is the walkthrough as first written, with the proposals it raised. Register flow **F05**, screens **FS-01 … FS-07** (and **TD-06**). Behaviour is in [Task → Focus sessions](../../schema/task#focus-sessions-begin--pause--finish), [Habit → Timed habits](../../schema/habit#timed-habits) and [Rules engine → module 8](../../architecture/rules-engine); this page tests it against the schema and engine. `FS-08` (Lock Screen activity) is v1.1 and out of scope.

**In one line:** the user taps Begin on a task, a quiet chip follows them around the app while they work, they pause, overrun, finish or stop, and the real time is recorded so Night Planning and the load can be honest.

**Preconditions:** Journey 2 is done. Example: today holds *"Draft the architecture review"* (60 min, due today) and a timed habit *"Qur'an reading"* (15 min target).

---

## Entry points

A session starts from three places: the **Begin** button on the *"Start here"* guidance card on Today (`TD-01`), **Begin** in the task detail (`TK-02`), and **Begin** on a timed habit's row (`HB`).

- **Writes (every Begin):** a `WorkSession` — `startedAt = now`, `day = logicalDate(now)`, `estimateMinutes` (a snapshot of `Task.effortMinutes`, or `nil`), `outcome = running`, and `task` **or** `habitWindow`.
- **Reads:** whether a session is already live (`outcome = running`, `endedAt = nil`).
- **Assumes:**
  - Begin needs nothing else — ✓ (a task that is live; completed and dropped tasks don't offer Begin);
  - Begin on a task that is not due today is fine — ✓ (it counts toward today once completed today; while running it simply isn't yet in "due today");
  - a second Begin is handled — ✓ (`FS-07`).
- **Read-only state:** Begin is proposed as always allowed after the trial (Journey 9, G-70).

## FS-01 The session chip

- **Sees:** a slim chip above the tab bar on **every tab**: the task title and a count-up timer (monospaced digits, so the numerals don't jitter). It is **filled only while a session is live**. On regular width and Duo it sits in the right-hand panel.
- **Reads:** the live `WorkSession` (elapsed is `(endedAt ?? now) − startedAt − pausedSeconds − (paused so far)`), and nearby Anchors (module 8).
- **Does:** taps it to open `FS-02`.
- **Assumes:**
  - the chip survives a killed app and another device — ✓ (everything derives from `startedAt`; the session syncs, so the chip also appears on the user's iPad);
  - the chip can warn about an approaching Anchor without blocking — **✗ G-21** (which events surface is under-specified: the docs say "Maghrib in 12 min", but the costly moment is an *open* window that is about to *close*).
- **Copy to respect:** neutral always. No red, no alarm, no "you're over".

## FS-02 The focus screen

- **Sees:** the timer numeral (display face, monospaced digits), the task title, *"of 60 min"*, the task's **note as a tappable checklist** beneath it, and **Pause** and **Finish**. A habit session shows the habit and its target, with no note.
- **Does:** ticks checklist items; taps Pause, Finish, or closes it (the session keeps running).
- **Writes:** ticking a box edits `Task.notes` (the markdown text); **Pause** sets `pausedAt`; **Resume** adds `now − pausedAt` to `pausedSeconds` and clears `pausedAt`.
- **Assumes:**
  - elapsed ignores paused time — ✓;
  - a session left paused or running overnight is closed — ✓ (auto-closed at the day rollover, with the partial time logged);
  - a manual change of the device clock can't corrupt a session — ✓ with care (elapsed clamps at zero; time zones don't matter because the fields are instants).

## FS-03 Overrun and FS-04 Paused

- **Overrun:** the same screen, the timer still counting (*"75 of 60 min"*); nothing changes — no colour, alarm, nudge or haptic. **Reads:** `elapsed > estimateMinutes`.
- **Paused:** the same screen with the timer held and **Resume** in place of **Pause**; only an explicit Pause pauses (backgrounding never does).
- **Assumes:** no estimate → no "overrun" — ✓ (the state only exists when `estimateMinutes` is set; a task with no estimate just counts up).

## FS-05 Finish — and stopping without finishing

- **Sees:** a sheet showing **actual against estimate** (*"74 min · estimated 60"*), an optional one-line note, and the choices. The current docs give it a single outcome, **Finish**, plus **abandon** in the state machine — but no screen reaches abandon (**✗ G-22**). The proposal: the sheet has two buttons — **Done** (the task is complete) and **Stop for now** (time logged, task stays live) — because being interrupted is the commonest way a session ends.
- **Writes — Done:** `outcome = finished`, `endedAt`, `actualSeconds` (elapsed minus pauses); `Task.isCompleted`, `completedAt = endedAt`; an optional timestamped line **appended** to `Task.notes`; for a repeating task the next instance is created. **Stop for now:** `outcome = abandoned`, `endedAt`, `actualSeconds`; the task is untouched.
- **Assumes:**
  - the partial time is kept either way — ✓ ("abandoning is not failing");
  - finishing or stopping from the chip, the screen or (v1.1) the Lock Screen all do the same — ✓.

## FS-06 Undo toast

- **Sees:** *"Done · Undo"* for five seconds.
- **Writes (Undo):** reopens the session (`endedAt = nil`, `outcome = running`) and un-completes the task (and, for a repeating task, removes the untouched next instance — [rule](../../schema/task#repeating-tasks)).
- **Assumes:** the five seconds of the toast don't count as work — **✗ G-23** (reopening as written would count them as running time; they should be added to `pausedSeconds`).

## FS-07 Switching task while one is running

- **Sees:** tapping Begin on a second task raises a sheet naming the running one: *"You're timing 'Draft the architecture review'. Settle it first."* — **Done · Defer to tomorrow · Drop** (for a habit session, only **Log it**). Today's docs omit the *Stop for now* choice that interruptions need (**G-22**).
- **Writes:** `finished`, `deferred` (a normal deferral with its count and record), `dropped` (`droppedAt`), or — with G-22 — `abandoned`. The elapsed time is logged whichever is chosen; the new session only starts afterwards.
- **Assumes:**
  - only one session is ever live — ✓ (engine-enforced; on a cross-device clash the later-started session is closed as `abandoned` and its time logged);
  - the user learns of that clash — **✗ G-26** (nothing tells them the other device's timer was stopped).

## Resolving a task while it is being timed

- **Does:** ticks the check on the running task on Today, or taps *Mark done*, *Defer* or *Drop* in its detail while its session is live.
- **Assumes:** the session and the task can't disagree — **✗ G-25** (nothing says what happens to the live session; left running it would outlast a completed task).

## TD-06 After a session is auto-closed

- **Sees:** at the day rollover a session still running is closed at the boundary instant; the next day's Today opens with **one row** offering to pick the task back up (*"Pick up 'Draft the architecture review'"*).
- **Reads:** yesterday's `autoClosed` session whose task is still live; no storage is needed (the row is derived, and disappears once the task is acted on or the day ends).
- **Writes (tap):** a new `WorkSession` for the same task. The earlier session stays as history.
- **Assumes:** the task isn't charged a deferral — ✓ (carried over without counting one).

## A timed habit's session

- **Begin / chip / focus screen / finish** work the same way. **Finish** adds the minutes to that day's `HabitEntry.amount` for the window (creating the entry, with its `target` snapshot, if none exists).
- **Assumes:**
  - several sessions in a day accumulate — ✓;
  - minutes can also be added by hand — ✓ (`HB-09`);
  - the entry's `amount` is exact — **✗ G-24** (rounding each session to whole minutes drifts; and a hand-added figure and timed figures both land in one integer, so neither can be recomputed).

---

## What the user sees at each point

At Begin the chip appears *"Draft the architecture review · 0:00"*. Twenty minutes in, after a pause, it reads *"0:20"* and the meter on Today is unchanged (the load counts the task, not the clock). After 60 minutes the chip keeps counting with no change in look. Finishing at 74 minutes shows *"74 min · estimated 60"*; Done marks the task complete, and the meter now uses **74 minutes** for that task instead of the 60-minute estimate (the load rule counts actual focus time once a session exists).

## Data that exists afterwards (end-state check)

| Model | Change |
|---|---|
| `WorkSession` | + 1 per Begin: `startedAt`, `day`, `estimateMinutes`, `pausedSeconds`, `endedAt`, `actualSeconds`, `outcome` (`finished` / `abandoned` / `deferred` / `dropped` / `autoClosed`) |
| `Task` | `isCompleted` / `completedAt` on Done; a timestamped line appended to `notes`; `deferralCount` on Defer; `droppedAt` on Drop |
| `HabitEntry` | timed habit: `amount` (minutes) for that day and window |
| `DeferralRecord` | + 1 when a session is settled with Defer |

Every row is storable now. One small **additive** change is proposed (G-24): a new raw value for `WorkSession.outcome`.

## Rules and changes this journey implies

If the proposals are accepted:

1. **Chip messages (G-21):** the chip shows the single most urgent line — an open, pending Anchor **closing soon** (*"Asr closes in 10 min"*) takes priority over a **fixed** Anchor's window **opening** within 30 minutes (*"Maghrib in 12 min"*). Flexible Anchors (bin night and the like) never appear. Neither blocks anything.
2. **Finish sheet and settle sheet (G-22):** *Done* and **Stop for now** (and, on the settle sheet, Defer and Drop for a task); a habit's settle sheet is *Log it* / *Stop for now*.
3. **Undo (G-23):** reopening a finished session adds the time since `endedAt` to `pausedSeconds`.
4. **Timed habit minutes (G-24):** the day's `HabitEntry.amount` is **recomputed** from that window's sessions — `round(total seconds ÷ 60)`, never per-session — and **minutes added by hand are stored as a finished session** with a new raw value `WorkSession.outcome = manual` (no start or end time of its own). Everything that feeds the entry is then a session, it can be recomputed at any time, and two devices converge by summing rows instead of overwriting a counter.
5. **Resolving a task with a live session (G-25):** the session closes with the matching outcome — *done* → `finished`, *defer* → `deferred`, *drop* → `dropped` — and its time is logged.
6. **Conflict notice (G-26):** if a session was closed as `abandoned` because another device started one first, the user sees a single quiet line on next open — *"Two timers were running; the later one was stopped and its time logged."*
