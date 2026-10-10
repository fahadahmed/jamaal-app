# CLAUDE.md — Jamaal

Context for Claude Code sessions in this repo. This is a handoff from planning done in Claude chat — treat it as ground truth for decisions already made; don't re-litigate these unless something concrete has changed.

## What Jamaal is

A calm-focus multiplatform app (iOS, iPadOS, macOS, with first-class iPhone Duo (the foldable iPhone) support — see `docs/journeys/app-flow.md`) built around three primitives — **Task**, **Habit**, **Anchor** — with a deterministic rules engine and a guided Night Planning flow. Built primarily for the developer's own use: a single unified "Today" list spanning personal, family, and work items, replacing a pattern of bouncing between reminder/task/calendar apps that never stuck.

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

No `.xcworkspace` — JamaalCore is a Swift Package (added as a local package dependency directly into `Jamaal.xcodeproj`), not a separate `.xcodeproj`, so no workspace is needed. ThreadsKit lives in its own repo, added as a **remote** Swift Package dependency (pinned "Up to Next Major Version" from 2.0.0).

## Xcode project settings (as created)

- Organization Identifier: `dev.fhdamd` → bundle ID `dev.fhdamd.Jamaal`
- Interface: SwiftUI · Language: Swift · Storage: SwiftData
- **Minimum OS: iOS 26 / macOS 26** (Liquid Glass is a system feature from 26; Duo-specific APIs from 27.1 are availability-gated)
- CI: `.github/workflows/ci.yml` runs `JamaalCore` tests and the app's unit tests on the `xcode-27` runner
- **Host in CloudKit: enabled** — cross-device sync (iPhone/iPad/Mac) is in scope for v1, not deferred
- Testing System: **Swift Testing with XCTest UI Tests** (see Testing section below)
- Team: Personal (free) is fine for simulator builds and CI, but **iCloud/CloudKit and push can't be provisioned on it**, so the paid Apple Developer Program ($99/year) must be enrolled before any real-device sync testing (by the start of Phase 3 at the latest), and the CloudKit container identifier created then. It is also needed for TestFlight-with-others, production CloudKit and App Store submission. **Running on your own device with the free team works** because the Debug configuration signs with `Jamaal/Jamaal-Personal.entitlements` (empty); Release uses `Jamaal.entitlements` (push and iCloud) and needs the paid programme. When CloudKit is wired, point Debug back at the full file.

## Widgets and the watch (decided 8 Oct 2026)

