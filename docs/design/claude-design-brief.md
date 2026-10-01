# Claude Design brief

> **Status: draft for the owner.** Written to be pasted into the Claude Design project ("Jamaal screens redesign"). It is self-contained because Claude Design cannot read this repo. **Precedence: styling comes from the Design project** — the v3 screens, the tokens page and the flow spec — **unless it conflicts with functionality locked in this repo.** This brief overrides Design only in those conflicts (§3); everything else about look, layout, type, colour and tone stays as Design has it. The repo docs it summarises are the source of truth for functionality: [App flow](../journeys/app-flow), [Today](../journeys/today-list), [Night Planning](../journeys/night-planning), [Onboarding](../journeys/onboarding), the [Schema overview](../schema/overview), the [Rules engine](../architecture/rules-engine) and [ThreadsKit usage](threadskit-usage).

## 1. What to produce

- A **revised screen set**, phone first (iOS), then the iPad two-panel layout, then iPhone Duo. macOS follows the iPad regular-width layout afterwards.
- Keep the v3 visual vocabulary: content sits on paper, separated by space and hairlines; glass appears only where you act (tab bar, sheets, steppers, slider thumbs); no containers around content.
- For every screen, **number it against the inventory in §7** so it is clear what it replaces or adds.
- Update the tokens page to match §4 (it is already close: this brief adds the pieces ThreadsKit 1.1.0 now ships).

## 2. The product in one minute

**One list. Just today. Beautifully ordered.** Jamaal is a calm-focus app for iPhone, iPad and Mac. A single Today list spans personal, family and work. Each evening a short Night Planning decides what belongs on tomorrow. **Jamaal is also the companion voice**: calm, supportive, non-judgmental, shown only as inline cards and empty states — never a chat interface.

Three primitives, each tracked differently:

| | You… | Tracked by | Example |
|---|---|---|---|
| **Task** | do it | completion | "Call the clinic back" |
| **Habit** | cultivate it | **density** (a grid of days), never streaks | reading, water, 20 minutes of running |
| **Anchor** | move around it | attendance | prayer times, the school run, bin night, a dentist appointment |

Principles that shape every screen:

- **One flat list.** No projects, boards or tags. A category is a coloured label plus an optional filter, never a section.
- **Nothing nags, nothing punishes.** No streaks, no "best", no red severity colours, no guilt. A miss is a quiet mark, not a failure.
- **The planner may defer your tasks, never your fixed commitments.** An overloaded day is always resolved by moving tasks.
- **Soft, never blocking.** Overflow, overload and "doesn't fit" are named in plain words with one tap to fix — nothing is refused.

## 3. Where Design conflicts with locked functionality

**Everything visual is Design's call.** The items below are the only places this brief overrides Design, and each is here because a choice in the Design files contradicts functionality decided in this repo. Fix these; leave the rest of the styling as drawn.

1. **Name: "Anchors", not "rituals".** The flow spec and tokens page call the third primitive a ritual. The product name is Anchor; relabel everywhere.
2. **No streaks anywhere.** v3's two habit detail screens (14, 15) show "18 streak · 31 best". Remove the three-number row and give its space to the plain-language read; keep the density grid.
3. **Copy that contradicts how the app works:**
   - Onboarding "Everything stays on device" — the app syncs through the user's own iCloud. Suggested: *"Kept in your own iCloud."*
   - Onboarding's "not" list shows "Tags, labels, filters" — categories exist as labels with an optional filter. Suggested: *"Projects and boards"* and *"Streaks and guilt"*.
   - Onboarding "I'll speak twice a day. Nothing else, ever." — habit and Anchor reminders, and a rare trial reminder, can exist (opt-in or few). Suggested: *"Once at night to plan, once in the morning with your list. Anything else is yours to switch on."*
   - (The owner decides the final wording; these show the facts the copy must respect.)
