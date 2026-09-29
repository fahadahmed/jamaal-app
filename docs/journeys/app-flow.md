# App flow — end to end

> **Status: new, draft — needs review.** Stitches the individual journeys ([onboarding](onboarding), [today-list](today-list), [night-planning](night-planning)) into one coherent story and lists what must be settled before screens are designed.

## The core loop

```
Onboarding → Today (day 0) → evening: Night Planning → Today (day 1) → during day → evening: Night Planning → …
```

The app is a daily rhythm: **plan at night, live from one list by day.** Everything else (Habits, Wellbeing, Settings) supports that loop.

## The companion

Jamaal is both the app and its companion voice — calm, supportive, non-judgmental. It nudges gently, notices patterns, and stays out of the way otherwise. Technically: the rules engine emits typed signals and a message-template layer phrases them (see [rules-engine.md](../architecture/rules-engine)), so the voice is consistent and testable. It appears as inline cards (Today guidance, overload warnings, "this one keeps slipping"), empty states, and notifications — never as a chat interface. There is no punitive tone: no red severity colours, misses are recorded honestly but framed gently.

## Day 0 — first launch

1. **Onboarding** ([onboarding.md](onboarding)): meet Jamaal → the idea → iCloud check → baseline capacity → notifications + evening time → first Task → first Habit → first Anchor (skippable) → ready.
2. **Today** opens with something in every section, the capacity slider set, and a card: *"Tonight, we'll plan tomorrow."*
3. During the first day the user completes, defers or ignores things. Nothing is punished.

## Day 0 evening — the first Night Planning

Triggered by the evening notification the user set up in onboarding (or the in-app banner if they declined notifications, or by opening it from Today).

- **Step 1 Review & carry forward** is light: there's little history. If everything is done or there's nothing incomplete, the carry-forward part is skipped; otherwise Keep/Later/Drop.
- **Step 2 Reflect** — first mood entry (starts the seven-day "gathering data" clock for Wellbeing).
- **Step 3 Plan tomorrow** — the step with the most value on day one: pick tasks and habits; tomorrow's Anchors appear read-only (they were generated the moment the `AnchorRule` was created).
- **Step 4 Capacity & load check** — first time the user sees load states, introduced gently.
- **Step 5 Confirm** — "Good night."

## Day 1 onward

- **Morning**: optional morning nudge. Today shows the confirmed plan filtered by capacity. Tasks are ordered by the hidden Eisenhower lens; the user never sees quadrants.
- **During the day**: tick tasks, tap Anchors attended/missed, complete habit windows (counted habits use a stepper), defer what won't fit. One guidance card at most. Streak-protection nudges as habit windows close.
- **Evening**: Night Planning again. The review now has real material and the wellbeing sparkline starts filling in.
- **If the user skips planning**: nothing is lost — incomplete dated tasks auto-defer at rollover and the 3rd-deferral date picker still catches chronic slippage.

## Navigation

Tab bar (floating pill): **Today · Habits · Wellbeing · Settings**

| Tab | Contains |
| --- | -------- |
| Today | The list; capacity slider; entry to Night Planning; task detail / add task sheets |
| Habits | Habit groups and habits; habit detail (heatmap, streaks); add habit / custom recurrence / group creation. **Proposed:** a segmented control "Habits \| Anchors" here, where Anchors lists `AnchorRule`s (add, edit, enable/disable) — see open questions |
| Wellbeing | Score, sparkline, gathering-data state, recent patterns |
| Settings | Medium-day length (default 180 min), planning and nudge times, categories, notifications warning card, iCloud, appearance |

Night Planning is a full-screen modal launched from Today (or a notification). Onboarding runs once, before the tabs.

### Adaptive layout (iPad and Mac)

One design language, same four destinations, layout adapted to width:

| | Compact width (iPhone) | Regular width (iPad, Mac) |
| --- | --- | --- |
| Navigation | Floating pill tab bar | Sidebar (adaptable tab/sidebar navigation) |
| Task detail | Bottom sheet | Trailing inspector pane beside Today |
| Add task | Bottom sheet | Popover / sheet |
| Night Planning | Full-screen modal | Centred modal, fixed comfortable width |
| Habits, Wellbeing, Settings | Full-screen pushes | Content pane with detail alongside where useful |

