# CLAUDE.md — Jamaal

Context for Claude Code sessions in this repo. This is a handoff from planning done in Claude chat — treat it as ground truth for decisions already made; don't re-litigate these unless something concrete has changed.

## What Jamaal is

A calm-focus multiplatform app (iOS, iPadOS, macOS, with first-class iPhone Duo support) built around three primitives — **Task**, **Habit**, **Anchor** — with a deterministic rules engine and a guided Night Planning flow. Built primarily for the developer's own use: a single unified "Today" list spanning personal, family, and work items, replacing a pattern of bouncing between reminder/task/calendar apps that never stuck.

Deliberately a **general** productivity app, not an Islamic-only one — Islamic practice habits (Qur'an reading, dhikr) and general habits (exercise, running) are just different presets of the same Habit engine, not a separate mode. Salah is modeled separately as an Anchor, not a Habit — see `docs/schema/anchor.md` — since its timing is externally fixed (prayer windows) rather than self-paced, which is Anchor's defining trait.

## Repo structure

```
jamaal-app/
├── Jamaal/              # app target (SwiftUI, multiplatform: iOS/iPadOS/macOS)
│   ├── App/
│   ├── Features/        # Today, Habits, Anchors, NightPlanning, Settings
│   ├── Components/      # capacity slider, habit heatmap, wellbeing sparkline, night-planning wizard
│   └── Resources/
├── JamaalCore/           # local Swift Package — SwiftData models + rules engine, NO UI imports
│   ├── Sources/JamaalCore/{Models,RulesEngine}/
│   └── Tests/JamaalCoreTests/
├── mockups/               # HTML reference screens (Liquid Glass pass applied) — source of truth for SwiftUI screens
├── docs/                  # synced to GitHub wiki via .github/workflows/sync-wiki.yml on merge to main
│   ├── Home.md / _Sidebar.md
│   ├── architecture/ (overview.md, rules-engine.md, decisions/, uml/)
│   ├── schema/ (task.md, habit.md, anchor.md)
│   ├── journeys/ (today-list.md, night-planning.md, onboarding.md)
│   ├── roadmap/phases.md
│   └── design/threadskit-usage.md
├── .github/workflows/ (ci.yml, sync-wiki.yml)
└── ci_scripts/            # reserved for Xcode Cloud, empty for now
```

No `.xcworkspace` — JamaalCore is a Swift Package (added as a local package dependency directly into `Jamaal.xcodeproj`), not a separate `.xcodeproj`, so no workspace is needed. ThreadsKit lives in its own repo, added as a **remote** Swift Package dependency (pinned "Up to Next Major Version" from 1.0.0).

## Xcode project settings (as created)

- Organization Identifier: `dev.fhdamd` → bundle ID `dev.fhdamd.Jamaal`
- Interface: SwiftUI · Language: Swift · Storage: SwiftData
- **Host in CloudKit: enabled** — cross-device sync (iPhone/iPad/Mac) is in scope for v1, not deferred
- Testing System: **Swift Testing with XCTest UI Tests** (see Testing section below)
- Team: Personal (free) — fine through development; paid Apple Developer Program ($99/year) only needed at TestFlight-with-others / production CloudKit / App Store submission time, not before

## Testing strategy

- **JamaalCore** (`JamaalCoreTests`): **Swift Testing** exclusively (`@Test`, `#expect`, `try #require`). No XCTest here — this package is pure logic (rules engine, models), Apple's default for new unit tests in Xcode 26, and a good fit for parameterized tests (e.g. Anchor generation across time-window scenarios).
- **Jamaal app** (`JamaalTests`): Swift Testing, for view models / app-layer logic.
- **Jamaal app** (`JamaalUITests`): **XCTest / XCUITest** — non-negotiable, Apple hasn't replaced XCUITest with Swift Testing. Use for the custom, interaction-heavy components (capacity slider, night-planning wizard) that are easy to silently break in a SwiftUI refactor.

## SwiftData / CloudKit constraints (applies to all three primitives)

Because CloudKit sync is in from v1:

- Every property needs a default value (no bare `let` without one)
- No unique constraints on attributes
- Relationships must be optional

## The three primitives

| Primitive  | Created by | Tracked via             | Nature                                                                                                                                                       |
| ---------- | ---------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Task**   | User       | Completion              | Something you _do_                                                                                                                                           |
| **Habit**  | User       | Streaks                 | Something you _cultivate_ — supports time-windowed occurrences (e.g. five daily prayers as a preset)                                                         |
| **Anchor** | Generated  | Attendance, not streaks | Something your life _moves around_ — timing and the consequence of a miss are external to the user (prayer windows, school runs, bin night, watering plants) |

Full rationale for Anchor as a third type (vs. folding into Habit): `docs/architecture/decisions/0001-anchor-object-type.md`.

Notes feature was dropped in favor of optional lightweight markdown (checklists, bold/italic, links, inline code) scoped to individual tasks, surfaced as a tappable checklist during a task/anchor's timed session — not a separate notes destination.

## Rules engine (JamaalCore)

Deterministic — same state + inputs always produce the same output, no ML/heuristics. Six modules proposed (**boundaries are a first draft, confirm before implementing**):

1. Task scheduling (due dates, rollover)
2. Habit streak tracking
3. Anchor generation (window-bound instances, attendance)
4. Night Planning orchestration (5-step wizard state machine)
5. Wellbeing scoring ("gathering data" → active score)
6. Notification/nudge logic (streak-protection, during-day guidance)

## Design system

ThreadsKit (shared package, also used by Riqa/Hashiya, v1.0.0) currently supplies **colour tokens only** — a cool palette with a teal accent (`#1F6A58` light / `#8FCBB8` dark), blue-based ink, terracotta as secondary (`terra`), light + dark baked in. This replaced the earlier warm palette (off-white/charcoal/terracotta/sage); there is no sage token. Full token table and open decisions: `docs/design/threadskit-usage.md`. Typography, spacing/radius and components are not in ThreadsKit yet; Fraunces + DM Sans remain the intended faces, unconfirmed upstream. Liquid Glass direction (floating pill tab bar, translucent glass nav circles) still applies.

Custom components NOT from ThreadsKit, built in `Jamaal/Components/`: capacity slider, habit group completion ring, habit heatmap grid, wellbeing sparkline (Swift Charts), Night Planning 5-step wizard.

## Business context (informs priority, not architecture)

- Pricing: free download, 14-day full-access trial, then subscription only — $2.99/mo or $24.99/yr (no lifetime SKU)
- Sharing/referral: **deferred to v1.1, not in scope for v1.** No referral mechanic is planned; the existing `Task.category` values of `personal`/`family`/`work` are just personal labels for the single user, not multi-account data sharing. Revisit if/when a real need shows up — no schema impact for now.
- Target launch: as early as late Dec 2026 (aligned to January resolution surge) or realistically ~March 2027 given ~10–20 hrs/week alongside full-time work; native Android (Kotlin, not Flutter) is a later, separate effort post-iOS-traction
- Phase 2 pace checkpoint: end of October 2026

## Working approach

**Docs/flows-first.** This repo was restarted from scratch specifically because the previous JamaalCore attempt skipped this step. `docs/schema/*`, `docs/journeys/*`, and `docs/architecture/rules-engine.md` are now filled in and resolved for v1 (see issues #5–#8) — implementation can begin. Don't skip this step for future primitives or major features; keep docs ahead of code.

## Git workflow

All new code or documentation work is tracked through a GitHub issue and lands via a PR — no direct commits to `main`, except trivial fixes (typos, formatting) explicitly requested as a direct commit.

1. Open (or use an existing) GitHub issue describing the work.
2. Branch off `main`, named `[type]/[issueNumber]-[description]`, where `type` is one of `feat`, `bug`, `task`, `doc`, and `description` is a short kebab-case summary (e.g. `feat/12-night-planning-wizard`).
3. Open a PR from that branch into `main`, referencing the issue (e.g. `Closes #12`).
4. Merge via PR — this is also what exercises `sync-wiki.yml` and (once it's live) `ci.yml`, which only fire on `main`.

## Open items to pick up next

- [ ] Revisit the Anchor generated-vs-user-created positioning (flagged in `docs/schema/anchor.md` and `docs/journeys/onboarding.md`) — not settled, just parked
- [ ] Fill in `docs/architecture/decisions/0001-anchor-object-type.md` — referenced by multiple docs as the rationale source but still an empty stub
- [ ] `ci.yml` doesn't exist yet — only `sync-wiki.yml` is live under `.github/workflows/`. `Jamaal.xcodeproj` now exists, so a build/test workflow can be added whenever CI is prioritized
- [ ] ThreadsKit isn't wired in yet (no dependency in `Jamaal.xcodeproj`, no `Package.resolved`). Token docs are done; see open decisions in `docs/design/threadskit-usage.md` (no sage → habit ring/heatmap colour plan, font faces, mockups on the old palette)
- [ ] `mockups/` is empty (README and `screens/` have no content) — the HTML reference screens referenced above still need to be added, re-skinned to the current palette
- [ ] Reconcile this file against prior planning-chat data once it's provided (in progress)
