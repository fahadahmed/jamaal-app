# Screen gallery

What the app looks like, screen by screen: the **design** (the v4 frames from Claude Design, the visual truth) beside the **built** app (screenshots of the real app on the iPhone and iPad simulators, with sample data). Every frame has an ID such as `TD-01`, and the [Screens and flows register](screens) lists what each one is for and how it behaves. How the pieces behind them fit together is in [Diagrams](../architecture/diagrams).

Where the built screen differs from the frame, the difference is recorded in [Design v4 reconciliation](../design/v4-reconciliation). The Mac is shown as designed only: it cannot be screenshotted from the build tooling.

## Today

### Today (TD-01)

One list, just today: the headline and the capacity meter and slider, then Anchors, Habits and Tasks. Detail: [Today list](today-list).

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/1-today-capture/TD-01-today-default.png" width="230" alt="Today (TD-01) design"><br><sub>Design</sub></td><td align="center" valign="top"><img src="../images/app-iphone-today.png" width="230" alt="Today (TD-01) built"><br><sub>Built</sub></td></tr></table>

### Add a task (TK-01)

The capture sheet: effort, how much it matters, when, then category and repeat. Task or Anchor at the top.

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/1-today-capture/TK-01-add-task.png" width="230" alt="Add a task (TK-01) design"><br><sub>Design</sub></td><td align="center" valign="top"><img src="../images/app-iphone-add-task.png" width="230" alt="Add a task (TK-01) built"><br><sub>Built</sub></td></tr></table>

### Focus session (FS-02)

