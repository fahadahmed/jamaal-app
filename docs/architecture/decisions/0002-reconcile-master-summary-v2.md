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
| Carry-forward Keep/Later/Drop in Night Planning | [night-planning.md](../../journeys/night-planning) step 1 |
| Habit groups (visual only, default collapsed), counted habits, per-day entries, heatmap states | [habit.md](../../schema/habit) |
| Habit fatigue, streak protection, new-habit realism | rules-engine module 2 |
| Wellbeing pattern detection, one nudge a day | rules-engine module 5, `NudgeLog` |
| During-day guidance (one card a day), notification-denied fallback, empty states | rules-engine module 6, [today-list.md](../../journeys/today-list) |
| Onboarding intro screens (meet Jamaal, concept, capacity, notifications) | [onboarding.md](../../journeys/onboarding) |
| Screen inventory and navigation | [app-flow.md](../../journeys/app-flow) |
| Domain `jamaal.app`; marketing site lives outside this repo | CLAUDE.md |

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
| Per-habit `currentStreak`, `isActive`, stored skip/fatigue fields | Per-window streaks, `isArchived`, fatigue derived from `HabitEntry` |

## Merged / changed

- **Categories stay, refined**: an editable list seeded with personal/family/work; one per task; a label and optional Today filter only, never a grouping axis. This keeps "no projects, no tags" true.
- **Capacity**: the user still sets `low`/`medium`/`high` (repo). Each level maps to a minute budget and tasks have optional effort, so v2's load states survive without a minutes-based capacity model. v2's learned baseline and per-weekday multipliers are **dropped** — the user sets capacity nightly, which already captures weekday variation.
- **Rollover → deferral**: `rolloverCount` becomes `deferralCount`; automatic day-rollover is kept as a safety net (reason `unspecified`) so skipping planning never loses a task.
- **Night Planning**: five steps kept, with carry-forward inside step 1: `reviewCarry → reflect → plan → capacity → confirm`. (v2's steps were `todayReview → carryForward → buildTomorrow → loadCheck → done`.) The load check merges with the capacity step; the repo's Reflect step (mood 1–5 + note) is retained.
- **`DailyCapacity` → `DayPlan`**: widened with planned/completed effort, load score, overloaded flag and completion rate, because wellbeing patterns need per-day history. v2's `WellbeingSnapshot` is not restored — wellbeing stays derived.
- **Rules engine**: six modules → seven (added Capacity & load). Numbering of the original six is unchanged.
- **New models** (v2 had some in different form): `TaskCategory`, `DeferralRecord`, `HabitEntry`, `HabitGroup`, `DayPlan`, `NudgeLog`. Total persisted: Task, TaskCategory, DeferralRecord, Habit, HabitTimeWindow, HabitEntry, HabitGroup, Anchor, AnchorRule, DayPlan, NightPlanningSession, NudgeLog.
- **`UserPreferences`** stay in `UserDefaults`/`@AppStorage`, per v2 (per-device; fits notification times).

## Not carried over

- v2's revenue outlook and build-time estimates (pre-date the pricing change).
- Marketing landing page mockup (belongs to the web project).
- CI/CD workflows described in v2 (`ci.yml` etc.): the repo's own CI is a separate open item.

## Still open

Tracked in [app-flow.md](../../journeys/app-flow) under "Still open".
