# Architecture overview

> **Status: draft, needs review.** A map of how the pieces fit, pointing at the pages that hold the detail. It repeats no schema or rules — see the linked docs.

## Shape of the system

Two Swift targets in one repo, plus one shared design package:

| Piece | What it is | Rules |
| ----- | ---------- | ----- |
| **`Jamaal`** | The app: SwiftUI, multiplatform (iOS, iPadOS, macOS). Features (Today, Habits, Anchors, Night Planning, Settings), custom components, view models. | Owns presentation, navigation, notifications, StoreKit. |
| **`JamaalCore`** | A local Swift Package: the SwiftData models and the deterministic rules engine. | **No UI imports.** Pure logic, testable without a simulator. |
| **ThreadsKit** | A separate repo, added as a remote Swift Package (2.0.0 or later): the palette, category colours, space, elevation, motion and the bundled fonts with the type roles. | Tokens only; components live in `Jamaal/Components/`. See [ThreadsKit usage](../design/threadskit-usage). |

There is no `.xcworkspace`: `JamaalCore` is added as a local package dependency directly in `Jamaal.xcodeproj`.

## How a decision flows

```
user action / clock / sync
        │
   view model (Jamaal)
        │  builds a context (today's tasks, habits, Anchors, sessions, settings)
        ▼
   rules engine (JamaalCore)      ← deterministic: same state + inputs, same output
        │  emits typed signals
        ▼
   message templates (Jamaal)     ← turns signals into the companion's words
        ▼
   views
```

- **The engine outputs typed signals, never strings.** A separate template layer phrases them in the companion's voice, so the engine stays testable and language-free.
- **Determinism is a hard rule**: no machine learning and no heuristics that vary between runs. "Learning" (for example the normal-day suggestion) is a plain calculation the user accepts or ignores.
- The engine is organised as eight modules behind one protocol; see [Rules engine](rules-engine).

## Persistence and sync

- **SwiftData** with **CloudKit** sync from v1: 14 models, all attributes defaulted, relationships optional, no unique constraints. The full list, conventions and dedup keys are in the [Schema overview](../schema/overview).
- **Because CloudKit can't enforce uniqueness and keeps the last write per record, the engine is written to be idempotent** — rollover, Anchor generation and deferral all use keys that make repeating or racing them safe.
- **Dates**: day-level fields are floating calendar dates; times of day are real instants. The app's day rolls over at a user-set time. See [The day boundary](rules-engine#the-day-boundary).
- **Local-only state** (per device, not synced): notification and appearance preferences, expanded/collapsed UI state, the engine's last-processed day.
- CloudKit's production schema is append-only, so the schema freeze matters before the first production deploy.

## Time, sessions and notifications

- **Focus sessions** derive elapsed time from a start timestamp, never from memory, so a killed app loses nothing. See [Task → Focus sessions](../schema/task#focus-sessions-begin--pause--finish).
- **Notifications** are local (`UNUserNotificationCenter`): the evening planning prompt, an optional morning nudge, habit reminders and a light window-closing nudge. Sessions never notify. Trial reminders are few and quiet. iOS caps pending local notifications at 64, which the volume must stay under.
- **Live Activity / Dynamic Island** for the running session is v1.1; it will be driven locally by the same session state, not by a push.

## Platforms and layout

- **Minimum OS: iOS 26 / macOS 26.** Liquid Glass is a system feature from 26, so the design needs no fallback; ThreadsKit's lower floor (iOS 18 / macOS 15) is irrelevant to the app. iPhone Duo-specific APIs (iOS 27.1) are newer and are gated behind availability checks.
- Layout adapts by size class: system tab bar and toolbars on compact width, sidebar plus a detail pane on regular width, and iPhone Duo covered by the compact (outer display) and regular (inner display) layouts. Navigation must use the system components so this adaptation is automatic. See [App flow → Adaptive layout](../journeys/app-flow#adaptive-layout-ipad-and-mac).

## Widgets and the watch

Widgets are in v1 and a watch companion is v1.1 ([ADR 0003](decisions/0003-widgets-in-v1-watch-in-v1-1), [spec](widgets-and-watch)). A widget extension cannot open the app's private store, so the SwiftData store lives in an **App Group container** from the first sync-enabled build. Both the widgets and the watch read a pure, `Codable` `WidgetSnapshot` that JamaalCore builds from the engine's existing reads.

## Testing

- **`JamaalCore`**: Swift Testing exclusively (`@Test`, `#expect`, `try #require`); the natural home for parameterised tests such as Anchor generation across time windows and prayer-time scenarios.
- **App view models**: Swift Testing in `JamaalTests`.
- **Custom, interaction-heavy components** (capacity slider, Night Planning wizard, focus chip): XCUITest in `JamaalUITests`.

## Business constraints that shape the build

- Free download, a 14-day app-managed trial, then a subscription; when it ends unsubscribed the app becomes **read-only**, not locked. See [App flow → Trial and subscription](../journeys/app-flow#trial-and-subscription).
- Sharing and referral are deferred to v1.1; categories are personal labels for a single user, not multi-account sharing.

## Where the detail lives

[Home](../Home) · [App flow](../journeys/app-flow) · [Schema overview](../schema/overview) · [Rules engine](rules-engine) · [ADR 0001](decisions/0001-anchor-object-type) · [ADR 0002](decisions/0002-reconcile-master-summary-v2) · [ADR 0003](decisions/0003-widgets-in-v1-watch-in-v1-1) · [Widgets and the watch](widgets-and-watch) · [Roadmap](../roadmap/phases)