4. **Capacity needs a level control.** v3 shows minutes only ("2h 15m of 3h"). Keep that as *budget used*, and add the **low / medium / high** control (§6). The Preferences screen's "Learned from 34 days / Energy by day" becomes: normal-day length, **default level per weekday** (weekends low), working-day start and end, and — under Advanced — the day-rollover time.
5. **Night Planning's flow** follows §7 (five steps, no mood line, tomorrow's gaps, *Skip tonight*), and the wide layout keeps **Keep / Later / Drop per task** — important tasks can't be parked as Someday, so "leftovers go back to the backlog" can't stand.
6. **Habit groups stay** as a purely visual bundle; screen 18 keeps a naming form.
7. **Navigation chrome is the system component.** v3 draws a floating tab capsule; it must be the system tab bar and toolbars with the Liquid Glass look, because the system bar is what moves to the side on iPhone Duo and becomes a sidebar on iPad.
8. **Importance is three levels and dropping is soft.** v3 draws importance as "Matters 4 of 5" and offers "Edit / Delete". Redraw importance as **low / medium / high** and call the action **Drop** (it is a soft delete with a 5-second undo).
9. **Natural-language capture is not adopted yet.** Flow screens A-02, A-03 and A-05 (live parse, ambiguous date, "landed") are out of scope until decided. Only A-04 is adopted, as **"Day is full · offer tomorrow"**.

### Design's own inconsistencies — resolve inside Design

These are not functional conflicts, so they are Design's to settle. Suggestions are given, but the call is Design's.

- **Primary button colour.** v3 draws an ink pill; the tokens page says terracotta is the only filled button colour, one per surface. Suggestion: follow the tokens page — it is the later, deliberate statement and the Done / Defer / Drop sheet depends on it.
- **Empty and finished states.** v3 screens 03 and 04 draw richer copy (and 04 has a *Plan tomorrow* button); the tokens page fixes four single-line empty states and says an empty list is never a call to action. Suggestion: follow the tokens page, and keep *Plan tomorrow* as a quiet text action after the planning time since it is an entry point.
- **The old ceramic design-system bundle** (`_ds/threads-design-system-…`: bone / ink / terracotta / sage, status colours, Bricolage Grotesque) is still in the project and linked from the screens, although the screens override it inline and the tokens page has replaced it. Suggestion: remove it so it can't leak back in.

## 4. Design system — what to draw with

**These are Design's own tokens** (from its tokens page and v3), as shipped in ThreadsKit 1.1.0. Light / dark values:

