# Roadmap — phases

> **Status: proposal, needs review.** The phase numbering from the earlier planning was not recorded in this repo. The only fixed points I found are the **Phase 2 pace checkpoint at the end of October 2026** and the launch window below (both from `CLAUDE.md`). The phases themselves are a proposal built from the decisions made so far; confirm or reshape them.

## Constraints

- About **10–20 hours a week**, alongside full-time work.
- **Launch target:** as early as late December 2026 (the January resolution surge), or realistically around **March 2027** at this pace.
- iOS, iPadOS and macOS together in v1. A native Android app (Kotlin, not Flutter) is a later, separate effort after iOS traction.
- The paid Apple Developer Program ($99/year) is only needed at TestFlight-with-others, production CloudKit and App Store submission time.

## Phase 1 — Docs and flows first *(done)*

Schema, journeys and the rules engine are specified; the earlier planning was reconciled into the repo; the design project was reviewed and its decisions folded in; the schema is a freeze candidate ([Schema overview](../schema/overview)).

## Phase 2 — Foundations *(current; pace checkpoint end of October 2026)*

- Wire ThreadsKit 1.1.0 or later into `Jamaal.xcodeproj`.
- Add a build-and-test workflow (`ci.yml`).
- Implement the 14 models in `JamaalCore` with a versioned schema, tests first.
- Implement the deterministic rules-engine modules in order of dependency, each with Swift Testing coverage: task scheduling, habit density, Anchor generation, capacity and load, focus sessions, then Night Planning orchestration, wellbeing and notification logic.
- **Checkpoint:** is the pace holding at 10–20 hours a week, and are the models and the first engine modules done or clearly on track? If not, the launch estimate moves toward March 2027 or scope moves to v1.1.

## Phase 3 — The core loop

- **Today**, add task, deferral, importance and categories, the capacity meter, and repeating tasks.
- The **focus timer**: ambient chip and focus screen (Live Activity waits for v1.1).
- **Habits**: the four kinds, the density grid and pauses.
- **Anchors**: rules, one-offs, prayer times, exceptions and window states.

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

Decisions still open are listed at the end of [App flow](../journeys/app-flow): avoid-habit design, category colours, fonts, whether to read calendar events, widgets and quick capture, and the accessibility and localisation plan.
