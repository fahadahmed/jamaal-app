# Widgets and the watch

How Jamaal appears outside the app: the **v1 widgets** and the **v1.1 watch companion**. The decision and its reasons are in [ADR 0003](decisions/0003-widgets-in-v1-watch-in-v1-1). The frames are drawn (batches 8 and 9, `WG-` and `WA-` in the [register](../journeys/screens)); what they decided is in the [reconciliation](../design/widgets-and-watch-reconciliation). Where this page and the frames differ on detail, the frames win and this page is updated to match.

## v1 widgets: scope

| Widget | Sizes | Shows | Tap |
|---|---|---|---|
| **Next Anchor** | Small; Lock Screen circular, rectangular and inline | The current or next Anchor window: *Dhuhr · until 15:32*, *School run opens 15:00* | Opens Today |
| **Today** | Small, medium, large | The headline (*Four things, gently paced.*), the capacity bar, the next two or three tasks (more on large) | Opens Today (a task opens its detail on a wide layout) |

On iPhone, iPad and Mac (desktop and Notification Center). *Plan tomorrow* (which opens Night Planning) appears from the planning time on the **medium and large** Today widget only, never on the Lock Screen, and is the **only terracotta on any widget**. Not in v1: interactive habit logging, Control Center controls, StandBy-specific designs, Live Activity.