The timer for the task in hand, with its checklist. Overrun is a state, never an alarm. Detail: [Today list](today-list#focus-chip-and-sessions).

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/2-timer/FS-02-focus-running.png" width="230" alt="Focus session (FS-02) design"><br><sub>Design</sub></td><td align="center" valign="top"><img src="../images/app-iphone-focus.png" width="230" alt="Focus session (FS-02) built"><br><sub>Built</sub></td></tr></table>

## Habits and Anchors

### Habits (HB-01)

Habits by group, each with its density grid: a grid of days, never a streak. Detail: [Habit](../schema/habit).

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/3-habits-anchors/HB-01-habits-overview.png" width="230" alt="Habits (HB-01) design"><br><sub>Design</sub></td><td align="center" valign="top"><img src="../images/app-iphone-habits.png" width="230" alt="Habits (HB-01) built"><br><sub>Built</sub></td></tr></table>

### Anchors (AN-01)

Rules for the things your day moves around: prayer times, the school run, bin night, plants. (Built: sample data with a test location, so the prayer time is not yours.) Detail: [Anchor](../schema/anchor).

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/3-habits-anchors/AN-01-rules-list.png" width="230" alt="Anchors (AN-01) design"><br><sub>Design</sub></td><td align="center" valign="top"><img src="../images/app-iphone-anchors.png" width="230" alt="Anchors (AN-01) built"><br><sub>Built</sub></td></tr></table>

## Night Planning

Five steps, one a screen, with a way out at every step. Detail: [Night Planning](night-planning).

### Review today (NP-01)

Step 1: a read-only look back at the day.

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/4-night-planning/NP-01-review-today.png" width="230" alt="Review today (NP-01) design"><br><sub>Design</sub></td><td align="center" valign="top"><img src="../images/app-iphone-plan-review.png" width="230" alt="Review today (NP-01) built"><br><sub>Built</sub></td></tr></table>

### Check the load (NP-04)

Step 4: choose tomorrow's capacity against what is planned.

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/4-night-planning/NP-04-check-the-load.png" width="230" alt="Check the load (NP-04) design"><br><sub>Design</sub></td><td align="center" valign="top"><img src="../images/app-iphone-plan-load.png" width="230" alt="Check the load (NP-04) built"><br><sub>Built</sub></td></tr></table>

## Wellbeing and Settings

### Wellbeing (WB-01)

A steady, plain read of the week with patterns, never a grade.

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/5-wellbeing-settings-onboarding/WB-01-wellbeing-steady.png" width="230" alt="Wellbeing (WB-01) design"><br><sub>Design</sub></td><td align="center" valign="top"><img src="../images/app-iphone-wellbeing.png" width="230" alt="Wellbeing (WB-01) built"><br><sub>Built</sub></td></tr></table>

### Settings (ST-01)

Capacity and day, notifications, categories, appearance, subscription and privacy.

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/5-wellbeing-settings-onboarding/ST-01-settings.png" width="230" alt="Settings (ST-01) design"><br><sub>Design</sub></td><td align="center" valign="top"><img src="../images/app-iphone-settings.png" width="230" alt="Settings (ST-01) built"><br><sub>Built</sub></td></tr></table>

## iPad and Mac

Regular width gets a sidebar, the task detail beside the list, and Night Planning on a wide canvas. Detail: [App flow](app-flow#adaptive-layout-ipad-and-mac).

### Today on the iPad (TD-01 with TK-02)

The list with the open task's detail beside it.

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/6-ipad-duo-macos/iPad-TD-01-TK-02.png" width="420" alt="Today on the iPad (TD-01 with TK-02) design"><br><sub>Design</sub></td><td align="center" valign="top"><img src="../images/app-ipad-today.png" width="420" alt="Today on the iPad (TD-01 with TK-02) built"><br><sub>Built</sub></td></tr></table>

### Habits on the iPad

A list and a detail pane, with a placeholder until something is picked.

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/6-ipad-duo-macos/iPad-HB-02-habits.png" width="420" alt="Habits on the iPad design"><br><sub>Design</sub></td><td align="center" valign="top"><img src="../images/app-ipad-habits.png" width="420" alt="Habits on the iPad built"><br><sub>Built</sub></td></tr></table>

### Build tomorrow on the wide canvas (NP-07)

A step rail beside the open step, and the day drawn as a bar.

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/4-night-planning/NP-07-wide-build.png" width="420" alt="Build tomorrow on the wide canvas (NP-07) design"><br><sub>Design</sub></td><td align="center" valign="top"><img src="../images/app-ipad-plan-build.png" width="420" alt="Build tomorrow on the wide canvas (NP-07) built"><br><sub>Built</sub></td></tr></table>

### The Mac (macOS-TD-01)

A real sidebar and the same list, with menu commands for the keyboard. Settings is in the app menu.

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/6-ipad-duo-macos/macOS-TD-01.png" width="560" alt="The Mac (macOS-TD-01) design"><br><sub>Design</sub></td></tr></table>

## Widgets

The Next Anchor widget in each of its states. Detail: [Widgets and the watch](../architecture/widgets-and-watch), [what the frames decided](../design/widgets-and-watch-reconciliation).

### Next Anchor, small (WG-01)

Open, upcoming, closing soon, none left, and needs attention. (Built: the debug gallery, which draws the same views as the widget.)

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/8-widgets/WG-01-next-anchor-home.png" width="520" alt="Next Anchor, small (WG-01) design"><br><sub>Design</sub></td><td align="center" valign="top"><img src="../images/app-iphone-widgets.png" width="230" alt="Next Anchor, small (WG-01) built"><br><sub>Built</sub></td></tr></table>

## Apple Watch (v1.1)

A companion app is planned for v1.1: Today, Anchors, the habit counter and the focus timer, fed by a small snapshot from the phone. Detail: [Widgets and the watch](../architecture/widgets-and-watch).

<table><tr>
<td align="center" valign="top"><img src="../../mockups/screens/9-watch/WA-01-today.png" width="520" alt="Watch Today"><br><sub>WA-01 Today</sub></td>
<td align="center" valign="top"><img src="../../mockups/screens/9-watch/WA-04-focus.png" width="520" alt="Watch Focus"><br><sub>WA-04 Focus</sub></td>
</tr></table>

## Onboarding and subscription

The first run, one decision a screen. Detail: [Onboarding](onboarding).

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/5-wellbeing-settings-onboarding/OB-02-the-idea.png" width="150" alt="OB-02-the-idea"><br><sub>OB-02-the-idea</sub></td><td align="center" valign="top"><img src="../../mockups/screens/5-wellbeing-settings-onboarding/OB-04-normal-day.png" width="150" alt="OB-04-normal-day"><br><sub>OB-04-normal-day</sub></td><td align="center" valign="top"><img src="../../mockups/screens/5-wellbeing-settings-onboarding/OB-05-reminders.png" width="150" alt="OB-05-reminders"><br><sub>OB-05-reminders</sub></td><td align="center" valign="top"><img src="../../mockups/screens/5-wellbeing-settings-onboarding/OB-06-first-task.png" width="150" alt="OB-06-first-task"><br><sub>OB-06-first-task</sub></td><td align="center" valign="top"><img src="../../mockups/screens/5-wellbeing-settings-onboarding/OB-08-first-anchor.png" width="150" alt="OB-08-first-anchor"><br><sub>OB-08-first-anchor</sub></td><td align="center" valign="top"><img src="../../mockups/screens/5-wellbeing-settings-onboarding/OB-09-ready.png" width="150" alt="OB-09-ready"><br><sub>OB-09-ready</sub></td></tr></table>

### The paywall (SB-01)

When the trial ends the app goes read-only, never locked. Detail: [App flow](app-flow#trial-and-subscription).

<table><tr><td align="center" valign="top"><img src="../../mockups/screens/5-wellbeing-settings-onboarding/SB-01-paywall.png" width="230" alt="The paywall (SB-01) design"><br><sub>Design</sub></td></tr></table>
