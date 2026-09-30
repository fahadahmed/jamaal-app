# Journey 9 — Trial, paywall and read-only

> **Status: done — gaps G-68 … G-75 raised, decided and applied** (see the [gap log](overview#gap-log)). The text below is the walkthrough as first written. Register flow **F12**; screens **ST-05** (Subscription), **SB-01** (Paywall), **SB-02** (trial reminders), **SB-03** (read-only banner), **ST-08** (About, privacy, data export) and the trial banner **TD-05**. Behaviour is in [App flow → Trial and subscription](../app-flow#trial-and-subscription) and [Rules engine → module 6](../../architecture/rules-engine); this page tests it against the journeys already walked, which is where most of the questions come from: every earlier screen now has to say what it does when the trial has ended.

**In one line:** for 14 days everything works; then, unless the user subscribes, the app becomes read-only — the day can still be lived (ticking things off, timing work) but nothing new is planned — and the user can always get their data out.

**Preconditions:** Journeys 1–8 done. Example: first launch on Monday 1 Sept; the trial ends after Monday 14 Sept; the user never subscribes; later they do.

---

## During the trial

- **Sees:** nothing different. `ST-05` shows *"9 days left"*; `TD-05` carries no banner until the last days.
- **Reads:** the trial start and today's logical date; the entitlement (StoreKit).
- **Writes:** nothing except `UserSettings.firstLaunchAt` (once, at first launch; Journey 1).
- **Assumes:**
  - "days left" is computable from the start date — **✗ G-69** (the start date comes from StoreKit's original-download date with a synced fallback, but which wins, what "14 days" means against the rollover, and the day the trial ends are undefined);
  - whether the user is *subscribed* is known — **✗ G-68** (the states are described in prose: there is no definition of trial / subscribed / grace / expired, nor what is used while offline).

## SB-02 Trial reminders

- **Sees:** a short, quiet notification around days 12, 14 and 15, then nothing; afterwards the banner carries it.
- **Reads:** the planner's horizon; the entitlement; notification permission and this device's *Send reminders* switch.
- **Assumes:** reminders have definite times, and cancel on subscribing — **✗ G-73** (no time of day is set; it's unsaid whether a user who subscribes on day 13 still gets day 14's; and whether the evening planning prompt and habit nudges really stop at expiry and return on subscribing).

## SB-01 The paywall

- **Sees:** a calm full screen on the first open after the trial ends: monthly ($2.99) and yearly ($24.99), **Restore purchases**, a plain **Not now**. No countdown, no pressure.
- **Reads:** products from StoreKit; `ST-05` reaches the same screen at any time.
- **Writes:** nothing of its own; a purchase updates the entitlement, which lifts every lock.
- **Assumes:**
  - it doesn't reappear every launch — **✗ G-72** (*"on next open"* is undefined: once, daily, every time?);
  - a purchase made on another device, or a restore, lifts the locks here without relaunching — ✓ (the entitlement is per Apple ID and updates arrive as a stream);
  - subscribing while in the middle of something doesn't break it — **✗ G-74** (an open Night Planning session, a running focus session, or a half-filled form when the trial ends at the rollover).

## The read-only state: what works, what doesn't

The app-flow doc lists categories ("viewing and ticking off allowed; creating, editing, planning and capacity locked"). Walking the screens shows that the list is too coarse to implement:

- **Begin on a task** (Journey 3 left this open) — starting a timer creates a `WorkSession` (a write), but it is how a task that is allowed to be completed gets done.
- **Correcting a past habit day**, **Add minutes by hand**, **Not today / Someone else did it** on an Anchor, **Mark as done after all** — are these "ticking off"?
- **Defer / Drop** on a task, **Keep / Later** in Night Planning, the overload **Move**, **Pause** a habit, **Restore** from Archived — edits or logging?
- **Automatic rules** (the rollover's auto-deferral, `DayPlan` finalisation, Anchor generation, a repeating task's next instance): they write data without the user, and wellbeing reads it.
- **Quick capture** (the Add button) and the **capacity slider**: locked, but visible.
- **Assumes:**
  - every action is clearly on one side — **✗ G-70** (no per-action table);
  - a locked control explains itself — **✗ G-71** (the docs don't say whether a locked control is hidden, greyed out, or opens something; hidden would make the app look broken, greyed out is a mystery);
  - the engine keeps the record straight while read-only — **✗ G-72**.

## SB-03 The read-only banner, and TD-05

- **Sees:** a slim line at the top of Today: *"Your trial has ended. You can still tick things off and see everything. Subscribe to plan and add."* with **Subscribe**. Tapping it opens `SB-01`. Notifications-off and trial-ending banners share the same slot; one at a time, most pressing first.
- **Assumes:** ✓ nothing more is needed in data; it is derived from the entitlement.

## ST-05 Subscription, and ST-08 export

- **ST-05:** *"9 days left"* in the trial; *"Subscribed — renews 14 Oct"* or *"Trial ended"* after; **Manage** (the system sheet), **Restore**.
- **ST-08:** privacy statement, **Export my data** (JSON), **Delete my data**.
- **Assumes:**
  - export needs no entitlement — ✓ (always available, offline too; it serialises every model in the schema manifest);
  - deleting data is safe — **✗ G-75** (it must remove the iCloud copy as well as the local store, and confirm twice; with CloudKit a local-only delete would simply sync back).

---

## What the user sees over time

Days 1–11 nothing. Day 12: a quiet reminder and, on Today, a line in the banner slot. Day 14: the last one. Day 15, first open: the paywall. They tap **Not now** and land on Today with the slim banner; they tick off tasks, log water, mark Asr attended, start a timer on a task that is already there. They can't add a task: the Add button is still there, and tapping it says, calmly, that adding needs a subscription. In the evening there is no planning prompt; the day still rolls over and the wellbeing tab keeps filling in. A week later they subscribe: the locks lift at once, tonight's planning prompt returns, and nothing was lost.

## Data that exists afterwards (end-state check)

| Model | Change |
|---|---|
| `UserSettings` | `firstLaunchAt` only |
| everything else | unchanged by trial state; read-only is a *gate on user actions*, not a data state |

No new fields. The entitlement is StoreKit's; a last-known copy is kept locally (per device, not synced) so the app opens offline in the right state.

## Rules and changes this journey implies

If the proposals are accepted:

1. **Access state (G-68):** a pure `AccessState` in JamaalCore computed from `(now, trialStart, entitlement)`: **`trial`** (before the trial ends), **`subscribed`** (an active entitlement, including a billing grace period or retry, so a failed card never locks someone out mid-week), **`readOnly`** (otherwise). StoreKit supplies the entitlement at the app layer; the last-known entitlement is cached locally and used offline for up to **7 days**, after which an unverifiable entitlement is treated as it last was rather than locking (nothing punishes being offline); an *expired* entitlement only takes effect when StoreKit confirms it.
2. **Trial dates (G-69):** the **trial start is the earlier of** StoreKit's original-download date and `UserSettings.firstLaunchAt` (so a reinstall or a second device never restarts it). The trial is **14 logical days, day 1 being the start day**; it ends at the rollover after the 14th day. "Days left" counts logical days, so it agrees with everything else in the app.
3. **The action table (G-70):**
   - **Always allowed (living the day):** complete and un-complete tasks; log habits in every way (check, stepper, slip, *Held*, minutes by hand, correcting the last 14 days); mark Anchors attended, not today, someone else, or late; **Begin, pause, finish and stop** focus sessions, tick a note's checklist, pick a session back up; every undo; change notification and appearance preferences; export.
   - **Needs a subscription (shaping the plan):** create a task, habit, habit group, Anchor rule, one-off Anchor or category; edit any of them; **Drop or Defer** a task by hand, and Keep / Later; Night Planning and the morning card; the overload **Move**; pause, archive and restore; change the capacity level, the normal day or any day setting; complete Onboarding steps that create things.
4. **Locked controls stay visible and explain themselves (G-71):** nothing is hidden or greyed out. Tapping a locked action opens one calm sheet — *"Adding and planning need a subscription"* — with **Subscribe** and **Not now**, never the full paywall's pressure. Toolbar items that are pure planning (**Plan tomorrow**) are hidden instead, since there is nothing to explain.
5. **The engine keeps running (G-72):** auto-deferral, `DayPlan` finalisation, session auto-close, Anchor generation and a repeating task's next instance are the app keeping its own record straight, not the user shaping the plan, so they continue and wellbeing stays coherent. What stops is **notifications**: the evening planning prompt, the morning nudge, habit and guidance nudges, and — apart from the trial-end reminders — everything the planner schedules. Anchor window reminders are the one exception the owner may choose to keep (**open**, see below). The paywall appears on the **first open of each logical day** while unsubscribed, at most once a day, never in the middle of a focus session; **Not now** is final for that day.
6. **Trial reminders (G-73):** local notifications at **09:00** on days 12, 14 and 15; cancelled the moment the entitlement becomes active, and never scheduled on a device whose *Send reminders* switch is off. The evening planning prompt and habit nudges stop at expiry and return on subscribing, because the planner simply stops or starts scheduling them on the access state.
7. **Mid-flow changes (G-74):** the entitlement is checked when an action *starts*, not held per screen. A running focus session can always be finished. A Night Planning session open at the moment the trial ends is ended as skipped by the normal rollover rule, with the choices already made kept. Subscribing lifts every lock at once and the planner re-plans.
8. **Deleting data (G-75):** **Delete my data** asks twice, deletes every record locally and in iCloud, and resets the app to first launch; it is not allowed to leave the cloud copy behind to sync back. Export and delete are always available.