Rules for what a widget shows: the same words and figures as the app (it reuses the engine's reads), no streaks, no red, **no Wellbeing score**, nothing that nags. A day that has nothing in it says so calmly.

**What the frames decided (widgets)** (`WG-01` to `WG-06`; the numbered list is in the reconciliation):
- **No checkboxes:** v1 widgets aren't interactive, so a task shows a category dot (a primary-coloured dot when tinted), never a check circle.
- **Accent group:** `widgetAccentable()` goes on the Anchor name, Today's count, the italic headline line and the bar fills; everything else is primary.
- **Next Anchor states:** upcoming; open; **closing soon** (keeps the accent colour; only the word and the bar's length change); none left today; **needs attention** (a window that closed unmarked: a neutral full bar and *Not marked yet*, neither accent nor error).
- **Today states:** normal; **all done** (the capacity bar is hidden; *4 of 4 done* and the next Anchor); **blank day** (the next Anchor and no "add something" prompt); evening with *Plan tomorrow*; **read-only** (the same data, no *Plan tomorrow*, one quiet *View only* line, and no upgrade prompt on a widget).
- **Dynamic Type at accessibility sizes:** the medium drops its headline to the count and shows one task, truncated to one line.
- **Habits stay off the large widget for now** (provisional; *owner to confirm*).
- On the Mac the widget is full colour when the desktop is focused and vibrant with a window in front.

## The data: `WidgetSnapshot`

A pure, `Codable`, device-independent value in JamaalCore (no UI, no SwiftData objects), built from the engine's existing Today reads:

- `generatedAt`, the logical day it describes, and `isReadOnly` (the trial ended without a subscription)
- the headline count of tasks left, and the capacity (planned minutes, budget, level, load state)
- the count of tasks left and done, and the first *N* of what is left in Today's order (id, title, effort, category colour key), with how many more there are; the done tasks are only counted
- the next *N* Anchors still to attend, as windows: id, name, the rule's title when there is one, phase (`open`, `closingSoon`, `upcoming`, or `needsAttention` for a closed window nobody marked), start, end, progress. Attended, skipped and delegated ones are left out; open ones come first, then upcoming, then unmarked ones
- the evening planning time and whether it has passed (the link is offered only when not read-only), and when the logical day ends

Built as `WidgetSnapshot.make(in:now:access:)` in JamaalCore. It only reads: it never marks a prompt as shown.

It is tested like any engine module. The phone's and iPad's widgets, the Mac's, and the watch all use it.

## The timeline

A widget does not tick. Its entries are computed ahead for the moments that change what it says: now; each Anchor window opening and closing in the next day; the evening planning time; the logical-day rollover. At most about a dozen entries, then the system asks again. The app reloads every timeline after a save (the same hook that re-plans notifications), when it comes to the foreground, when a sync brings changes, and when the access state changes. The system limits how often a widget may refresh, so nothing here depends on a per-minute update. After a sync a widget can be stale until the next refresh; it shows data as of the last one.

## Opening the app

Widgets use a `jamaal://` link: `jamaal://today`, `jamaal://plan` (Night Planning), `jamaal://task/<id>`. The app turns a link into the same route a notification tap uses, so there is one path in.

## Privacy and rendering

- **Task titles are marked privacy-sensitive**, so they are hidden on the Lock Screen while the device is locked. Anchor titles (a prayer name, the school run) show on a locked Lock Screen, because the Next Anchor widget is useless without them; `WG-05` draws it that way (*owner to confirm*). Redacted titles are drawn as a plain bar, on a locked Lock Screen, in StandBy and on an iPad Lock Screen.
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

### Navigation and screens (as drawn in `WA-00` to `WA-04`)

- **Navigation:** three vertical pages (**Today · Anchors · Habits**), at most one level of push, and **Focus as a full-screen cover**. No tab bar.
- **Launch rule:** a running session opens Focus; otherwise an open, unmarked Anchor window opens Anchors; otherwise Today. After an hour away the rule runs again.
- **Task detail exists on the watch:** *Begin* is the filled button and *Done* is glass; the checklist is read-only; *More on your iPhone* points the way to defer and drop.
- **Finish** offers the finish sheet's two choices, **Done** and **Stop for now**; defer, drop and the note line stay on the phone.
- **Anchors:** *Attended* is the filled action, and a long-press on a row gives *Attended* or *Skipped*. The app says the time left in words (*40 min left*); complications show the clock time.
- **Counted habits** are saved as you turn the crown, debounced into one queued action; past the target the ring stays full and the number keeps going.
- **Pending state:** a queued action shows a dashed ring and *waiting for iPhone*; an *As of 14:20* footer appears only after 15 minutes without a snapshot.
- **First run:** before the first snapshot arrives, Today says *Open Jamaal on your iPhone to begin.* Read-only users see the pages with no action buttons.
- **40 mm:** the primary button is 40 pt tall there, the only place below 44.
- **Icon:** the existing monogram layers with a circular mask, one appearance, and the small-size J at list and notification sizes.

### How it works (option 1: companion)

- The **iPhone owns the store.** It sends the latest `WidgetSnapshot` to the watch with `updateApplicationContext` (latest wins). The watch app and its complications read it from the watch's own container and reload their timelines.
- The watch **sends actions back** (complete a task, change a habit's amount, begin, pause or finish a focus session, attend an Anchor) with `transferUserInfo`, so they queue while the phone is out of reach. Each carries an id and a time, so applying one twice is harmless. The phone applies them through the **same engine functions the app uses**, then sends a new snapshot. If the two disagree the phone wins, and the watch shows a pending mark until it hears back.
- **Focus on the watch:** the timer uses a running-time text so it stays correct, and an extended-runtime session keeps the app alive while a session runs. A session started on the watch is created on the phone, so the one-live-session rule, the chip and (later) the Live Activity stay consistent. If the phone is out of reach the watch keeps its own start time and tells the phone when it reconnects.

An independent watch app (its own store, synced through CloudKit as a fourth device) is possible later and would need the engine, conflict handling and migrations on the watch.

### What it needs

The watchOS platform added to JamaalCore (its manifest lists iOS and macOS today; it imports only Foundation, SwiftData and the prayer-times library, so it should compile) and to ThreadsKit (iOS and macOS today; to be checked), a watchOS 27 simulator runtime (only 10.4 is installed), a watch app target embedded in the iOS app, a Design pass for the watch screens, and the owner's Apple Watch for testing (it takes a device slot on the paid programme).

## Open questions

Settled by the frames and the owner (see the reconciliation): Live Activity stays v1.1; the Next Anchor complication shows the closing clock time and not a draining ring.

Still **owner** sign-offs (the frames assume them):
- **Anchor titles visible on a locked Lock Screen** (proposed and drawn: yes).
- **Habits off the large Today widget** for now (provisional).
