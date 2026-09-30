# ADR 0002: Reconcile the earlier planning chat ("Master Project Summary v2") into this repo

> **Status: draft, needs review.** Records which decisions from the earlier planning chat carried over, which the repo's own decisions superseded, and what changed to merge them. From here on, **this repo is the single source of context** — the summary file is no longer a reference.

## Context

The earlier planning chat produced a "Master Project Summary v2" (repo `jamaal-ios`, 9 SwiftData models, 20 HTML mockup screens, an older business plan). The repo was later restarted docs-first, gained the **Anchor** primitive, picked up CloudKit-from-v1, ThreadsKit, and a different pricing model. The two disagreed in several places.

## Rule of thumb applied

Where the summary and the repo conflict on **structure, platform or business**, the repo (CLAUDE.md and `docs/`) wins — it is later and deliberate. Where the summary has **behaviour the repo lacks**, it was carried over unless it conflicts with a repo principle.

## Carried over from v2

| Item | Where it lives now |
| ---- | ------------------ |
| One flat list — no projects, no tags | [task.md](../../schema/task) intro; categories are labels only |
| Jamaal as companion voice; typed signals → message-template layer | [rules-engine.md](../rules-engine) architecture; [app-flow.md](../../journeys/app-flow) |
| Hidden Eisenhower quadrant, never shown | [task.md](../../schema/task) (derived), rules-engine module 1 |
| Effort estimates, load score and load states | `Task.effortMinutes`, rules-engine module 7 |
| Deferral behaviour (instant ×2, date picker from 3rd, reason chips, suggest removal at 5) | [task.md](../../schema/task), `DeferralRecord` |
| Carry-forward Keep/Later/Drop in Night Planning | [night-planning.md](../../journeys/night-planning) step 2 |
| Habit groups (visual only, default collapsed), counted habits, per-day entries, heatmap states | [habit.md](../../schema/habit) |
| Habit fatigue, new-habit realism (streak protection dropped — see density decision) | rules-engine module 2 |
| Wellbeing pattern detection, one nudge a day | rules-engine module 5, `NudgeLog` |
| During-day guidance (one card a day), notification-denied fallback, empty states | rules-engine module 6, [today-list.md](../../journeys/today-list) |
| Onboarding intro screens (meet Jamaal, concept, capacity, notifications) | [onboarding.md](../../journeys/onboarding) |
| Screen inventory and navigation | [app-flow.md](../../journeys/app-flow) |
| Domain `jamaal.app`; marketing site lives outside this repo | CLAUDE.md |
| Focus-session timer (from the Claude Design flow spec, not v2) | [task.md](../../schema/task#focus-sessions-begin--pause--finish), rules-engine module 8 |

## Superseded — repo wins

| v2 | Repo |
| -- | ---- |
| One-time purchase ($9.99–$24.99 by platform), no subscription | Free download, 14-day trial, then subscription ($2.99/mo or $24.99/yr) |
| Bundle ID `app.jamaal.ios`, repo `jamaal-ios` | `dev.fhdamd.Jamaal`, `jamaal-app` |
| iOS first; macOS v1.1; watchOS v1.2 | iOS/iPadOS/macOS together in v1; watchOS not planned |
| iOS 17 floor; CloudKit optional | iOS 18 floor (ThreadsKit); CloudKit hosted from v1 |
| Two primitives; salah as a habit group | Three primitives; salah is an Anchor ([ADR 0001](0001-anchor-object-type)) |
| `NightPlanningSession` transient | Persisted, so it resumes across devices |
| Warm palette (off-white/charcoal/terracotta/sage) | ThreadsKit's cool palette ([threadskit-usage](../../design/threadskit-usage)) |
| Fixed `personal`/`family`/`work` strings vs. "no tags ever" | Editable `TaskCategory` list (see below) |
| `Task.status` string, `scheduledFor` non-optional, `sortOrder` | `isCompleted`/`completedAt`/`droppedAt`, optional `dueDate`; ordering derived |
| Per-habit `currentStreak`, `isActive`, stored skip/fatigue fields | Per-window density from `HabitEntry` (no streaks — decided after reviewing the design project), `isArchived`, fatigue derived |

## Merged / changed

- **Categories stay, refined**: an editable list seeded with personal/family/work; one per task; a label and optional Today filter only, never a grouping axis. This keeps "no projects, no tags" true.
- **Capacity**: two measures. The user still sets `low`/`medium`/`high` (repo), which is an energy budget of *focused-task* minutes from their "normal day" length (v2's 3-hour baseline, kept as the `medium` level). Separately, free time is the working day (start to a user-set end, default 19:00) minus fixed Anchors, which cut it into blocks, and the minutes of flexible Anchors and habits — adopting the design's "the day is fragmented by fixed commitments" idea without dropping low/medium/high. The end of the day is soft; midnight stays the hard rollover. v2's weekday multipliers stay dropped, replaced by user-set default levels per weekday (weekends `low`). The app learns the normal day **by suggestion only**: from the last four weeks of actual focus time it proposes a new length, and never changes it by itself (v2 and the design's "learned from 34 days" is therefore a suggestion, not a silent adjustment).
- **Rollover → deferral**: `rolloverCount` becomes `deferralCount`; automatic day-rollover is kept as a safety net (reason `unspecified`) so skipping planning never loses a task.
- **Night Planning**: five steps, ending on the design's shape: `review → carry → build → load → close` (v2 and the design: Review today → Carry forward → Build tomorrow → Check the load → Close the day). The repo's separate Reflect step is dropped: the 1–5 mood and note become one optional line on the Review step, and wellbeing derives mostly from behaviour. Build tomorrow opens on tomorrow's fixed commitments with named free gaps (tasks are not placed into gaps), and a *Skip tonight* action exists. (The repo's earlier intermediate shape folded carry-forward into step 1.)
- **`DailyCapacity` → `DayPlan`**: widened with planned/completed effort, load score, overloaded flag and completion rate, because wellbeing patterns need per-day history. v2's `WellbeingSnapshot` is not restored — wellbeing stays derived.
- **Rules engine**: six modules → eight (added Capacity & load, and Focus sessions). Numbering of the original six is unchanged.
- **New models** (v2 had some in different form): `TaskCategory`, `DeferralRecord`, `HabitEntry`, `HabitGroup`, `DayPlan`, `NudgeLog`. Total persisted: 14 models — Task, TaskCategory, DeferralRecord, WorkSession, Habit, HabitTimeWindow, HabitEntry, HabitGroup, Anchor, AnchorRule, DayPlan, NightPlanningSession, NudgeLog and UserSettings. The authoritative list is [the schema overview](../../schema/overview).
- **Habit kinds** (design H-04…H-09): v2's binary and counted, plus timed (reuses the focus timer) and avoid (inverted logging — specified as a proposal because the design only has a title), plus pause with a reason. Grouped sets stay `HabitGroup`; the design's detected-habit offer is v1.1.
- **Day boundary** (not in v2): a user-set rollover (default midnight) with logical dates and floating calendar dates, so the design's midnight wall becomes a setting, and a lazy idempotent catch-up replaces any assumption that the app runs at midnight.
- **Recurring tasks** (not in v2 or the earlier repo docs): simple repeat on `Task` — `repeatKind`, `repeatWeekdays`, `seriesID`; one live instance per series.
- **`UserPreferences`** stay in `UserDefaults`/`@AppStorage`, per v2 (per-device; fits notification times).

## Not carried over

- v2's revenue outlook and build-time estimates (pre-date the pricing change).
- Marketing landing page mockup (belongs to the web project).
- CI/CD workflows described in v2 (`ci.yml` etc.): the repo's own CI is a separate open item.

## Still open

Tracked in [app-flow.md](../../journeys/app-flow) under "Still open".
