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
| Settings | Capacity defaults, planning and nudge times, categories, notifications warning card, iCloud, appearance |

Night Planning is a full-screen modal launched from Today (or a notification). Onboarding runs once, before the tabs.

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
| Icon set, app icon | Exist (legacy palette) |

Legacy mockups are in `mockups/legacy/` — layout/flow reference only; they predate ThreadsKit's cool palette.

## Coherence checklist

Resolved in this reconciliation:

- [x] Capacity model — enum for the user, minute budget + effort estimates for the engine
- [x] Night Planning step count/order — five steps, carry-forward in step 1
- [x] Night Planning session — persisted (CloudKit resume)
- [x] Rollover vs. deferral — unified as deferral with auto-defer safety net
- [x] Eisenhower — hidden, derived, drives order / capacity visibility / suggestions
- [x] Categories — editable list, label + filter only
- [x] Notification permission — asked in onboarding, with an in-app fallback
- [x] Habit vs. Anchor boundary — salah is an Anchor; groups hold Habits only
- [x] Pricing / platforms / bundle ID — repo (CLAUDE.md) wins over v2

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