**Widgets are in v1** (Next Anchor and Today, on iPhone, iPad and Mac, with Lock Screen accessory widgets); a **companion watchOS app is v1.1**; Live Activity, App Intents and interactive widgets are v1.1. The SwiftData store must live in an **App Group container from the first CloudKit-enabled build** (done with the CloudKit set-up once the paid programme is active, about 14 Oct 2026), so no user ever migrates. Widgets and the watch both read a pure, `Codable` `WidgetSnapshot` built in JamaalCore. v1 launches on iPhone, iPad and Mac together; **tvOS is not planned** (the medium doesn't suit the app) and visionOS is a possible later step. See `docs/architecture/decisions/0003-widgets-in-v1-watch-in-v1-1.md`, `docs/architecture/widgets-and-watch.md` and, for what Design's batches 8–9 decided, `docs/design/widgets-and-watch-reconciliation.md`.

## Testing strategy

- **JamaalCore** (`JamaalCoreTests`): **Swift Testing** exclusively (`@Test`, `#expect`, `try #require`). No XCTest here — this package is pure logic (rules engine, models), Apple's default for new unit tests in Xcode 26, and a good fit for parameterized tests (e.g. Anchor generation across time-window scenarios).
- **Jamaal app** (`JamaalTests`): Swift Testing, for view models / app-layer logic.
- **Jamaal app** (`JamaalUITests`): **XCTest / XCUITest** — non-negotiable, Apple hasn't replaced XCUITest with Swift Testing. Use for the custom, interaction-heavy components (capacity slider, night-planning wizard) that are easy to silently break in a SwiftUI refactor.

- **Jamaal Mac app** (`JamaalMacUITests`): **XCUITest on a real Mac** (macOS only; the iOS UI tests can't run there). It launches the Mac app with the same debug arguments and checks the sidebar, the menu shortcuts (⌘1–⌘4, ⌘N, ⌘, and ⇧⌘P), the focus chip and the right-click menu. Run it with `xcodebuild test -project Jamaal/Jamaal.xcodeproj -scheme JamaalMac -destination 'platform=macOS'`. The `JamaalMac` scheme is **not tracked** (a shared scheme in the repo stops Xcode generating the automatic `Jamaal` scheme that CI uses, which broke CI once): copy `Jamaal/Schemes/JamaalMac.xcscheme` into `Jamaal/Jamaal.xcodeproj/xcshareddata/xcschemes/` on your machine first. In a clean checkout the automatic `Jamaal` scheme also includes the target (`-only-testing:JamaalMacUITests`). **It drives the real desktop: it takes over the mouse and keyboard while it runs, so keep your hands off, and the first run may ask you to allow control of the computer.** An automated agent session can't screenshot the Mac or press keys in it, so this is how Mac behaviour is verified.

## SwiftData / CloudKit constraints (applies to all three primitives)

The authoritative model list, conventions and dedup keys are in `docs/schema/overview.md`.

Because CloudKit sync is in from v1:

- Every property needs a default value (no bare `let` without one)
- No unique constraints on attributes
- Relationships must be optional

## The three primitives

| Primitive  | Created by | Tracked via             | Nature                                                                                                                                                       |
| ---------- | ---------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Task**   | User       | Completion              | Something you _do_                                                                                                                                           |
| **Habit**  | User       | Density (a grid of days), not streaks | Something you _cultivate_ — four kinds: binary, counted, timed (minutes; uses the focus timer) and avoid (log a slip); can be paused with a reason |
| **Anchor** | User — as a recurring rule (instances generated) or a one-off | Attendance (attended / missed / skipped), not streaks | Something your life _moves around_ — timing and the consequence of a miss are external to the user (prayer windows, school runs, bin night, watering plants) |

Full rationale for Anchor as a third type (vs. folding into Habit): `docs/architecture/decisions/0001-anchor-object-type.md`.

Notes feature was dropped in favor of optional lightweight markdown (checklists, bold/italic, links, inline code) scoped to individual tasks, surfaced as a tappable checklist during a task's focus session (timed), plus optional timestamped lines on the finish and defer sheets — not a separate notes destination.

## Product principles (carried from the earlier planning chat)

- **One flat list, no projects, no tags — ever.** `TaskItem.category` is an editable label list (defaults personal/family/work), one per task, used as a label and optional filter, never a grouping axis.
- **Jamaal is also the companion voice** — calm, supportive, non-judgmental; inline cards, never a chat UI; no punitive severity colours. Tagline: "One list. Just today. Beautifully ordered."
- **Hidden Eisenhower**: quadrant derived from importance (`importance`) and urgency (due date, deferrals), never shown.
- Effort estimates + capacity level → load state; deferral escalates at the 3rd deferral (date picker) and 5th (suggest removal).
- Full reconciliation with the earlier planning chat: `docs/architecture/decisions/0002-reconcile-master-summary-v2.md`. End-to-end flow and coherence checklist: `docs/journeys/app-flow.md`.

## Rules engine (JamaalCore)

Deterministic — same state + inputs always produce the same output, no ML/heuristics. Eight modules (numbering of the original six is stable; **boundaries are a draft, confirm before implementing** — see `docs/architecture/rules-engine.md`):

1. Task scheduling (due dates, rollover)
2. Habit density & intelligence (no streaks)
3. Anchor generation (window-bound instances, attendance)
4. Night Planning orchestration (5-step wizard state machine: review today → carry forward → build tomorrow → check the load → close the day; skippable)
5. Wellbeing scoring ("gathering data" → active score)
6. Notification/nudge logic (window-closing reminders, during-day guidance)
7. Capacity & load (energy budget from `low`/`medium`/`high` for tasks; free time from the working day minus fixed commitments; soft day-end; what Today shows)
8. Focus sessions (task timer state machine: Begin / pause / finish, one live session, midnight auto-close)

Modules emit typed signals; a separate message-template layer phrases them in Jamaal's companion voice.

## Design system

ThreadsKit (shared package, also used by Riqa/Hashiya; depend on **2.0.0 or later**) supplies the design tokens: a `ThreadsPalette` protocol (21 colour names plus status roles) with `JamaalPalette` as its only conformance — a cool palette with a teal accent (`#1F6A58` light / `#8FCBB8` dark), blue-based ink, terracotta (`terra`) as the one action colour, light + dark baked in — plus the five category colours, space/radius/hit, elevation, motion, and the bundled fonts (Fraunces, Hanken Grotesk, JetBrains Mono) with the six type roles. Views read colours from `@Environment(\.threads)` and never use a raw hex; fonts are registered at launch with `ThreadsFonts.registerAll()`. There is no sage token. Full reference and open items: `docs/design/threadskit-usage.md`. Components are not in ThreadsKit (they live in `Jamaal/Components/`). Liquid Glass direction (floating pill tab bar, translucent glass nav circles) still applies.

**Precedence: styling is taken from the Claude Design project** (the v3 screens, its tokens page and flow spec) **unless it conflicts with functionality locked in this repo.** The self-contained hand-off is `docs/design/claude-design-brief.md`. **Design v4 is now delivered**: the 110 frames and editable sources in `mockups/screens/` are the visual truth, the token and component handoff is `docs/design/README.md`, and `docs/design/v4-reconciliation.md` records where it changed the docs (behaviour and data still come from `docs/journeys/`). Type: Fraunces (display), Hanken Grotesk (text) and JetBrains Mono (labels), as Design draws them — not DM Sans — now bundled in ThreadsKit 2.0.0.

Custom components NOT from ThreadsKit, built in `Jamaal/Components/`: capacity slider, habit group completion ring, habit heatmap grid, wellbeing sparkline (Swift Charts), Night Planning 5-step wizard.

## Business context (informs priority, not architecture)

- Pricing: free download, 14-day full-access trial, then subscription only — $2.99/mo or $24.99/yr (no lifetime SKU). Trial is app-managed (no payment up front); when it ends without a subscription the app goes read-only, not locked — see `docs/journeys/app-flow.md`
- Sharing/referral: **deferred to v1.1, not in scope for v1.** No referral mechanic is planned; the existing `TaskItem.category` values of `personal`/`family`/`work` are just personal labels for the single user, not multi-account data sharing. Revisit if/when a real need shows up — no schema impact for now.
- Target launch: as early as late Dec 2026 (aligned to January resolution surge) or realistically ~March 2027 given ~10–20 hrs/week alongside full-time work; native Android (Kotlin, not Flutter) is a later, separate effort post-iOS-traction
- Phase 2 pace checkpoint: end of October 2026

## Working approach

**Docs/flows-first.** Screens and flows are locked in `docs/journeys/screens.md` (the register) before they are drawn or built, and all eleven journeys have been walked against the schema and engine (`docs/journeys/walkthroughs/overview.md`: 89 gaps decided and applied; the remaining owner items are listed at its end). This repo was restarted from scratch specifically because the previous JamaalCore attempt skipped this step. `docs/schema/*`, `docs/journeys/*`, and `docs/architecture/rules-engine.md` are now filled in and resolved for v1 (see issues #5–#8) — implementation can begin. Don't skip this step for future primitives or major features; keep docs ahead of code.

## Git workflow

All new code or documentation work is tracked through a GitHub issue and lands via a PR — no direct commits to `main`, except trivial fixes (typos, formatting) explicitly requested as a direct commit.

1. Open (or use an existing) GitHub issue describing the work.
2. Branch off `main`, named `[type]/[issueNumber]-[description]`, where `type` is one of `feat`, `bug`, `task`, `doc`, and `description` is a short kebab-case summary (e.g. `feat/12-night-planning-wizard`).
3. Open a PR from that branch into `main`, referencing the issue (e.g. `Closes #12`).
4. Merge via PR — this is also what exercises `sync-wiki.yml` and `ci.yml`, which fire on PRs into `main` and on `main`.

## Open items to pick up next

- [x] CI: `.github/workflows/ci.yml` builds and tests `JamaalCore` and the app's unit tests on every code PR and push to `main` (docs-only changes skip it). XCUITest joins once it covers real screens
- [x] ThreadsKit 2.0.0 is wired into `Jamaal.xcodeproj` (remote, Up to Next Major) with `Package.resolved` committed; fonts register at launch. Remaining design items are in `docs/design/threadskit-usage.md`
- [ ] Open owner items (region table review, Anchor reminders while read-only, category hues, fonts, merge order of the stacked PRs, paid programme and iCloud spike) are collected in `docs/journeys/walkthroughs/overview.md#open-owner-items`
- [x] `mockups/screens/` holds the Design v4 frames (110 in batches 1–7, plus batches 8 and 9 for widgets and the Apple Watch) and editable sources; `mockups/legacy/` is layout reference only
- [x] Reconcile against prior planning-chat data — done, see ADR 0002. Remaining open decisions are listed in `docs/journeys/app-flow.md` ("Still open")
