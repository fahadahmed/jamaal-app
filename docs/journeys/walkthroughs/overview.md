# Journey walkthroughs

> **Status: in progress — one journey at a time.** Each walkthrough walks a journey screen by screen to test the schema and our working assumptions *before* code, and doubles as the per-screen spec Claude Design redraws from. Screen IDs are from the [Screens and flows register](../screens).

## Method

For every screen in the journey:

- **Sees / does** — what is on it and what the user can do.
- **Reads / writes** — the schema fields and engine signals it touches.
- **Assumes** — the working hypotheses the screen relies on, each checked against the schema and engine docs: ✓ holds, or **✗ G-nn** a gap.
- **Copy to respect** — lines that must be consistent with how the app works.

Then each walkthrough ends with the **data that exists afterwards** (an end-state check: if a screen's output can't be stored, that's a gap), what the next screen will show, and the gaps raised. Gaps go into the log below with a proposed resolution and a status, and a walkthrough isn't finished until each of its gaps is **Decided** or consciously deferred.

## Journeys

| # | Journey | Register flow | Status |
|---|---------|---------------|--------|
| 1 | [First launch and onboarding](01-first-launch) | F01 | **Done** — G-01 … G-10 decided and applied (G-08 open) |
| 2 | [Capture a task, and living in Today](02-capture-and-today) | F03, F04, TD-01 | **Walked** — gaps G-11 … G-20 proposed |
| 3 | A focus session | F05 | |
| 4 | An Anchor's day; creating Anchors | F06, F07 | |
| 5 | Habits: create, log, pause | F08 | |
| 6 | Night Planning | F09 | |
| 7 | Capacity and day settings | F10 | |
| 8 | Wellbeing | F11 | |
| 9 | Trial, paywall and read-only | F12 | |
| 10 | Notifications denied; problems and recovery | F13, F15 | |
| 11 | Categories | F14 | |

The order follows a new user's life (first launch first), so each journey can assume the data the earlier ones created. It can be reordered.

## Gap log

**Status:** *Proposed* (a resolution is suggested, waiting for a decision) · *Decided* · *Applied* (written into the schema, engine or journey docs) · *Open* (needs information or a separate decision first).

| ID | From | Gap | Proposed resolution | Status |
|----|------|-----|---------------------|--------|
| G-01 | J1 · OB-01/03 | **Onboarding re-runs on a second device.** The "onboarding complete" flag is per-device, but the data syncs, so an iPad would show onboarding again on top of an already-set-up account. | Add a synced `UserSettings.onboardingCompletedAt`. A first launch with iCloud waits briefly ("Checking iCloud…") for sync before deciding; a returning account gets a short "Welcome back" and skips onboarding. | **Applied** — `UserSettings.onboardingCompletedAt`; "Welcome back" on a second device |
| G-02 | J1 · OB-05 | **Reminders fire on every device.** Times are per-device local preferences and every device schedules its own notifications, so an iPhone + iPad + Mac user gets three evening prompts. A second device also starts with the default 20:00, not what the user chose. | Sync the times in `UserSettings` (`planningMinute`, `morningMinute`); keep a **per-device "send reminders here" switch** (local), defaulting on for iPhone and off for iPad and Mac. | **Applied** — synced `planningMinute` / `morningMinute`; local "Send reminders on this device" switch (iPhone on, iPad/Mac off) |
| G-03 | J1 · OB-06 | **The first task wouldn't appear on Today.** Onboarding says "something you need to do this week", but a task with no date is backlog (collapsed) and a later date isn't due today — yet Today is meant to open with something in every section. | The first task defaults to **due today** (Today or Tomorrow are the only choices), with the prompt "Something you need to do today." | **Applied** — first task defaults to due today |
| G-04 | J1 · OB-07 | **Habit presets aren't defined.** `presetKey` is a string with no catalogue: onboarding needs each preset's kind, target, window, effort and schedule. | Define the catalogue (table in the walkthrough), kept as bundled app data, not user data. | **Applied** — preset catalogue in [habit.md](../../schema/habit#presets) (Qur'an and dhikr values for the owner to correct) |
| G-05 | J1 · OB-08 | **A rule created mid-day would mark today's earlier windows missed.** Creating prayer times at 21:00 would generate Fajr → Asr for today, each already closed, and the next evaluation would finalise them as *missed* on the very first screen. | Generation never creates an instance whose window ended before the rule's `createdAt` (and the same for slots added by a later edit). Engine rule, no new field. | **Applied** — engine rule in module 3 |
| G-06 | J1 · OB-03 | **CloudKit development needs a paid developer account.** `CLAUDE.md` says the free Personal Team is fine through development, but iCloud and push can't be provisioned on it, and the project's iCloud container list is empty. Simulator builds and CI are unaffected; real-device sync testing is not. | Decide **when to enrol** (before any sync testing — Phase 3 at the latest), then create the container identifier. Correct the `CLAUDE.md` note. | **Applied** — enrol before any real-device sync testing (Phase 3 at the latest); CLAUDE.md corrected |
| G-07 | J1 · OB-04 | **Day settings can contradict each other.** Nothing forbids a working-day end before its start, or a rollover after the start. | Document the validation: `rolloverMinute < dayStartMinute < dayEndMinute`, with at least two hours between start and end. | **Applied** — validation rule on `UserSettings` |
| G-08 | J1 · OB-06 | **Category chips have no colours.** The first-task screen introduces the three default categories, but `TaskCategory.colorKey` values aren't defined. | Tied to the category-colour decision (register #9); placeholders until then. | **Open** — placeholders until the category-colour decision (register #9) |
| G-09 | J1 · OB-08 | **Prayer times can't be built until a prayer-time library is chosen** (and its method list checked against the `method` values offered). | Choose the library (the design suggested `adhan`) at the start of the Anchor work. | **Applied** — `adhan`, licence to verify at build setup |
| G-10 | J1 · OB-07 | **"Something else" can't host the full type picker in onboarding.** | In onboarding, "Something else" is a binary daily habit with just a title; the other kinds come from the Habits tab. | **Applied** — "Something else" is a binary daily habit |
| G-11 | J2 · TK-01 | **Effort can't express long tasks.** The chip "2h+" stores what? A three-hour task can't be said, yet load and the "doesn't fit a gap" flag both rely on real durations. | The four chips are shortcuts; **Other…** is a 15-minute stepper up to 8 hours. | Proposed |
| G-12 | J2 · TK-01 | **Missing estimates silently switch the warnings off.** Items without effort count as zero, so "Day is full" and the overflow flag never fire for them. | **Preselect 30m** (changeable; *No estimate* stays available), so most tasks carry an effort. | Proposed |
| G-13 | J2 · TD-01 | **"Today's load" isn't defined while the day is under way.** Module 7 says "tasks planned for the day", not which ones, and a completed task must still count toward the day (the all-done screen reads "2h 15m spent"). | Count **live tasks due on or before today, plus tasks completed today**, using actual focus time where a session exists and the estimate otherwise. Write it into module 7. | Proposed |
| G-14 | J2 · TD-01 | **Un-completing a repeating task creates two live instances** (the next one already exists). | Remove the spawned next instance if it is untouched; otherwise refuse with *"This one already repeated"*. | Proposed |
| G-15 | J2 · TK-03 | **Which deferral reason is stored for an instant deferral?** The 1st and 2nd have no chip, but `reason` has five values. | A user deferral with no chip is `reschedule`; with a chip it is that chip's value; automatic is `unspecified`. | Proposed |
| G-16 | J2 · TK-01/03 | **Quick dates have no rules.** "Later this week" and "Next week" (and the week's first day) are undefined. | Use the user's calendar's first weekday: *Later this week* = three days from now if still in the same week (otherwise not offered); *Next week* = the first day of next week. | Proposed |
| G-17 | J2 · TD-04 | **A separate Add chooser makes capture two taps.** | Drop the chooser screen: the Add sheet opens on Task, with a **Task \| Anchor** switch at the top. Update the register. | Proposed |
| G-18 | J2 · TD-01 | **No manual ordering in v1** rests on an untested hypothesis that the engine's order is good enough. | Ship without drag-ordering; treat it as a **working hypothesis to check in real use**. If wrong, `Task.sortOrder` is additive. | Proposed |
| G-19 | J2 · TK-02 | **A dropped task can't be found again** after the 5-second undo: Design draws Delete, we have a soft Drop, and there is no History screen. | Accept for v1 (history is kept in the data, just not surfaced); revisit with a History screen after launch. | **Applied** — accepted for v1; revisit with a History screen after launch |
| G-20 | J2 · TK-01/02 | **Design draws importance as "Matters 4 of 5", and "Edit / Delete".** That contradicts three-level importance and soft Drop. | Design redraws importance as low / medium / high and uses *Drop*. (A functional conflict, per the brief.) | Proposed — Design fix |
