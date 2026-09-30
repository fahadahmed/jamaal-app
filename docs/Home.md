# Jamaal

**One list. Just today. Beautifully ordered.**

Jamaal is a calm-focus app for iPhone, iPad and Mac (with first-class iPhone Duo support). It replaces bouncing between reminder, task and calendar apps with a single "Today" list spanning personal, family and work — and a short guided **Night Planning** each evening that decides what belongs on tomorrow's list.

Jamaal is also the name of the companion voice: calm, supportive and non-judgmental. It nudges gently, notices patterns, and stays out of the way otherwise.

## Three primitives

| Primitive | Created by | Tracked via | Nature |
| --------- | ---------- | ----------- | ------ |
| **Task** | You | Completion | Something you *do* |
| **Habit** | You | Density — a grid of days, never streaks | Something you *cultivate* |
| **Anchor** | You, as a recurring rule or a one-off | Attendance | Something your life *moves around* — prayer times, the school run, bin night |

A deterministic **rules engine** (no machine learning) orders the day, checks the load against your energy and your free time, and drives Night Planning. There is no chat interface and no projects, boards or tags — categories are just labels.

## Where to start reading

- **Every screen and flow:** the [Screens and flows register](journeys/screens).
- **How a day works, end to end:** [App flow](journeys/app-flow), then [Today](journeys/today-list), [Night Planning](journeys/night-planning) and [Onboarding](journeys/onboarding).
- **What is stored:** [Schema overview](schema/overview), then [Task](schema/task), [Habit](schema/habit) and [Anchor](schema/anchor).
- **How it decides things:** [Architecture overview](architecture/overview) and the [Rules engine](architecture/rules-engine).
- **Why things are the way they are:** [ADR 0001: Anchor object type](architecture/decisions/0001-anchor-object-type) and [ADR 0002: Reconciling the earlier planning](architecture/decisions/0002-reconcile-master-summary-v2).
- **How it looks:** [ThreadsKit usage](design/threadskit-usage).
- **What happens when:** [Roadmap](roadmap/phases).

## Status

Docs-first: the schema, flows and rules engine are specified and the schema is a freeze candidate. Implementation starts from these pages — see the [Roadmap](roadmap/phases). Decisions still open are listed at the bottom of [App flow](journeys/app-flow).