Mac additionally gets menu-bar commands and keyboard shortcuts (new task, open Night Planning). Design the compact layout first, then the regular-width variants of Today, task detail and Night Planning; the rest stretch. **iPhone Duo** (CLAUDE.md lists it as first-class) is still undefined — see "Gaps found in review".

## Trial and subscription

Pricing (CLAUDE.md): free download, 14-day full-access trial, then subscription only ($2.99/mo or $24.99/yr).

- **Trial**: app-managed. It starts at first launch with no payment up front and no card. Onboarding's final screen mentions it in one calm line ("14 days, everything included").
- **Trial start date** must survive reinstalls and multiple devices, so it can't live only in local storage. Likely source: the app's original-download date from StoreKit (`AppTransaction`), with a synced fallback. Implementation detail to confirm.
- **During the trial**: nothing changes. Settings has a trial-status row ("9 days left"). Reminders about the end are gentle and infrequent (e.g. days 12 and 14).
- **Day 15 — paywall**: a calm full-screen paywall on next open. Monthly and yearly options, restore purchases, and a plain "Not now".
- **Not subscribed → read-only**: Today, habits, wellbeing and history stay fully viewable, and ticking existing items off (complete a task, mark an Anchor attended, count a habit) still works so the day isn't held hostage. **Locked**: creating or editing tasks, habits, anchors and categories, Night Planning, and changing capacity. Data export always works. A slim banner explains and offers to subscribe.
- **Subscribing** lifts everything immediately; nothing is lost either way.

## Screen inventory (from v2, updated)

| Screen | Status |
| ------ | ------ |
| Today (with guidance highlight, companion card, capacity slider) | Mockup exists (legacy palette); needs Anchors section, category labels |
| Night Planning — 5 steps | Mockup exists as 5 steps *without* Anchors read-only context and with a different step order; needs re-flow |
| Task detail (normal / deferred / complete) | Mockup exists; add category, Start/Finish if approved |
| Defer date picker (quick select / calendar, reason chips) | Mockup exists |
| Add task (title, effort, notes, importance, schedule) | Mockup exists; **add category** |
| Habits overview (collapsed / expanded groups) | Mockup exists |
| Habit detail (healthy / slipping) | Mockup exists; heatmap colours need re-mapping |
| Counted-habit stepper | Mockup exists |
| Add habit (binary / counted / daily / weekdays / custom) | Mockup exists |
| Custom recurrence, habit group create/assign | Mockup exists |
| Wellbeing (high / low score, gathering data) | Mockup exists |
| Settings | Mockup exists (capacity slider + day multipliers — multipliers dropped) |
| Onboarding | Mockup exists as 5 screens; **needs** planning-time, Task/Habit/Anchor creation steps |
| Empty states, notifications-off fallback, during-day guidance | Mockups exist |
| **Anchor rules list + add/edit rule (per-type forms)** | **New — no mockup** |
| **Anchor row on Today (window, attended/missed)** | **New — no mockup** |
| **Category management (Settings)** | **New — no mockup** |
| **Repeat picker (in add task / detail)** | **New — no mockup** |
| **Paywall** | **New — no mockup** |
| **Trial status row and read-only banner** | **New — no mockup** |
| **Regular-width layouts: sidebar, Today + inspector, Night Planning modal** | **New — no mockup** |
| Icon set, app icon | Exist (legacy palette) |

Legacy mockups are in `mockups/legacy/` — layout/flow reference only; they predate ThreadsKit's cool palette.

## Coherence checklist

Resolved in this reconciliation:

- [x] Capacity model — enum for the user (their own call), minute budget from a tunable medium-day length; load counts tasks, habit windows and anchors, each with an optional duration
- [x] Night Planning step count/order — five steps, carry-forward in step 1
- [x] Night Planning session — persisted (CloudKit resume)
- [x] Rollover vs. deferral — unified as deferral with auto-defer safety net
- [x] Eisenhower — hidden, derived, drives order / capacity visibility / suggestions
- [x] Categories — editable list, label + filter only
- [x] Importance rules — three levels (low default, medium, high), set in Night Planning; medium/high require a date and never Someday; 3rd deferral eases to low; prompt when a plan has 5+ tasks and fewer than two medium/high
- [x] Notification permission — asked in onboarding, with an in-app fallback
- [x] Habit vs. Anchor boundary — salah is an Anchor; groups hold Habits only
- [x] Pricing / platforms / bundle ID — repo (CLAUDE.md) wins over v2
- [x] Trial and subscription — app-managed 14-day trial, then read-only with a calm paywall
- [x] iPad and Mac navigation — sidebar on regular width, inspector for task detail
- [x] Recurring tasks — simple repeat on Task, one live instance per series