| Token | Role | Light | Dark |
|---|---|---|---|
| `app` | Page background | `#EFF4F0` | `#12303F` |
| `card` | Card, panel, sheet | `#FFFFFF` | `#FFFFFF` @ 5% |
| `ink` | Titles, primary text and icons | `#0A3A53` | `#E7F1F4` |
| `ink2` | Body | `#14506E` | `#BCD3DA` |
| `ink3` | Labels, quiet text (the contrast floor, 5.0:1) | `#3F6E80` | `#8FAAB4` |
| `terra` | The action — the only filled button, a decision being asked for | `#9A4F2E` | `#DDA080` |
| `terraPress` | Pressed fill for `terra` | `#7E3F24` | `#C08868` |
| `accent` | What is settled — done, logged, completed | `#1F6A58` | `#8FCBB8` |
| `accentPress` | Pressed fill for `accent` | `#175245` | `#74B3A0` |
| `onAccent` | Text on a filled `terra` / `accent` | `#EAF3F6` | `#16242E` |
| `deep` | Deepest surface | `#0C4767` | `#071B27` |
| `onDeep` | Text on `deep` | `#EAF3F6` | `#EAF3F6` |
| `glassOn` (the design's `selected`) | Opaque selected-row fill | `#FFFFFF` | `#1D4052` |
| `glass` | Glass material tint | `#FFFFFF` @ 62% | `#FFFFFF` @ 9% |
| `line` / `line2` | Hairline / stronger border | `#0A3A53` @ 14% / 24% | `#E7F1F4` @ 14% / 24% |
| `d1` · `d2` · `d3` | Density steps: light · mid · full | `#D3E3DB` · `#71A393` · `#0C4767` | `#2B4A46` · `#4E7D72` · `#8FCBB8` |
| `missed` | A missed density cell | `#E3BEAB` | `#6B4A38` |
| `alert` / `alertSoft` | Destructive text / soft fill | `#A32E22` / `#F2D4CE` | `#F09A90` / `#5A2A22` |

Colour rules:

- **No status colours.** Success is `accent`, warning is `terra`, a lapsed item is `missed`, info is plain `ink2`. Nothing is greyed out; disabled is opacity 0.42 only.
- **`alert` is for destructive only** — a *soft fill with alert text*, never a filled alert button. Only `terra` is filled, so the eye lands on the safe choice first (the Done / Defer / Drop sheet).
- **Icons take `ink2` or `ink3`**, never an accent unless that accent's meaning applies.
- **Text on a fill uses `onAccent`** (it flips between light and dark themes); never hardcode white.
- **Never tint text to make it quieter** — quiet is `ink3`. No `.opacity()` on text.
- Distinct names may share a hex in dark (terra and the rule colour; accent and `d3`). Keep them as separate tokens.
- **Category labels need a small palette that doesn't exist yet** (see §9). Draw them provisionally with the existing tokens and mark them as placeholders.

**Type** — three families, six roles, sizes rebased so body is 17 pt and everything scales with Dynamic Type:

| Role | Font | Size | Use |
|---|---|---|---|
| label | JetBrains Mono 500, tracked .16em | 12 | eyebrows, chip labels, times (caps at the `.xxLarge` accessibility size) |
| meta | Hanken Grotesk 400 | 15 | secondary row line, counts |
| body | Hanken Grotesk 400 | 17 | all prose |
| row | Hanken Grotesk 600 | 18 | task title, the most-drawn role |
| lede | Hanken Grotesk 400 | 19 | sheet intros, empty states |
| display | Fraunces 500 (SOFT 60, WONK 1; 300 for the two largest) | 28 / 34 / 38 | screen titles, the timer numeral |

Leading is bound to the role: display 1.08, label / meta / row 1.35, body / lede 1.6. The timer numeral uses display with **monospaced digits**. (ThreadsKit doesn't bundle the fonts yet.)

**Space and shape** — screen gutter **26** (a *minimum*: each edge resolves against its own safe area, asymmetric on Duo); gaps 4 / 10 / 14 / 22, with 14 the workhorse; row padding 12 × 14; chip padding 9 × 20 and 12 × 20. Radii: **3** (density cell), **8** (field), **14** (card, selected row), **pill** (every button, chip and checkbox — the signature). Every tappable thing has a **44 pt** hit target; a 22 pt mark keeps an invisible 44 pt area.

**Elevation and material** — light grounds use shadow: *lift* `0 18 40 −26 rgba(6,32,46,.42)` and *float* `0 10 26 −14 rgba(6,32,46,.50)`, plus a 1 pt hairline. Dark grounds use **material, not shadow** (a shadow can't lift a card off a darker ground): neutral `rgba(0,0,0,.70)` `0 22 50 −28` for the lift only. Glass is white at 62% in light and 9% in dark, with a constant blur. No shadows on content.

**States** — **a press never moves anything** (the finger is already covering it): the fill darkens one step (`terraPress` / `accentPress`); a checkbox ring thickens 1.5 → 2.5 pt. Focus is a 2 pt terracotta ring with 3 pt offset (an `alert` ring on destructive). Disabled is opacity 0.42.

**Motion and haptics** — 140 ms for state changes (press, check, chip) and 260 ms for a surface arriving (sheet, screen), both `easeOut(0, 0, .2, 1)`; reduced motion sets both to zero and cross-fades the sheet. Completion is one soft impact; defer and drop are silent; a closing window is a light notification. Nothing buzzes to ask for attention.

**Icons** — 22 pt box, 1.75 pt stroke, round cap and join, no fill. SF Symbols at regular weight match closely; custom drawing is only for the density grid and window bar, which are graphics, not icons.

**Components** — every screen is a composition of these (the list is closed; a new one needs an argument):

| Component | Geometry / rule |
|---|---|
| **TaskRow** | 12 × 14 padding, 14 gap; title (row) + meta line; category as a small coloured label; selected fill at radius 14 |
| **Chip** | 9 × 20 padding, pill; outline by default, **filled only when it is a live timer** |
| **PillButton** | 12 × 20, pill, 44 hit; filled / outline / destructive; **one filled per surface** |
| **SettleSheet** | 26 gutter, radius 14; Done / Defer / Drop, plus an optional one-line note |
| **DensityGrid** | 18 cell, 3 gap, 3 radius; `d1`–`d3` plus `missed`; **fills from the trailing edge**; **never holds a numeral** (a label sits beside the grid) |
| **WindowBar** | 6 tall, pill; Anchor window states upcoming / open / closing soon / closed |
| **CapacityMeter** | 8 tall, pill; budget used; `terra` when overloaded or past the day's end |
| **SectionHeader** | label + 24 rule with the terracotta line prefix — the only decorative mark |
| **Session chip + focus screen** | the running timer, above the tab bar on every tab |
| **Capacity slider** | low / medium / high, glass thumb |
| **Step rail** | Night Planning on wide layouts |

Navigation chrome is the **system** tab bar and toolbars with the iOS 26 Liquid Glass look — not hand-built — so iPad sidebars and iPhone Duo's side-mounted controls adapt automatically. Tab bar: **Today · Habits · Wellbeing · Settings**.

## 5. Voice and copy

- **No exclamation marks, no praise, no guilt, and never second-person about the past.** *"Three of five"*, not *"You missed two!"*. The app states what is true and stops.
- **Empty states — Design's pattern** (tokens page): one `lede` line in `ink3`, centred on plain `app`, no illustration, no button, no encouragement. The four fixed lines: today **"Nothing left for today."** · first launch **"Write the first thing."** · habits **"No habits yet — they'll appear as patterns do."** · history **"Nothing logged yet."** (v3 screens 03 and 04 draw different copy — see §3, Design's own inconsistencies.)
- **Keep the companion lines short and factual**, for example: *"This one keeps slipping. Pick a day that actually works."* · *"Groceries could wait until Wednesday. Want me to move it?"* · *"40 min past 19:00."* · *"Day is full · offer tomorrow."* · *"Maghrib in 12 min."* · *"Tomorrow is ready. Three tasks, 3h exactly. Put the phone down."* · *"No plan for today — two minutes to pick?"*
- Times and counts must be able to render in **Arabic-Indic numerals**; layouts use leading / trailing only and mirror for right-to-left (the density grid fills from the trailing edge; Duo's side controls stay on the same side).

## 6. Behaviour cheat sheet (so the screens are right)

- **Importance** has three levels — low (default), medium, high — set mainly in Night Planning. Choosing medium or high **requires a due date** (pre-filled, can't be cleared) and **hides "Someday"**. A medium or high task deferred for the **3rd** time is eased to low, and the companion says so. Low tasks always sort after medium and high.
- **Deferral** means a task moved to a later day **after its due day has arrived**; rescheduling something due later (pushing tomorrow's task to Thursday, the overload *Move*) is not a deferral. The 1st and 2nd deferral are instant (to tomorrow); from the **3rd** a date picker opens (Later this week / Next week / Someday / a date) with reason chips **Too much on · Not ready · Not relevant**; from the 5th the companion suggests dropping it. At most one deferral per task per day.
- **Capacity** is the user's own call: **low / medium / high**. Medium is their *normal day* (default 3h, set in onboarding), low is two-thirds, high is four-thirds. The budget counts **tasks only**. A separate **free-time** measure takes the working day (default 08:00–19:00) minus fixed Anchors (which cut it into gaps) and the minutes of flexible Anchors and habits. The meter shows **budget used** (*"2h 15m of 3h"*) with a load state (light / balanced / full / overloaded / exhausting), and turns terracotta past the day's end with one tap to move the overflow. A quiet flag appears if a task is longer than the longest gap. Never blocking.
- **Anchors:** recurring rules (prayer times, school run, bin night, plant watering, custom) generate instances; one-offs are added directly. Statuses: **attended · missed · skipped ("Not today") · delegated ("Someone else did it")** — skipped and delegated are not misses. **Attended can only be logged while the window is open**; an upcoming Anchor's control is disabled and says when it opens. A rule that produces several Anchors a day shows as **one collapsed row** ("Salah 3/5 · Asr · until 17:58") that expands. A plants-style rule has a multi-day window and shows every day it is open.
- **Habits** come in four kinds: **binary**, **counted** (stepper), **timed** (a target in minutes; **Begin** uses the same chip; "12 of 20 min") and **avoid** (**Log a slip** and **Held today**; a day fills only if the app was used that day — silence is never success; no days-since-slip counter). A habit can be **paused with a reason** (travel, illness, cycle, other); paused days are empty cells, not misses, and the habit is hidden from Today.
- **Focus timer:** Begin starts a session; the chip is global chrome above the tab bar. Overrun counts up and says nothing (no red, no alarm). One timer at a time — starting a second raises the settle sheet for the running one. Finish shows actual against estimate, an optional note line and a 5-second undo toast. A session running at the day rollover closes and tomorrow opens with one row offering to pick it back up.
- **Notes:** one markdown note per task (checklists, bold, italic, links, inline code), shown as a tappable checklist under the timer. **No** list-row preview, **no** habit notes.
- **Repeating tasks:** daily / weekly on days / monthly; needs a date; one live instance per series; Drop skips only this occurrence, Stop repeating ends the series.
- **Day rollover** is a user-set time (default midnight); the day **end** (default 19:00) is a soft planning boundary only.
- **Wellbeing** is derived only from behaviour — **no self-reporting anywhere (no mood)**. Score 0–100 over 14 days from tasks (35%), Anchors attended (25%), habits (20%) and load (20%); "gathering data" until 7 active days. Trend is words (*steadier / about the same / heavier*), never a coloured number. When a pattern shows, **one inline card** offers one change with **Not now** (for example *"The last three days were heavy. Lighten Saturday?"*); never a notification.
- **Categories** are labels only: five label colours (teal, blue, ochre, plum, slate), a label is always a **dot plus the name**, at most eight active, archived ones restorable. The Today filter narrows **Tasks only**; Anchors, habits and the meter stay whole-day.
- **Notifications denied** is three states (not asked, denied, turned off later). Settings lists what isn't being delivered; where a reminder is configured one quiet line says notifications are off; the Today banner appears only if this device's switch is on and permission off, once a day, dismissible, *Don't remind me*. The always-available **Plan tomorrow** row is separate.
- **Problems** are quiet and never alarming: iCloud states (not signed in, restricted, storage full, sync trouble; offline is never one) say *your data is safe on this device* and what would fix it; an iCloud account change offers **Export my data** first; a store that won't open shows a recovery screen (*Try again* / *Reset this device's data*); a newer-version value reads *Update Jamaal to see this*.
- **Night Planning entry:** a **Plan tomorrow** action in Today's toolbar, a quiet row after the planning time, and the evening notification or banner. The morning card opens a shortened flow (Build → Load → Close). Tomorrow's habits are shown read-only; tasks are pulled in and pushed out, never reordered; gaps under 20 minutes aren't shown.
- **Trial:** 14 logical days, app-managed, no payment up front. After that the app is **read-only** with a calm paywall shown once on the first open of each day. *Living the day* still works (tick tasks, log habits, mark Anchors, run a timer); *shaping the plan* is locked (creating or editing anything, manual Defer and Drop, Night Planning, capacity). **Locked controls stay visible**; tapping one opens a calm sheet (*"Adding and planning need a subscription"* — Subscribe / Not now). Export and delete always work.

> The stable IDs and the full list (with entry points, states and what is already drawn) are in the repo's **Screens and flows register** (`docs/journeys/screens.md`); name Design frames with those IDs (`TD-01`, `NP-03`, …). The tables below are the same list in summary.

## 7. Screen inventory

**Status:** *keep* = works as drawn · *rework* = change it · *new* = not drawn yet. Numbers refer to v3.

### Today
| Screen | Status | Notes |
|---|---|---|
| 01 Today | rework | Add the Anchors section (plain rows, grouped rows, window bars, three actions), category labels, the capacity slider **and** meter, timed / avoid habit rows, and the session chip host |
| 02 Guidance | keep | Add **Begin** on the "Start here" card |
| 03 Blank / 04 All done | align | Design's own copy differs between v3 and its tokens page — settle inside Design (§3); no functional change |
| X-01 Overloaded | new | "More than four things": the meter, the named overflow, one-tap move |
| X-02 Carried-over arrival | new | The single "pick it back up" row after an auto-closed session |
| Morning card | new | "No plan for today — two minutes to pick?" once |
| Banners | new | Notifications off (24, keep and align), trial ending, read-only — one at a time, most pressing first |
| Category filter (`TD-03`) | new | Header control: *All* + categories; a clear chip; empty result *"Nothing in Family today."* + *Show all* |
| Plan tomorrow | new | Toolbar action and a quiet row after the planning time |
| Add (Task / One-off Anchor) | new | The Add button offers a choice |

### Tasks and the timer
| Screen | Status | Notes |
|---|---|---|
| 10 Add task | rework | Opens on Task with a **Task \| Anchor** switch (no chooser screen); effort chips 15m / 30m / 1h / 2h+ with an **Other…** stepper and **30m preselected**; importance low / medium / high (low default), category, schedule incl. repeat; medium/high reveals the required date and hides Someday |
| 11 Task detail | rework | Note checklist, category, deferral history, **Begin**, Mark done, Defer, Drop, Stop repeating |
| 12 Defer (3rd slip) | rework | Reason chips; the easing message for medium/high |
| A-04 Day is full | new | "Offer tomorrow" — never blocks |
| T-01 Session chip on Today | new | Above the tab bar, global |
| T-02 Focus screen | new | Timer, note checklist, Pause, Finish |
| T-03 Overrun | new | "75 of 60", neutral |
| T-04 Paused | new | Explicit pause only |
| T-05 / T-06 Finish sheet + undo | new | Actual vs estimate, note line, **Done** and **Stop for now**, 5 s toast |
| T-08 Switch task | new | Settle sheet for the running task: Done · Stop for now · Defer · Drop |
| T-07 Lock Screen activity | **v1.1 — draw last** | Live Activity and Dynamic Island |

### Habits and Anchors
| Screen | Status | Notes |
|---|---|---|
| 13 Habits overview | rework | Groups stay; add timed / avoid / paused states |
| 14 / 15 Habit detail | rework | Density grid + plain-language read; **no streak numbers** |
| H-04 Type picker | new | Four kinds with plain descriptions |
| 16 Add habit, 17 Recurrence, 18 New group | keep / rework | Add kind; group stays visual |
| H-05 Timed habit | new | Target minutes; uses the chip |
| H-06 Avoid habit | new — **needs exploration** | See §9; draw two options |
| H-07 Pause with reason | new | Travel, illness, cycle, other; open-ended allowed |
| H-09 Edit / archive | new | History is never deleted |
| 19 No habits | rework | Fixed empty line |
| **Anchors segment** in the Habits tab | new | The rules list |
| **Add / edit Anchor rule** | new | Two forms: prayer times (location, method, madhab, prayers, Isha end; advanced adjustments) and the shared scheduled form (recurrence, named time slots, duration, placement); an **exceptions** editor (term break, holiday, travel, illness, open-ended); a "needs attention" state |
| **Add one-off Anchor** | new | Title, date, window, optional duration |

### Night Planning (five steps)
| Step | Status | Notes |
|---|---|---|
| 1 Review today | rework | Plain counts, time spent vs estimate; no mood line (nothing is self-reported) |
| 2 Carry forward | rework | Keep / Later / Drop per task; 3rd-slip behaviour |
| 3 Build tomorrow | rework | **Opens on tomorrow's working day**: fixed commitments drawn in and free gaps **named** ("before the school run · 2h 40m free"); list on phone, proportional timeline on wide; then a plain task list (not placed into gaps), flags for tasks longer than the longest gap, **Add one-off Anchor** |
| 4 Check the load | rework | Level slider pre-selected to the weekday default, budget used, overflow past the day's end, one specific suggested move |
| 5 Close the day | rework | "Tomorrow is ready…", a plain count of nights planned (no streak), Good night |
| **Skip tonight** | new | Available on every step |
| Wide layout | rework | Five stops on one canvas with a step rail |

### Wellbeing, Settings, Onboarding
| Screen | Status | Notes |
|---|---|---|
| 20 / 21 Wellbeing | keep | Score derived from behaviour only (tasks, Anchors, habits, load); trend in words; the strained state carries one pattern card with **Not now**; the "why" view is v1.1 |
| 22 Gathering data | keep | |
| 23 Settings | rework | Normal-day length + occasional quiet suggestion ("You usually do about 2h 40m — set your normal day to that?"), default level per weekday, working-day start / end, rollover (Advanced), categories management, trial status |
| **Category management** (`ST-04`) | new | Editable, reorderable list; five label colours; at most eight; collapsed **Archived** with Restore |
| **Subscription** (`ST-05`), **iCloud status** (`ST-06`), **Privacy and export** (`ST-08`) | new | Days left or status, manage, restore · signed in / problem · privacy statement, Export my data, Delete my data (two confirmations) |
| **Problem states** (`SY-05`) | new | iCloud line, account-changed notice with Export first, store-recovery screen |
| 25–29 Onboarding | rework | Meet Jamaal → the idea → (iCloud check, silent) → **your normal day + when the working day ends + the capacity slider** → reminders with the evening time → **first Task, first Habit, first Anchor** (the Anchor step is skippable: "Not now") → ready |
| **Paywall** | new | Calm, full-screen, monthly and yearly, restore, "Not now"; plus the locked-control sheet (*Adding and planning need a subscription*) |

## 8. Adaptive layouts

- **iPhone** (compact): the system tab bar; sheets; Night Planning as a full-screen modal.
- **iPad** (regular): **superseded by Design v4**: a sidebar, then a list (440 pt), then a detail panel (see `docs/design/README.md` §8). **No modals on wide**: sheets become panels and the list stays lit. Night Planning becomes a one-canvas step rail. A keyboard adds shortcuts, never chrome.
- **iPhone Duo:** folded is the phone build unchanged. Unfolded is the regular layout, with Today pinned left at its phone measure and the right panel holding what a push or sheet would show. Toolbars and the tab bar move to the side on the outer display and in inner landscape (use system components). Keep every element clear of the fold — sheets, alerts and menus move for it automatically; custom components must avoid it. Prefer an **even number of columns** in grids.
- The **session chip lives in the right panel** on wide layouts. Wide layouts add no components, only the 340 pt list beside a detail panel.
- **macOS** later: reuse the regular-width layout with a sidebar and menu-bar commands.
- Draw the phone set first; iPad and Duo inherit it.

## 9. Open decisions — draw provisionally and mark clearly

- **Category label colours** — decided as five (`accent` teal, `blue`, `ochre`, `plum`, `slate`; defaults Personal teal, Family ochre, Work blue), but the **hues are for Design to propose**: pick them from the palette family so they clear 4.5:1 and never resemble terracotta (terracotta means warning and overload). They become new ThreadsKit tokens.
- **Avoid habits (H-06).** Semantics are decided (log a slip; a day is complete only if slips are within the allowance **and** the user engaged that day; no days-since-slip counter). Draw two treatments for the owner to choose between.
- **Wellbeing "why" view (X-04 / WB-04)** is v1.1; draw the score, trend words, sparkline and the pattern card only.
- **Natural-language capture (A-02, A-03, A-05).** Not adopted; leave out.
- **Decided since the first brief** (draw them): Jumu'ah is a *Friday label* option on the prayer rule; Anchor reminders exist (prayer times remind at the start by default, everything else off, a closing reminder is opt-in); a **missed** Anchor offers *Mark as done after all* until the end of that day.
- **Fonts** are not bundled in ThreadsKit yet; design with Fraunces, Hanken Grotesk and JetBrains Mono.

## 9a. Screens to draw, in batches

Attach to the Design project: this brief, `docs/journeys/screens.md` (the register — name frames by its IDs) and the per-screen specs in `docs/journeys/walkthroughs/` (`01`–`11`). The register's status column says what is **None** (not drawn), **Spec** (specified, not drawn) or **Drawn** (rework if the brief says so). 30 screens are None and 17 are Spec. Draw in this order; each batch is reviewable on its own:

1. **Today and capture** — `TD-01` and its states (empty, all done, overloaded, carried-over `TD-06`, morning card `TD-07`, banners `TD-05`: notifications off · trial ending · read-only), category filter `TD-03`, Add `TD-04`, `TK-01`, `TK-02`, note editor `TK-04`, repeat picker `TK-05`, category picker `TK-06`.
2. **The timer** — `FS-01` chip, `FS-02` focus screen, `FS-03` overrun, `FS-04` paused, `FS-05` finish sheet, `FS-06` done + undo, `FS-07` switch-task sheet, `SY-03` undo toast. (`FS-08` Live Activity is v1.1: last.)
3. **Habits and Anchors** — `HB-06` pause, `HB-07` edit/archive, `HB-08` avoid (two options), `HB-09` minutes by hand; `AN-01` rules list, `AN-02` rule detail, `AN-03` type, `AN-04` prayer form with `AN-11` location, `AN-05` scheduled form, `AN-06` exceptions, `AN-07` needs attention, `AN-08` one-off, `AN-09` rows on Today, `AN-10` actions; Archived sections with Restore.
4. **Night Planning** — `NP-01` … `NP-05`, `NP-06` skip, and the shortened morning flow; wide canvas `NP-07`.
5. **Wellbeing, Settings, Onboarding, Subscription, System** — `WB-01` … `WB-03` (and the pattern card); `ST-01` … `ST-08` (Capacity & day, Notifications & times with its warning card, Categories, Subscription, iCloud status, Appearance, privacy and export); `OB-03`, `OB-06`, `OB-07`, `OB-08`; `SB-01` paywall, `SB-02` reminder copy, `SB-03` read-only banner and the locked-control sheet; `SY-01` banner, `SY-02` empty lines, `SY-05` problem states (incl. account-changed notice and store-recovery screen), `SY-06` icon and launch.
6. **Wide layouts** — iPad two-panel and Duo inner display for the screens above, then the macOS sidebar.

## 9b. Paste-ready prompt

> Redraw Jamaal's screens using the attached brief, register and walkthroughs. Styling comes from this project (v3 screens, tokens page, flow spec) unless the brief says a locked behaviour conflicts. Work in the six batches of §9a, phone first, and **stop after each batch** for review. Name every frame with its register ID (`TD-01`, `NP-03`…). Mark anything provisional (category hues, the avoid-habit options) clearly. Follow the acceptance checklist in §10: no streaks, no mood or self-reporting, no red severity, no praise, scolding or exclamation marks, terracotta as the only filled button, and every locked or problem state calm and quiet.

## 10. Acceptance checklist

**Functional — must hold:**

- [ ] No streak, "best" or counter anywhere; habits show a density grid and a plain-language read only.
- [ ] Night Planning has five steps plus *Skip tonight*; carry-forward keeps Keep / Later / Drop on every layout.
- [ ] Medium / high importance always shows a required date and never offers Someday.
- [ ] An Anchor can be marked attended only while its window is open; skipped and delegated are not misses.
- [ ] Capacity has the low / medium / high control and the meter shows budget used; nothing ever blocks.
- [ ] Navigation uses the system tab bar and toolbars; nothing is hand-built that would fail to adapt on iPad or Duo.
- [ ] The copy respects how the app works (iCloud sync, categories as labels, opt-in reminders), and never praises, scolds or uses an exclamation mark.
- [ ] Every tappable element has a 44 pt target; layouts use leading / trailing and safe areas only; nothing sits in the Duo fold; right-to-left mirrors, with the density grid filling from the trailing edge.

**Styling — per Design** (check against Design's own rules, and resolve its inconsistencies in §3):

- [ ] Terracotta is the only filled button colour, at most one filled button per surface; destructive actions are a soft fill with alert text.
- [ ] No red severity; every empty and finished state follows Design's pattern.
- [ ] Every text pair clears 4.5:1 in light and dark (`ink3` is the floor); `onAccent` sits on every filled accent; no hardcoded white.
- [ ] A press changes fill only, never position; density cells contain no numerals.
