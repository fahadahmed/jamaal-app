# Roadmap — phases

> **Status: proposal, needs review.** The phase numbering from the earlier planning was not recorded in this repo. The only fixed points I found are the **Phase 2 pace checkpoint at the end of October 2026** and the launch window below (both from `CLAUDE.md`). The phases themselves are a proposal built from the decisions made so far; confirm or reshape them.

## Constraints

- About **10–20 hours a week**, alongside full-time work.
- **Launch target:** as early as late December 2026 (the January resolution surge), or realistically around **March 2027** at this pace.
- iOS, iPadOS and macOS together in v1. A native Android app (Kotlin, not Flutter) is a later, separate effort after iOS traction.
- The paid Apple Developer Program ($99/year) is only needed at TestFlight-with-others, production CloudKit and App Store submission time.

## Phase 1 — Docs and flows first *(done)*

Schema, journeys and the rules engine are specified; the earlier planning was reconciled into the repo; the design project was reviewed and its decisions folded in; the schema is a freeze candidate ([Schema overview](../schema/overview)). All eleven [journey walkthroughs](../journeys/walkthroughs/overview) are done: 89 gaps found, decided and applied, tested against the schema, which needed no further fields after the freeze work.

## Phase 2 — Foundations *(current; pace checkpoint end of October 2026)*

- ~~Wire ThreadsKit 1.1.0 or later into `Jamaal.xcodeproj`.~~ **Done.**
- ~~Add a build-and-test workflow (`ci.yml`).~~ **Done** (`JamaalCore` tests and the app's unit tests on the `xcode-27` runner).
- ~~Day boundary first~~ **Done:** `CalendarDate` (floating calendar dates) and `DayBoundary` (logical date, catch-up days, Night Planning's target day) are in `JamaalCore`, tests first.
- ~~ThreadsKit 2.0.0 with the palette contract, the category colours, space, elevation, motion and the bundled fonts, then bump the app's dependency.~~ **Done.**
- ~~Implement the 14 models in `JamaalCore` with a versioned schema, tests first.~~ **Done:** the 14 `@Model` classes, typed raw values with the unknown-value rule, `VersionedSchema` V1 with a migration plan, and a container factory, with Swift Testing coverage (defaults, relationships, delete rules, CloudKit constraints). Not yet verified against a real CloudKit container (needs the paid programme).
- ~~First-launch seeding and the CloudKit dedup rules~~ **Done** (`Seeding`, `Dedup` in `JamaalCore/RulesEngine`, idempotent, with mutation-checked tests).
- ~~Capacity and load calculations (budgets, load state, weekday defaults) and the day rollover step~~ **Done** (`CapacityLoad`, `Rollover`); free time, named gaps, overflow, suggested capacity and the fit flags are in too (`FreeTime`); wiring them into the rollover's `DayPlan` and the habit minutes come with the habit and Anchor slices.
- ~~Habit rules: pauses, due-ness, density states, the read signal, weekly progress, today's windows and the shared engagement definition~~ **Done** (`HabitRules`, `HabitPauses`, `Engagement`).
- ~~Anchor rules, first slice: config decoding, scheduled generation (preview and sync), exceptions, window states, attendance logging~~ **Done** (`AnchorConfig`, `AnchorGenerator`, `AnchorAttendance`). `afterLast` and the prayer windows (`adhan-swift`) are in too, which completes Anchor generation in `JamaalCore`.
- ~~Task rules, first slice: priorities and ordering, importance rules, quick dates, deferral, Today's task list~~ **Done** (`TaskPriority`, `TaskRules`, `QuickDates`, `TaskDeferral`, `TodayTasks`). Repeating tasks and complete / un-complete / drop are in too (`TaskRepeat`, `TaskActions`).
- ~~Focus sessions: timer state machine, finish and undo, settle, closing with the task, timed-habit minutes, the rollover carry, the pick-up row, the approaching-Anchor line~~ **Done** (`FocusSessions`, `HabitSessions`). Remaining engine modules: Night Planning orchestration, wellbeing, the notification planner.
- ~~Night Planning, part 1: session lifecycle, Build, Load, Close~~ **Done** (`NightPlanning`). Part 2 (the Review read model and Carry forward with undo) is in too. Wellbeing is complete (the score, gathering data, sparkline and trend; the four patterns, their actions and the inline card), and so is the notification planner with the access state and the trial. **All eight rules-engine modules are now built in `JamaalCore`**; what remains is the app layer: views, StoreKit, the system's notification and location APIs, and CloudKit sync.
- ~~App shell and the engine tick~~ **Done:** the adaptable `TabView` (tab bar on a phone, sidebar on iPad and Mac, Anchors its own sidebar item and a segment of Habits on compact width) with placeholder screens built from ThreadsKit tokens; the model container (CloudKit off until the paid programme); the tick on launch and when the app becomes active. Next: the first real screens (Today), from the Design v4 frames.
- ~~Today, first slice~~ **Done:** header and headline, the capacity meter and slider, the Tasks section (tick and untick) and *Also today*. Still to come on Today, each its own change: Anchors, Habits, banners, the toolbar (filter, Plan tomorrow, Add), the wellbeing strip, the companion card.
- ~~Today: Anchors~~ **Done:** plain and grouped rows, window bars, the tick, and the choices (Not today, Someone else did it, Mark as done after all, Undo). Still to come on Today: Habits, banners, the toolbar (filter, Plan tomorrow, Add), the wellbeing strip, the companion card.
- Implement the deterministic rules-engine modules in order of dependency, each with Swift Testing coverage: task scheduling, habit density, Anchor generation, capacity and load, focus sessions, then Night Planning orchestration, wellbeing and notification logic.
- **Checkpoint:** is the pace holding at 10–20 hours a week, and are the models and the first engine modules done or clearly on track? If not, the launch estimate moves toward March 2027 or scope moves to v1.1.

## Phase 3 — The core loop

- **Today**, add task, deferral, importance and categories, the capacity meter, and repeating tasks.
- The **focus timer**: ambient chip and focus screen (Live Activity waits for v1.1).
- **Habits**: the four kinds, the density grid and pauses.
- **Anchors**: rules, one-offs, prayer times (using `adhan-swift`), exceptions and window states.
- **Enrol in the paid Apple Developer Program and create the CloudKit container** before any real-device sync testing (required for iCloud and push).
- **Real-device iCloud spike** (first thing after enrolment): verify what happens to the synced store on sign-out or an account change (G-80), and that two devices converge on the dedup keys.

## Phase 4 — The evening ritual

- **Night Planning** in its five steps, including tomorrow's gaps and *Skip tonight*.
- **Onboarding**, with guided first Task, Habit and Anchor.
- **Notifications** and the in-app fallbacks.

## Phase 5 — Ship preparation

- iPad, Mac and iPhone Duo layouts; accessibility (Dynamic Type, VoiceOver for the custom components, no colour-only states); right-to-left and Arabic-Indic numerals.
- **Trial and paywall**, with the read-only state.
- Privacy, data export and the App Store material.
- **CloudKit production schema deploy** — only after the schema freeze is signed off.
- TestFlight with others, then submission.

## After v1

**v1.1:** Live Activity and Dynamic Island for the running session, detected habits (the offer to promote a repeating task), and sharing / referral if a real need shows up.
**Later:** native Android.

## Open items that could move things

Decisions still open are listed at the end of [App flow](../journeys/app-flow): avoid-habit design, fonts, whether to read calendar events, widgets and quick capture, and the accessibility and localisation plan.
