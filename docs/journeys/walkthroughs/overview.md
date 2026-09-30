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
| 1 | [First launch and onboarding](01-first-launch) | F01 | **Walked** — gaps G-01 … G-10 |
| 2 | Capture a task, and living in Today | F03, F04, TD-01 | next |
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
| G-01 | J1 · OB-01/03 | **Onboarding re-runs on a second device.** The "onboarding complete" flag is per-device, but the data syncs, so an iPad would show onboarding again on top of an already-set-up account. | Add a synced `UserSettings.onboardingCompletedAt`. A first launch with iCloud waits briefly ("Checking iCloud…") for sync before deciding; a returning account gets a short "Welcome back" and skips onboarding. | Proposed |
| G-02 | J1 · OB-05 | **Reminders fire on every device.** Times are per-device local preferences and every device schedules its own notifications, so an iPhone + iPad + Mac user gets three evening prompts. A second device also starts with the default 20:00, not what the user chose. | Sync the times in `UserSettings` (`planningMinute`, `morningMinute`); keep a **per-device "send reminders here" switch** (local), defaulting on for iPhone and off for iPad and Mac. | Proposed — needs a decision |
| G-03 | J1 · OB-06 | **The first task wouldn't appear on Today.** Onboarding says "something you need to do this week", but a task with no date is backlog (collapsed) and a later date isn't due today — yet Today is meant to open with something in every section. | The first task defaults to **due today** (Today or Tomorrow are the only choices), with the prompt "Something you need to do today." | Proposed |
| G-04 | J1 · OB-07 | **Habit presets aren't defined.** `presetKey` is a string with no catalogue: onboarding needs each preset's kind, target, window, effort and schedule. | Define the catalogue (table in the walkthrough), kept as bundled app data, not user data. | Proposed — needs review |
| G-05 | J1 · OB-08 | **A rule created mid-day would mark today's earlier windows missed.** Creating prayer times at 21:00 would generate Fajr → Asr for today, each already closed, and the next evaluation would finalise them as *missed* on the very first screen. | Generation never creates an instance whose window ended before the rule's `createdAt` (and the same for slots added by a later edit). Engine rule, no new field. | Proposed |
| G-06 | J1 · OB-03 | **CloudKit development needs a paid developer account.** `CLAUDE.md` says the free Personal Team is fine through development, but iCloud and push can't be provisioned on it, and the project's iCloud container list is empty. Simulator builds and CI are unaffected; real-device sync testing is not. | Decide **when to enrol** (before any sync testing — Phase 3 at the latest), then create the container identifier. Correct the `CLAUDE.md` note. | Open — needs a decision |
| G-07 | J1 · OB-04 | **Day settings can contradict each other.** Nothing forbids a working-day end before its start, or a rollover after the start. | Document the validation: `rolloverMinute < dayStartMinute < dayEndMinute`, with at least two hours between start and end. | Proposed |
| G-08 | J1 · OB-06 | **Category chips have no colours.** The first-task screen introduces the three default categories, but `TaskCategory.colorKey` values aren't defined. | Tied to the category-colour decision (register #9); placeholders until then. | Open |
| G-09 | J1 · OB-08 | **Prayer times can't be built until a prayer-time library is chosen** (and its method list checked against the `method` values offered). | Choose the library (the design suggested `adhan`) at the start of the Anchor work. | Open |
| G-10 | J1 · OB-07 | **"Something else" can't host the full type picker in onboarding.** | In onboarding, "Something else" is a binary daily habit with just a title; the other kinds come from the Habits tab. | Proposed |