Still open — settle before or during screen design:

- [ ] Start/Finish tracking on tasks ([task.md](../schema/task))
- [ ] Onboarding: which steps are skippable (proposal in [onboarding.md](onboarding))
- [ ] Anchor positioning wording and where users manage rules (proposal: Habits tab segment)
- [ ] `AnchorRule.configData` shapes (needed for the Anchor form screens)
- [ ] Category colours and habit heatmap colours — ThreadsKit has no sage and only two accents ([threadskit-usage](../design/threadskit-usage))
- [ ] Fonts (Fraunces + DM Sans intended, unconfirmed in ThreadsKit)
- [ ] Streaks for "N times a week" habits
- [ ] Wellbeing score composition
- [ ] Backlog visibility and manual ordering on Today
- [ ] "Tonight vs. tomorrow" at odd hours

## Gaps found in review

Not covered anywhere in the docs yet (checked by search). Grouped by what they would change.

**Would change screens or journeys**

- ~~**Trial and paywall.**~~ **Resolved** — see "Trial and subscription". Still open: what the evening Night Planning notification does after the trial ends (proposal: stops), and whether the trial-end reminders are notifications or in-app only.
- ~~**Adaptive layout.**~~ **Resolved for iPad and Mac** — see "Adaptive layout". **iPhone Duo** ("first-class" in CLAUDE.md) is still undefined: what device or mode does it mean, and what changes for it?
- ~~**Recurring tasks.**~~ **Resolved** — simple repeat on Task, see [task.md](../schema/task#repeating-tasks).
- **Calendar and other apps.** The stated goal is to stop bouncing between reminder, task and calendar apps, but nothing says whether Jamaal reads calendar events, imports Reminders, or ignores them.
- **Habit pause.** No way to pause a streak for travel or illness; matters for a non-punitive tone.
- **Quick capture and system surfaces.** No widgets, share extension, App Intents/Siri, or Live Activities — likely important for a "Today" app, and they shape what data must be reachable outside the app.
- **Privacy, export and account.** v2 called the app "privacy-first"; there is no data export/delete or privacy journey (also needed for App Store submission).

**Would change the schema or engine**

- **CloudKit duplicates.** CloudKit forbids unique constraints, so two devices can each create the same thing: the three default categories on first launch, generated Anchor instances, a `DayPlan` per date, the automatic day-rollover deferral (double-incrementing `deferralCount`). The engine must be idempotent, with a dedup strategy, before implementation.
- **CloudKit schema is effectively append-only once deployed to production.** Every field name in these docs should be considered final before the first production schema deploy.
- **Editing rules.** What happens to future instances when an `AnchorRule` is edited or disabled, and how deleting a category or archiving a habit group shows up in history, aren't specified.
- **Anchor reminders.** Module 6 mentions during-day guidance for upcoming anchors, but there's no per-rule lead time or reminder setting.
- **Day boundary.** "Tonight vs. tomorrow" (already open) also affects when auto-deferral and `DayPlan` closing run, and whether they run at all when the app hasn't been opened.

**Quality and reach**

- **Accessibility.** Beyond a "larger text" preference in v2, nothing on Dynamic Type, VoiceOver for the custom components (capacity slider, completion ring, heatmap), or colour-only states — the heatmap and load states must not rely on colour alone, and ThreadsKit's palette is small.
- **Localisation.** No RTL layout, Arabic strings, or Hijri-date handling, though Islamic practice presets are a stated use case and the name is Arabic.
- **Roadmap docs.** `docs/roadmap/phases.md`, `docs/architecture/overview.md` and `docs/Home.md` are empty, with the phase 2 pace checkpoint due end of October 2026.
