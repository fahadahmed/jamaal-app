# Diagrams

How the pieces fit, drawn rather than described. Each diagram is [Mermaid](https://mermaid.js.org), so it renders on this wiki and in the repository, and each one says which page holds the detail. Screens are in the [Screen gallery](../journeys/screen-gallery).

- [The pieces](#the-pieces) · [The data](#the-data) · [One day's housekeeping: the engine tick](#the-engine-tick)
- [Adding a task](#adding-a-task) · [Night Planning](#night-planning) · [An Anchor's life](#an-anchors-life) · [A focus session](#a-focus-session) · [Access and the trial](#access-and-the-trial)
- [Sync between devices](#sync-between-devices) · [Widgets](#widgets) · [Links and notification taps](#links-and-notification-taps) · [Navigation by device](#navigation-by-device)

## The pieces

Everything that decides something is in **JamaalCore**, a Swift package with no UI. The app and the widget extension are thin: they read the same store and draw. The store lives in the **App Group** container so the widget can read it, and iCloud mirrors it between devices. Detail: [Architecture overview](overview), [Widgets and the watch](widgets-and-watch).

```mermaid
flowchart TB
  subgraph Targets["Targets"]
    direction LR
    App["Jamaal app<br/>SwiftUI: iPhone, iPad, Mac"]
    Widgets["JamaalWidgets<br/>widget extension"]
    Watch["Watch app<br/>v1.1"]
  end
  subgraph Core["JamaalCore: a Swift package with no UI"]
    direction LR
    Models["Models<br/>SwiftData schema"]
    Engine["Rules engine<br/>deterministic modules"]
    Snapshot["WidgetSnapshot<br/>and WidgetTimeline"]
  end
  Kit["ThreadsKit<br/>colours, type, fonts"]
  Store[("SwiftData store<br/>in the App Group container")]
  iCloud[("iCloud<br/>CloudKit private database")]
  Apple["Apple services<br/>StoreKit, notifications"]

  Targets --> Core
  Targets --> Kit
  App -->|read and write| Store
  Widgets -.->|read only| Store
  Store <-->|CloudKit mirroring| iCloud
  App --> Apple
  App -->|reload timelines| Widgets
  Watch -.->|snapshot over WatchConnectivity| App
```

## The data

Three primitives and what hangs off them. A **Task** is something you do, a **Habit** something you cultivate, an **Anchor** something your life moves around: see [Schema overview](../schema/overview) and the pages for [Task](../schema/task), [Habit](../schema/habit) and [Anchor](../schema/anchor). Every relationship is optional and every property has a default, because the store syncs through CloudKit.

```mermaid
classDiagram
  direction LR
  class TaskItem {
    title
    dueDate
    effortMinutes
    importance
    deferralCount
    completedAt
  }
  class TaskCategory {
    name
    colorKey
    isArchived
  }
  class DeferralRecord
  class WorkSession {
    startedAt
    endedAt
    outcome
  }
  class Habit {
    title
    kind
    isArchived
  }
  class HabitGroup
  class HabitTimeWindow
  class HabitEntry {
    amount
    completedAt
  }
  class AnchorRule {
    title
    sourceKey
    isArchived
  }
  class Anchor {
    title
    occurrenceDate
    windowStart
    windowEnd
    attendance
  }
  class UserSettings {
    mediumDayMinutes
    rolloverMinute
    planningMinute
  }
  class DayPlan
  class NightPlanningSession
  class NudgeLog

  TaskCategory "0..1" <-- "*" TaskItem : labelled
  TaskItem "1" --> "*" DeferralRecord
  TaskItem "1" --> "*" WorkSession
  Habit "*" --> "0..1" HabitGroup
  Habit "1" --> "*" HabitTimeWindow
  HabitTimeWindow "1" --> "*" HabitEntry
  HabitTimeWindow "1" --> "*" WorkSession
  AnchorRule "1" --> "*" Anchor : generates
```

`UserSettings`, `DayPlan`, `NightPlanningSession` and `NudgeLog` stand alone. An `Anchor` with no rule is a one-off. A `WorkSession` belongs to a task **or** a habit window, never both.

## The engine tick

The engine keeps the day current in **one idempotent call**: a second tick over the same moment changes nothing. It runs at launch, whenever the app becomes active, and a few seconds after changes arrive from iCloud. Detail: [Rules engine](rules-engine).

```mermaid
flowchart TD
  Trigger(["Launch, app becomes active,<br/>or iCloud changes settle"]) --> Seed["Seed what is missing<br/>settings and default categories"]
  Seed --> Dedup["Merge duplicates<br/>another device made"]
  Dedup --> Catch["Catch up every day that has ended<br/>auto-defer, record the day, close timers"]
  Catch --> Generate["Generate Anchors<br/>for today and tomorrow"]
  Generate --> Missed["Mark closed, unlogged windows missed"]
  Missed --> Remember["Remember the last processed day"]
  Remember --> After["Then: replan notifications,<br/>reload widgets"]
```

## Adding a task

The form keeps a dated task dated and nudges the date when something matters. Before saving, a full day is noticed and a way out is offered. Detail: [Today list](../journeys/today-list), [Task](../schema/task).

```mermaid
sequenceDiagram
  actor You
  participant Sheet as Add task sheet
  participant Form as AddTaskForm
  participant Core as TaskCreation (JamaalCore)
  participant Store as SwiftData store
  participant Today as Today screen

  You->>Sheet: Type a title, choose effort, how much it matters, when
  Sheet->>Form: Update the draft
  Form-->>Sheet: Raising importance dates the task today
  You->>Sheet: Add to today
  Sheet->>Core: dayFullCheck(draft)
  alt The day is full
    Core-->>Sheet: Suggest another day
    Sheet-->>You: Offer to move it, or add anyway
    You->>Sheet: Choose
  end
  Sheet->>Core: create(draft)
  Core->>Store: Insert the task
  Store-->>Today: The list updates
  Store-->>Sheet: Saved, close
```

## Night Planning

Five steps, saved as you move, with a way out at every step. Skipping loses nothing. A closed night reopens at Build, and a skipped one starts again at Review. Detail: [Night Planning](../journeys/night-planning).

```mermaid
stateDiagram-v2
  [*] --> Review
  Review --> Carry : Continue
  Carry --> Build : Keep, Later or Drop each task
  Carry --> Build : nothing left over, passed through
  Build --> Load : Pull tasks in, push them out
  Load --> Close : Choose tomorrow's capacity
  Close --> [*] : Plan confirmed
  Close --> Build : Reopen a closed night
  Review --> Skipped : Skip tonight
  Carry --> Skipped : Skip tonight
  Build --> Skipped : Skip tonight
  Load --> Skipped : Skip tonight
  Skipped --> Review : Reopen, the skip is cleared
```

## An Anchor's life

An Anchor has a **window** that is worked out from the clock (never stored) and an **attendance** that is recorded. A missed window is not a failure to hide or to shout about: it reads as a plain fact. Detail: [Anchor](../schema/anchor).

```mermaid
stateDiagram-v2
  direction LR
  [*] --> Upcoming
  Upcoming --> Open : the window starts
  Open --> ClosingSoon : last quarter, at least 10 minutes
  ClosingSoon --> Closed : the window ends
  Open --> Closed : the window ends
```

```mermaid
stateDiagram-v2
  [*] --> Pending
  Pending --> Attended : Attended
  Pending --> Skipped : Not today
  Pending --> Delegated : Someone else did it
  Pending --> Missed : the window closes unlogged
  Attended --> Pending : Undo, while the window is open
  Skipped --> Pending : Undo
  Delegated --> Pending : Undo
  Missed --> Attended : Mark done after all, the same day
```

## A focus session

One live session at a time, for a task or a timed habit. Elapsed time is worked out from the start time, so a closed or killed app never loses or invents time. Overrun is a state, not an event: nothing nags. Detail: [Rules engine, module 8](rules-engine#8-focus-sessions-state-machine).

```mermaid
stateDiagram-v2
  [*] --> Running : Begin, refused while another is live
  Running --> Paused : Pause
  Paused --> Running : Resume
  Running --> Overrun : elapsed passes the estimate
  Overrun --> Settling : Finish
  Running --> Settling : Finish
  Paused --> Settling : Finish
  Settling --> Done : Done
  Settling --> Stopped : Stop for now
  Settling --> Deferred : Defer
  Settling --> Dropped : Drop
  Running --> AutoClosed : the day rolls over
  Overrun --> AutoClosed : the day rolls over
  Running --> Abandoned : another device started later
  Done --> [*]
  Stopped --> [*]
  Deferred --> [*]
  Dropped --> [*]
  AutoClosed --> [*]
  Abandoned --> [*]
```

## Access and the trial

The trial is managed by the app, with no payment up front. When it ends without a subscription the app goes **read-only**, never locked: living the day (ticking things off, logging, Anchor outcomes, focus timers, export) always works, while shaping the plan is locked. Detail: [App flow](../journeys/app-flow#trial-and-subscription).

```mermaid
stateDiagram-v2
  [*] --> Trial : first launch, 14 days
  Trial --> Subscribed : subscribe
  Trial --> ReadOnly : the trial ends, no subscription
  Subscribed --> ReadOnly : the subscription lapses
  ReadOnly --> Subscribed : subscribe or restore
```

## Sync between devices

The phone, the iPad and the Mac each keep a full copy, and iCloud carries changes between them. Each device seeds the default categories on first launch, so for a moment there are two sets: the engine merges them once the import settles. Widgets are told to reload. Detail: [Architecture overview](overview#sync-243).

```mermaid
sequenceDiagram
  actor You
  participant iPad as iPad app
  participant S1 as iPad store
  participant CK as iCloud (CloudKit)
  participant S2 as iPhone store
  participant Phone as iPhone app
  participant W as iPhone widget

  You->>iPad: Add or change something
  iPad->>S1: Save
  S1->>CK: Mirror the change
  CK->>S2: Deliver it to the iPhone
  S2-->>Phone: Remote change notification
  Phone-->>Phone: The lists update at once
  Phone->>W: Reload the timelines
  Note over Phone: Three quiet seconds later
  Phone->>Phone: Engine tick: seed and merge duplicates
```

## Widgets

A widget cannot run the app's code, so it works from a small, device-independent snapshot of Today that it builds itself from the shared store, read-only. It plans its own updates (an Anchor opening or closing, the planning time, the day's end) and the app tells it when the data changes. Detail: [Widgets and the watch](widgets-and-watch).

```mermaid
sequenceDiagram
  participant App as Jamaal app
  participant R as WidgetRefresher
  participant WK as WidgetKit
  participant P as Widget provider
  participant St as Shared store (read only)
  participant Core as WidgetSnapshot (JamaalCore)

  App->>R: A save, an iCloud change, or the app leaves the screen
  R->>WK: Reload timelines, after a quiet second
  WK->>P: Ask for a timeline
  P->>St: Open without creating or writing
  P->>Core: make(now): tasks, capacity, Anchor windows
  Core-->>P: A snapshot of Today
  P->>Core: WidgetTimeline.plan(snapshot)
  Core-->>P: The moments the widget changes
  P-->>WK: One entry per moment, and when to ask again
  WK-->>WK: Draws each entry at its moment
```

## Links and notification taps

A widget tap and a notification tap take the same path in: both become a route, and the app acts on the route. A link that is not ours is ignored. Planning goes through the same access check as the Plan tomorrow button. Detail: [Widgets and the watch](widgets-and-watch#opening-the-app).

```mermaid
sequenceDiagram
  actor You
  participant Src as Widget or notification
  participant App as Jamaal app
  participant Link as JamaalLink (JamaalCore)
  participant Shell as App shell
  participant Today as Today screen

  You->>Src: Tap
  Src->>App: jamaal://today, plan or task/id, or a notification id
  App->>Link: Parse
  alt Not one of ours
    Link-->>App: Nothing, ignored
  else A route
    Link-->>App: today, planning for tomorrow, or a task
    App->>Shell: Set the route
    Shell->>Today: Show Today
    alt planning
      Today->>Today: Start Night Planning, if the plan may be shaped
    else a task
      Today->>Today: Open that task
    end
  end
```

## Navigation by device

The same sections, shaped by the screen. Anchors are a segment inside Habits on a phone and their own sidebar item where there is room. Detail: [App flow](../journeys/app-flow#navigation).

```mermaid
flowchart TD
  Sections["Today, Habits, Anchors,<br/>Wellbeing, Settings"]
  Sections --> Phone["iPhone<br/>floating tab bar of four<br/>Anchors is a segment of Habits"]
  Sections --> Pad["iPad<br/>sidebar of five<br/>detail panel beside the list"]
  Sections --> Mac["Mac<br/>sidebar of four<br/>Settings in the app menu"]
  Mac --> Keys["Menu commands<br/>New Task, Plan Tomorrow,<br/>sections 1 to 4, Settings"]
  Pad --> Wide["Night Planning on a wide canvas<br/>with a step rail"]
  Mac --> Wide
```
