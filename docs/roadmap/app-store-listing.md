# App Store listing

The text for the first version's page in App Store Connect (#377). Copy each block as it is. The limits are App Store Connect's, and each count below was checked. The voice is the product's own: calm, no urgency, no exclamation marks, no streaks (see the [TestFlight email brief](../design/testflight-emails-brief) and the [Home page](../Home)).

**Not claimed anywhere, because it is not built:** the Apple Watch app, Live Activity, sharing or referral, tvOS. **iPhone Duo is not mentioned** either: it is not a shipping device, so the public page would only confuse.

## Fields

| Field | Limit | Value |
|---|---|---|
| **Name** | 30 | `Jamaal` (the app record's name; `Jamaal: Daily Planner` is 21 characters if you want "planner" indexed, and the subtitle already carries the idea) |
| **Subtitle** | 30 | `Calm tasks, habits and anchors` (30) |
| **Promotional text** | 170 | see below (159); it can be changed without a new version |
| **Keywords** | 100 | see below (97); comma-separated, no spaces; words already in the name, subtitle and category are ignored |
| **Description** | 4000 | see below (2432) |
| **What's new** | 4000 | see below (217) |
| **Support URL** | | `https://jamaal.app/support` |
| **Marketing URL** | | `https://jamaal.app` |
| **Privacy Policy URL** | | `https://jamaal.app/privacy` |
| **Copyright** | | `2026 Fahad Ahmed`, or the legal name you publish under (yours to confirm) |
| **Primary category** | | Productivity (already set). A secondary category is optional: Lifestyle fits |
| **Age rating** | | 4+ (already set) |
| **App Privacy** | | **Data Not Collected** (the app has no account and no server; the diagnostics stay on the device) |

## Promotional text

```
One list for today. Plan tomorrow tonight, keep habits as a grid of days instead of streaks, and let prayer times and the school run set the shape of your day.
```

## Keywords

```
planner,todo,task,habit,tracker,routine,focus,prayer,salah,reminder,daily,schedule,night,planning
```

## Description

```
Jamaal is a calm planner for one list: just today.

Tasks, habits and the things your day moves around live together on a single Today list, so you stop bouncing between a reminder app, a task app and a calendar. Nothing nags. There are no streaks, no scores to chase and no projects to maintain.

TODAY
One flat list for personal, family and work. Say how much energy today has, and Jamaal shows what fits: if there is too much, it says so plainly and helps you choose what waits. A task that keeps slipping gets a gentle question, not a red mark.

NIGHT PLANNING
A short guided close to the day: look back, carry over what is left, set up tomorrow and check the load. Five quiet steps, and you can skip it any night.

HABITS WITHOUT STREAKS
Binary, counted, timed or "avoid", each shown as a grid of days, so a missed day is one empty square, not a broken chain. Pause a habit for travel or illness and it simply waits.

ANCHORS
Some things are not yours to schedule: prayer times, the school run, bin night, watering the plants. Anchors hold them as a rule, window by window, and you mark each one attended, missed or skipped. Prayer times are worked out for where you are.

FOCUS
Begin a task and a timer runs while its checklist stays in view. Pause, finish, or come back to it later.

WIDGETS
See your next Anchor or today's list from the Home Screen, the Lock Screen and the Mac desktop.

ON ALL YOUR DEVICES
iPhone, iPad and Mac, kept in step through your own iCloud. Jamaal has no account and no server. Everything you add stays on your devices and in your iCloud, and you can export or delete it whenever you like.

A GENTLE COMPANION
Jamaal is also the voice you hear: calm, supportive and never judgmental. It notices patterns and offers a suggestion when one helps, and otherwise stays out of the way.

TRY IT FREE
Jamaal is free to download with a 14-day full trial, and no payment details are asked up front. After the trial, ticking things off, logging habits, marking Anchors and running a timer keep working. Adding, editing and Night Planning need a subscription: $2.99 a month or $24.99 a year. Payment is charged to your Apple Account, and a subscription renews automatically unless you cancel at least 24 hours before the period ends. Manage or cancel it in your Apple Account settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://jamaal.app/privacy
```

## What's new

```
The first release of Jamaal: one list for today, Night Planning, habits as a grid of days, Anchors for prayer times and the school run, a focus timer, widgets, and sync across iPhone, iPad and Mac through your iCloud.
```

## What each part of the description rests on

| Sentence about | In the app |
|---|---|
| One flat list, energy and load, "what fits" | Today, the capacity slider, the load state and *Day is full* (`docs/journeys/today-list.md`) |
| A slipping task gets a question | The third deferral opens a date picker and the fifth suggests removing it (`CLAUDE.md`, product principles) |
| Night Planning, five steps, skippable | The wizard: review, carry, build tomorrow, check the load, close the day |
| Four habit kinds, grid of days, pause | `Habit` kinds binary, counted, timed, avoid; density grid, no streaks; pause with a reason |
| Anchors: attended, missed, skipped; prayer times for where you are | `AnchorRule`, attendance, the prayer-times rule with the user's location |
| Focus timer with its checklist | The focus screen and the note's checklist |
| Widgets: Home Screen, Lock Screen, Mac | Next Anchor and Today widgets, with the Lock Screen accessory widgets |
| iPhone, iPad and Mac through your own iCloud; no account, no server; export and delete | CloudKit sync, *Privacy and your data* |
| 14-day trial with no payment details; what keeps working after it; $2.99 a month or $24.99 a year; renewal and cancel wording | The app-managed trial, read-only mode, the two plans, and the paywall's renewal text (guideline 3.1.2) |

If a sentence stops being true, change it here and on the page together.

## Still yours to decide

- **Name**: keep `Jamaal`, or add words after it.
- **Copyright holder**: your name or a company.
- **Secondary category.**
- The **screenshots and previews** are tracked in #362 and the **review notes** come later.
