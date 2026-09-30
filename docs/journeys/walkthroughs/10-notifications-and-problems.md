# Journey 10 — Notifications denied; problems and recovery

> **Status: done — gaps G-76 … G-83 raised, decided and applied** (see the [gap log](overview#gap-log)). The text below is the walkthrough as first written. Register flows **F13** (notifications denied) and **F15** (problems); screens **SY-01**, **ST-03**, **ST-06**, **SY-05**, **OB-03** and **AN-07**. Behaviour is in [Rules engine → module 6](../../architecture/rules-engine) and [Architecture → Persistence and sync](../../architecture/overview); this page tests what the app does when the things it depends on — permission to notify, iCloud, the local store, newer data from another device — are not as hoped.

**In one line:** when a reminder can't be delivered, or sync, storage or another device's data misbehaves, the app keeps working, says plainly what is wrong only when it matters, and never loses anything.

**Preconditions:** Journeys 1–9 done. Examples: notification permission denied in onboarding; an iPhone and an iPad on the same iCloud account; a prayer rule with at-start reminders; a habit with a reminder; the user later signs out of iCloud.

---

# Part A — Notifications denied (F13)

## OB-05 and the permission states

- **Sees:** in onboarding, the permission request framed around the evening reminder. Later, **ST-03** (*Notifications & times*): the planning and morning times, the **Send reminders on this device** switch and a **warning card** if notifications are off, with a link to system settings.
- **Reads:** the system's authorisation status for this device; the local switch.
- **Assumes:**
  - "denied" is one state — **✗ G-76** (there are really three: *not asked yet* — the user skipped `OB-05`; *denied*; and *turned off later in system Settings*. Each needs a different button, and the app finds out about the last only by checking);
  - the switch and the permission combine sensibly — **✗ G-76** (the switch can be **on** while the permission is **off**, or **off** by the iPad/Mac default while permission is fine).

## SY-01 The fallbacks

- **Sees:** *"an in-app banner at planning time and a warning card in `ST-03`"*.
- **Reads:** the time, whether tonight is planned or skipped, the permission state.
- **Assumes:**
  - the banner is the only thing lost — **✗ G-77** (denied notifications also silence **Anchor reminders** — a prayer rule's at-start reminder, the point of the default — habit reminders, the morning nudge and the trial-end reminders; only the planning prompt has a fallback, so a user who set up prayer reminders is left silently without them);
  - the banner and the quiet **Plan tomorrow** row from Journey 6 (G-45) are different things — **✗ G-77** (the register treats them as one: one is an invitation to plan, always available; the other explains why no reminder arrived, and should appear only when a reminder the user wanted is affected);
  - a banner that returns every evening is acceptable — **✗ G-77** (no limit or *don't remind me* exists);
  - a device with *Send reminders* **off** by choice gets the banner — **✗ G-77** (an iPad that's deliberately quiet would nag).

## Tapping a notification

- **Does:** taps the planning prompt, an Anchor or habit reminder, or a trial reminder.
- **Assumes:** each opens something sensible — **✗ G-78** (no routing is defined: the planning prompt should open Night Planning, an Anchor reminder should land on its row, a trial reminder on `ST-05`, and nothing should open a locked screen after the trial).

---

# Part B — Problems and recovery (F15)

## iCloud after onboarding (ST-06, SY-05)

- **Sees:** `ST-06` — *signed in* or a problem; `SY-05` — a problem state on Today.
- **Reads:** the account status and, from CloudKit's event stream, the most recent sync error.
- **Assumes:**
  - problems are told apart from normal life — **✗ G-79** (offline isn't a problem; *signed out*, *restricted*, *iCloud storage full* and a long run of sync failures are; the docs only say "surfaced only when there is a problem" without defining it);
  - the user can't lose data by changing or leaving their iCloud account — **✗ G-80** (when the account signs out or changes, the synced store can be reset or re-associated by the system; what the user sees and what survives isn't defined, and it can't be verified without a provisioned container).

## A local store that won't open

- **Sees:** nothing defined.
- **Assumes:** the store always opens — **✗ G-81** (a failed migration or damaged file would make the app crash on launch, with no way back; the iCloud copy would be fine).

## Data from a newer version

- **Reads:** a row written by a newer app on another device.
- **Assumes:**
  - an unreadable Anchor rule is protected — ✓ (`AN-07`: never generated, never deleted);
  - anything else from a newer version is safe — **✗ G-82** (the schema rule says new raw-string values are additive and safe to *store*, but an older app *reading* an unknown `outcome`, `kind`, `status` or `sourceKey` has no defined fallback, and it would be easy to crash or delete).

## Two devices at once

- **Reads:** duplicate rows created on two devices (two `UserSettings`, two sessions, two `DayPlan`s for a date).
- **Assumes:**
  - the engine deduplicates quietly — ✓ (keys in the schema overview; earliest wins);
  - a timer clash tells the user once — ✓ (Journey 3, G-26: *"Two timers were running; the later one was stopped and its time logged."*);
  - the register says the same — **✗ G-83** (`F15` still says the settle sheet is shown on next open, which Journey 3 replaced with the quiet line).

## Other problems already covered

An Anchor rule that can't be read (`AN-07`, Journey 4), location declined for prayer times (city search; device mode falls back to the stored coordinate), an empty Today, and a session left running overnight (Journey 3) all behave as already decided.

---

## What the user sees over time

Denying notifications in onboarding costs nothing on day one: Today works, and after the planning time a quiet row invites them to plan. A week later they add prayer times with at-start reminders; the form says, in one line, that notifications are off and reminders won't arrive, with a link to turn them on. Nothing else nags. On the iPad, where reminders are off by default, nothing is said at all. When they sign out of iCloud to fix something, Settings says so plainly and the data stays on the device; signing in again resumes sync. A tap on an evening reminder opens Night Planning directly.

## Data that exists afterwards (end-state check)

| Model | Change |
|---|---|
| all synced models | unchanged by any of these states |
| local preferences | banner dismissals, the last-known permission state, the *Send reminders* switch (not synced) |

No schema change. These are app-layer states, read from the system and stored locally.

## Rules and changes this journey implies

If the proposals are accepted:

1. **Permission states (G-76):** the app reads the authorisation status on launch and every foreground. **Not asked** → a *Turn on reminders* button that shows the system prompt in context; **denied** (or turned off later) → a link to system Settings; **granted** → nothing. The planner schedules only when this device's switch is **on and** permission is granted; ST-03 shows both honestly (*"Reminders are on for this device, but notifications are off in Settings"*).
2. **What denial costs, and where it's said (G-77):** the **warning card in ST-03** lists what isn't being delivered (planning prompt, Anchor reminders, habit reminders, morning nudge). Where a reminder is *configured* — an Anchor rule's reminder row, a habit's reminder row — a single quiet line says notifications are off, with the link. The **Today banner** appears **only** when this device's switch is on and permission is off, at most **once per logical day**, dismissible for that day, with *Don't remind me* storing a local preference. It is distinct from the always-available **Plan tomorrow** row (G-45). A device whose switch is off by choice shows no banner.
3. **Routing (G-78):** a **planning** notification opens Night Planning for the target date (ignored, with the ordinary sheet, if the app is read-only); an **Anchor** or **habit** reminder opens Today scrolled to that row; a **trial** reminder opens `ST-05`. v1 notifications have no action buttons, and all use the default interruption level (nothing is time-sensitive; Focus modes are respected).
4. **iCloud problems (G-79):** `ST-06` shows one of *Signed in* · *Not signed in* · *iCloud is restricted* · *iCloud storage is full* · *Sync is having trouble* (three consecutive failures over at least a day). **Offline is never a problem.** Only the last four surface outside Settings, as one quiet line on Today (`SY-05`), dismissible, returning after a day if still true; every message states the same two facts — *your data is safe on this device* and what would fix it.
5. **Account changes (G-80):** the app listens for account changes; on a sign-out or a different account it **pauses rollover and sync-dependent work**, shows a plain *"Your iCloud account changed"* notice with **Export my data** first, and only then continues. Because the system's behaviour when an account leaves can't be confirmed without a provisioned container, a **spike on a real device** (Phase 3, paid programme) must verify it before TestFlight; this journey records the requirement rather than the answer.
6. **A store that won't open (G-81):** launch catches a container failure and shows a recovery screen instead of crashing: **Try again**, and **Reset this device's data** (two confirmations; the iCloud copy downloads again). It never resets silently and never touches the iCloud copy.
7. **Unknown values (G-82):** every raw-string read falls back to a neutral, inert case (`unknown`): the row is **kept, never deleted or rewritten**, shown neutrally or hidden, excluded from counts and the score, and the older app shows a quiet *"Update Jamaal to see this"* where a row can't be displayed.
8. **The register (G-83):** `F15` is corrected to say the timer clash is told once by a quiet line, not a settle sheet.
