# Widgets and the watch

How Jamaal appears outside the app: the **v1 widgets** and the **v1.1 watch companion**. The decision and its reasons are in [ADR 0003](decisions/0003-widgets-in-v1-watch-in-v1-1). Frames are still to be drawn: see the [Design brief](../design/widgets-and-watch-brief).

## v1 widgets: scope

| Widget | Sizes | Shows | Tap |
|---|---|---|---|
| **Next Anchor** | Small; Lock Screen circular, rectangular and inline | The current or next Anchor window: *Dhuhr · until 15:32*, *School run opens 15:00* | Opens Today |
| **Today** | Small, medium, large | The headline (*Four things, gently paced.*), the capacity bar, the next two or three tasks (more on large) | Opens Today (a task opens its detail on a wide layout) |

On iPhone, iPad and Mac (desktop and Notification Center). In the evening the Today widget can offer *Plan tomorrow*, which opens Night Planning. Not in v1: interactive habit logging, Control Center controls, StandBy-specific designs, Live Activity.

Rules for what a widget shows: the same words and figures as the app (it reuses the engine's reads), no streaks, no red, **no Wellbeing score**, nothing that nags. A day that has nothing in it says so calmly.

## The data: `WidgetSnapshot`

A pure, `Codable`, device-independent value in JamaalCore (no UI, no SwiftData objects), built from the engine's existing Today reads:

- `generatedAt`, the logical day it describes, and `isReadOnly` (the trial ended without a subscription)
- the headline count of tasks left, and the capacity (planned minutes, budget, level, load state)
- the first *N* tasks: id, title, effort, category colour key, done or not (and how many more there are)
- the next *N* Anchors: id, title, state (upcoming, open, closing), window start and end
- the evening planning time and whether it is due

It is tested like any engine module. The phone's and iPad's widgets, the Mac's, and the watch all use it.

## The timeline

A widget does not tick. Its entries are computed ahead for the moments that change what it says: now; each Anchor window opening and closing in the next day; the evening planning time; the logical-day rollover. At most about a dozen entries, then the system asks again. The app reloads every timeline after a save (the same hook that re-plans notifications), when it comes to the foreground, when a sync brings changes, and when the access state changes. The system limits how often a widget may refresh, so nothing here depends on a per-minute update. After a sync a widget can be stale until the next refresh; it shows data as of the last one.

## Opening the app

Widgets use a `jamaal://` link: `jamaal://today`, `jamaal://plan` (Night Planning), `jamaal://task/<id>`. The app turns a link into the same route a notification tap uses, so there is one path in.

## Privacy and rendering

- **Task titles are marked privacy-sensitive**, so they are hidden on the Lock Screen while the device is locked. Anchor titles (a prayer name, the school run) show, because the Next Anchor widget is useless without them. *Owner to confirm.*
- Full-colour, tinted (accented) and Lock Screen (vibrant) rendering are all designed for. Fonts are bundled into the extension.
- A widget needs no network. Read-only users see the same data with no editing prompts.

## Where the store lives

The SwiftData store moves into an **App Group container**, with the **CloudKit container set-up, in the first sync-enabled build**, so no user ever migrates. The in-memory test and debug modes are unaffected. On the Mac the group identifier is team-prefixed.

## Targets

One widget extension target for iOS and macOS, built on JamaalCore and ThreadsKit (and the same fonts). It needs its own App ID, the App Groups capability on the app and the extension, and the paid programme.

## Order of work

1. **Before the paid programme (no entitlements needed):** these docs and the Design brief; `WidgetSnapshot` and the timeline logic in JamaalCore with tests; the `jamaal://` routing in the app.
2. **After it (about 14 October):** the App Group, the store move and the CloudKit container in one change; the extension target; **Next Anchor** first, then **Today**, then the Lock Screen widgets, then the Mac.
3. **Then:** apply Design's frames, check VoiceOver and Dynamic Type, and TestFlight with widgets.

## The watch companion (v1.1)

### What the user gets

- **Today:** the next task large; tap to mark it done (one soft haptic, as the design rules say); the Digital Crown scrolls the rest.
- **Anchors:** the current window and the time left, and a Smart Stack card that surfaces at the right time of day.
- **Habits:** Water counted with the crown; *Held today* and *Slip* for avoid habits; a tick for the rest; *Begin* on a timed habit.
- **Focus timer:** Begin, pause and finish, with the time in large digits and a soft haptic at the end.
- **Complications**, in priority order:
  1. **Next Anchor** (the primary one): inline *Dhuhr · until 15:32*; rectangular, the Anchor and its window with the next one beneath; corner, curved text with a soft arc for how much of the window has passed; circular, a ring with the closing time in the middle. It shows the **clock time the window closes**; *closes in 40 min* appears only in the larger rectangular size. No draining ring and no urgent colour: nothing should demand attention.
  2. **Today:** circular, a ring of planned time against the day's budget with the number of tasks left inside; rectangular, the next task and its effort. Task titles are privacy-redacted while the watch is locked.
  3. **Focus timer**, only while a session runs: a count-up time that opens the focus screen, surfacing in the Smart Stack.
  4. **A habit counter** (*Water 3 of 8* as a ring) is later: choosing the habit needs a configurable widget, which brings in App Intents.
  - Not on a face: the Wellbeing score, anything streak-like, an overdue count. An open Anchor window is the natural moment for the **Smart Stack** to surface its card by itself.
- **Notifications:** the window-closing and evening reminders already mirror from the iPhone; Mark done can become an action.

Not on the watch: Night Planning, Wellbeing (a score on the wrist would feel judgemental), Settings, and adding a task (a dictated quick add is a later decision, because it needs defaults for effort and importance).

### How it works (option 1: companion)

- The **iPhone owns the store.** It sends the latest `WidgetSnapshot` to the watch with `updateApplicationContext` (latest wins). The watch app and its complications read it from the watch's own container and reload their timelines.
- The watch **sends actions back** (complete a task, change a habit's amount, begin, pause or finish a focus session, attend an Anchor) with `transferUserInfo`, so they queue while the phone is out of reach. Each carries an id and a time, so applying one twice is harmless. The phone applies them through the **same engine functions the app uses**, then sends a new snapshot. If the two disagree the phone wins, and the watch shows a pending mark until it hears back.
- **Focus on the watch:** the timer uses a running-time text so it stays correct, and an extended-runtime session keeps the app alive while a session runs. A session started on the watch is created on the phone, so the one-live-session rule, the chip and (later) the Live Activity stay consistent. If the phone is out of reach the watch keeps its own start time and tells the phone when it reconnects.

An independent watch app (its own store, synced through CloudKit as a fourth device) is possible later and would need the engine, conflict handling and migrations on the watch.

### What it needs

The watchOS platform added to JamaalCore (its manifest lists iOS and macOS today; it imports only Foundation, SwiftData and the prayer-times library, so it should compile) and to ThreadsKit (iOS and macOS today; to be checked), a watchOS 27 simulator runtime (only 10.4 is installed), a watch app target embedded in the iOS app, a Design pass for the watch screens, and the owner's Apple Watch for testing (it takes a device slot on the paid programme).

## Open questions

- Anchor titles visible on the locked Lock Screen: yes (proposed) or hidden too?
- Live Activity stays v1.1 (proposed).
- Whether the Today widget's large size shows habits as well as tasks.
