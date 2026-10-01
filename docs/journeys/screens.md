# Screens and flows register

> **Status: lock candidate — needs the owner's sign-off.** One list of every screen, state and flow in v1, with stable IDs. It is what Claude Design redraws from and what code is built against; nothing gets built or drawn that isn't here. Behaviour lives in the journey and schema docs; this page is the *map*. Section 7 lists the few decisions still needed before it can be called locked.

## 1. How to read this

**IDs** are stable: `TD` Today · `TK` tasks · `FS` focus sessions · `HB` habits · `AN` Anchors · `NP` Night Planning · `WB` Wellbeing · `ST` Settings · `OB` Onboarding · `SB` subscription · `SY` system and cross-cutting. Use them as the names of Design frames and as the names of the Swift views' screens.

**Design status** — what Claude Design has today:

| Mark | Meaning |
| ---- | ------- |
| **Drawn** | Drawn in *Jamaal Screens v3*; the number is given (`v3·10` = screen 10). May need rework per the brief. |
| **Spec** | Specified in *Jamaal Flows 01* (IDs like `T-02`) but not drawn. |
| **None** | Not in Design at all. |

**Phase:** *v1* ships at launch · *v1.1* later. **Variants:** every screen has a *compact* layout (iPhone; also the iPhone Duo outer display) and a *regular* layout (iPad, Mac, Duo inner display) unless noted; see [App flow → Adaptive layout](app-flow#adaptive-layout-ipad-and-mac). On regular width sheets become panels beside the list.

Sources of behaviour: [Today](today-list) · [Night Planning](night-planning) · [Onboarding](onboarding) · [App flow](app-flow) · [Schema](../schema/overview) · [Rules engine](../architecture/rules-engine) · [Claude Design brief](../design/claude-design-brief).

**Testing the register against the schema:** each flow is walked screen by screen in the [journey walkthroughs](walkthroughs/overview), which raise gaps in a running log before any code depends on them.

## 2. App map

```
Onboarding (once) ─────────────────────────────────────────────► tabs
                                                                   │
  ┌─────────────┬──────────────────────┬──────────────┬────────────┘
  ▼             ▼                      ▼              ▼
Today         Habits                 Wellbeing      Settings
 │            ├─ Habits segment       └─ score,      ├─ Capacity & day
 │            │   └─ habit detail        sparkline   ├─ Notifications & times
 │            └─ Anchors segment                     ├─ Categories
 │                └─ rule list → add/edit rule       ├─ Subscription
 │                                                   └─ iCloud · appearance · about
 ├─ task detail  (sheet / panel)
 ├─ Add → Task · One-off Anchor  (sheet)
 ├─ Night Planning  (full-screen modal; wide: one canvas)
 └─ focus chip → focus screen           (global: present on every tab)

Global overlays: undo toast · settle sheet · paywall · banners
```

Tab bar is **Today · Habits · Wellbeing · Settings**, the system Liquid Glass bar (sidebar on regular width). The **session chip** is chrome above it on every tab.

## 3. Flows

Each flow lists its trigger, the screens it passes through, its branches and its end states.

**F01 First launch.** Trigger: first open. `OB-01 → OB-02 → (OB-03 if iCloud has a problem) → OB-04 → OB-05 → OB-06 → OB-07 → OB-08 (skippable) → OB-09 → TD-01` with the "Tonight, we'll plan tomorrow" card. Denying notifications in OB-05 is fine: `SY-01`'s banner takes over.

**F02 The daily loop.** Morning: optional morning nudge → `TD-01` showing the confirmed plan (or the morning card `TD-07` if no plan). Day: F03–F06. Evening: the planning notification (or banner) → F09. Rollover (default midnight) is invisible except `TD-06` when a session was auto-closed.

**F03 Capture a task.** `TD-01 → Add sheet (Task | Anchor switch) = TK-01`. Branches: medium/high importance → date row required, Someday hidden · repeat chosen → date required · day already full → "Day is full · offer tomorrow" (`TK-01` state, never blocks) · no importance and no date → backlog task. End: row appears in `TD-01`.

**F04 Complete, defer or drop a task.** Tap the check → done (quiet completion feedback). Tap the row → `TK-02` → Mark done / Begin / Defer / Drop / Stop repeating. Defer: 1st and 2nd are instant to tomorrow; from the 3rd `TK-03` (reason chips; a medium/high task is eased to low first, which un-hides Someday). Drop: soft delete with undo toast `SY-03`. Note: a one-line timestamped note can be appended on finish and defer.

**F05 Run a focus session.** `TK-02` or the "Start here" card → Begin → chip `FS-01` appears on every tab. Tap chip → `FS-02` (timer, note checklist, Pause, Finish). Branches: Pause → `FS-04`; estimate passed → `FS-03` (neutral); Finish → `FS-05` (actual vs estimate, optional note) → task done → `SY-03` undo for 5 s; a second Begin while running → `FS-07` settle sheet (Done / Defer / Drop the running one); abandon → partial time kept; rollover reached → session closes at the boundary and `TD-06` offers to pick it back up. A timed habit uses the same screens (`HB` Begin).

**F06 An Anchor's day.** `TD-01` shows Anchors (plain rows, grouped rows, window bar). Tap Attended only while the window is open; Not today and Someone else did it until it closes; a closed window becomes missed. Tap a grouped row to expand it.

**F07 Create and manage Anchors.** Habits tab → Anchors segment `AN-01` → Add → `AN-03` (choose type) → `AN-04` (prayer times: location prompt → `AN-11`) or `AN-05` (shared scheduled form) → optional `AN-06` exceptions. One-offs: the Anchor side of the Add sheet (`TD-04`) or `NP-03` → `AN-08`. Edit from `AN-02`; delete archives. An undecodable rule shows `AN-07`.

**F08 Habit lifecycle.** Habits tab → Add → `HB-03` (type picker first) → kind-specific form → optional `HB-04` (custom recurrence) and `HB-05` (group). Logging: check, stepper, **Begin** (timed), **Log a slip** / **Held today** (avoid). Pause → `HB-06`; edit or archive → `HB-07`. Detail `HB-02` shows the density grid and the plain-language read.

**F09 Night Planning.** Trigger: evening notification, banner, or the **Plan tomorrow** action on Today. `NP-01 Review → NP-02 Carry forward → NP-03 Build tomorrow → NP-04 Check the load → NP-05 Close the day`. **Skip tonight** at any step (`NP-06`). If no plan was confirmed, the next morning shows `TD-07`, which opens the shortened flow for today (Build → Load → Close). A night that already has a session is resumed, not restarted. On wide layouts the five steps are one canvas (`NP-07`).

**F10 Capacity and day settings.** Slider on `TD-01` (level for today) · `ST-02` (normal-day length, weekday defaults, working-day start and end, rollover under Advanced) · the quiet normal-day suggestion line (Settings, and at most once in `NP-04`).

**F11 Wellbeing.** Wellbeing tab → `WB-01 / WB-02 / WB-03`; a suggested action (for example "Lighten Saturday") applies to the plan. The sparkline on `TD-01` links here.

**F12 Trial, paywall, read-only.** Days 1–14 nothing changes (`ST-05` shows days left). Quiet reminders around days 12–15. Day 15 → `SB-01` paywall (monthly, yearly, restore, Not now). Not subscribed → read-only (`SB-03` banner): viewing and *living the day* work (ticking off, logging, Anchor outcomes, timers); shaping the plan (creating, editing, Night Planning, capacity) is locked, with a calm sheet when a locked control is tapped. The paywall shows once on the first open of each logical day. Subscribe → everything returns.

**F13 Notifications denied.** Permission is *not asked* (OB-05 skipped), *denied*, or *turned off later* — re-checked on every foreground. `ST-03`'s warning card lists what isn't being delivered (planning prompt, Anchor, habit and morning reminders) with a button (*Turn on reminders* or a link to system Settings); where a reminder is configured, one quiet line says notifications are off. `SY-01`'s Today banner appears only when this device's switch is on and permission is off, once per logical day, dismissible, with *Don't remind me*; it is separate from the always-available **Plan tomorrow** row. Tapping a notification opens Night Planning (planning), Today at that row (Anchor, habit) or `ST-05` (trial).

**F14 Categories.** `ST-04` (list, rename, reorder, add, archive and restore, one of five label colours; at most eight active); the picker inside `TK-01` / `TK-02`; optional Today filter (Tasks only; the meter stays whole-day; local, clears at rollover).

**F15 Problems.** iCloud issue → `OB-03` (onboarding) or `SY-05` (later); an Anchor rule that can't be decoded → `AN-07`; two devices that both started a session → the later one is closed as abandoned and one quiet line says so on next open; a local store that won't open → a recovery screen (*Try again* / *Reset this device's data*); an iCloud account change → a notice with *Export my data* first; a value from a newer version → kept and shown as *Update Jamaal to see this*.

## 4. Screen register

Columns: **ID · screen · entry · content and states · design · phase**. *Design* reads **Drawn v4** where `mockups/screens/` has frames (named by these IDs; index in [mockups/screens/README](../../mockups/screens/README)); a few screens were not redrawn in v4 and keep their earlier status — see [Design v4 reconciliation](../design/v4-reconciliation). "C/R" = compact and regular layouts both required.

### Today (`TD`)

| ID | Screen | Entry | Content and states | Design | Phase |
|---|---|---|---|---|---|
| TD-01 | **Today** (C/R; Duo inner = list + panel) | Tab 1, launch | Capacity slider and meter; companion card slot; **Anchors** (plain rows, grouped rows "Salah 3/5", window bars, three actions); **Habits** (binary, counted stepper, timed "12 of 20 min", avoid, paused hidden); **Tasks** (category label, effort; importance not shown); **Also today** (collapsed, count); **Plan tomorrow** (toolbar action, and a quiet row after the planning time); Add; chip host. States: default · guidance ("Start here" / "Good now") · first launch · all done · overloaded · past the day's end | **Drawn v4** · 5 frames | v1 |
| TD-02 | Wellbeing strip | On TD-01 | Sparkline; "gathering data" until seven active days | **Drawn** (in v3·01) · not redrawn in v4 | v1 |
| TD-03 | Category filter | TD-01 header | Narrows **Tasks only** to one category (Anchors and habits always shown; meter, load and *Also today* whole-day); *Start here* from visible tasks; local, clears at rollover and relaunch; empty result *"Nothing in Family today."* + *Show all*; never creates sections | **Drawn v4** · 2 frames | v1 |
| TD-04 | Add sheet entry: **Task \| Anchor** switch | TD-01 Add | The add sheet opens on Task; the switch at the top reaches the one-off Anchor form (`AN-08`). No separate chooser screen | **None** · not redrawn in v4 | v1 |
| TD-05 | Banners | TD-01 top | Notifications off · trial status · read-only | **Drawn v4** · 3 frames | v1 |
| TD-06 | Carried-over row | TD-01 | One row to pick a session's task back up after auto-close | **Drawn v4** · 1 frame | v1 |
| TD-07 | Morning card "No plan for today" | TD-01 | Shown once; opens the shortened flow for today (Build → Load → Close) | **Drawn v4** · 1 frame | v1 |

### Tasks (`TK`)

| ID | Screen | Entry | Content and states | Design | Phase |
|---|---|---|---|---|---|
| TK-01 | **Add task** (sheet / panel) | TD-04 | Title; effort (15m/30m/1h/2h+ shortcuts, Other… stepper, 30 preselected); importance (low default); category; schedule; repeat; note. States: medium/high (date required, Someday hidden) · repeat · "Day is full · offer tomorrow" | **Drawn v4** · 3 frames | v1 |
| TK-02 | **Task detail** (sheet / panel) | Row tap | Title, note checklist, category, effort, importance, due, deferral history; Begin · Mark done · Defer · Drop · Stop repeating. States: normal · deferred · repeating · running · complete | **Drawn v4** · 2 frames | v1 |
| TK-03 | **Defer / Later** picker | Defer from TK-02 or NP-02 | Later this week · Next week · Someday (low only) · a date; reason chips from the 3rd; the easing message | **Drawn v4** · 1 frame | v1 |
| TK-04 | Note editor | TK-02 | Markdown subset (checklists, bold, italic, links, code); no headings, tables, images | **Drawn v4** · 1 frame | v1 |
| TK-05 | Repeat picker | TK-01 / TK-02 | Daily · weekly days · monthly | **Drawn v4** · 1 frame | v1 |
| TK-06 | Category picker | TK-01 / TK-02 | Pick or none; archived shown only as the current selection; a new task inherits an active filter's category | **Drawn v4** · 1 frame | v1 |

### Focus sessions (`FS`)

| ID | Screen | Entry | Content and states | Design | Phase |
|---|---|---|---|---|---|
| FS-01 | **Session chip** (global chrome, C/R) | Begin | Title + count-up; filled only while live; "Maghrib in 12 min" near a fixed Anchor | **Drawn v4** · 3 frames | v1 |
| FS-02 | **Focus screen** | Chip | Timer numeral (monospaced digits), note checklist, Pause, Finish | **Drawn v4** · 2 frames | v1 |
| FS-03 | Overrun | FS-02 | Same as running; "75 of 60", no red, no alarm | **Drawn v4** · 1 frame | v1 |
| FS-04 | Paused | FS-02 | Explicit pause only | **Drawn v4** · 1 frame | v1 |
| FS-05 | **Finish sheet** | Finish | Actual vs estimate; optional note line; **Done** or **Stop for now** | **Drawn v4** · 1 frame | v1 |
| FS-06 | Done + undo toast | FS-05 | 5-second undo | **Drawn v4** · 1 frame | v1 |
| FS-07 | **Switch-task settle sheet** | Begin while running | Done · Stop for now · Defer to tomorrow · Drop the running task (habit: Log it · Stop for now) | **Drawn v4** · 2 frames | v1 |
| FS-08 | Lock Screen activity / Dynamic Island | System | Live Activity | **Drawn v4** · 8 frames | **v1.1** |

### Habits (`HB`)

| ID | Screen | Entry | Content and states | Design | Phase |
|---|---|---|---|---|---|
| HB-01 | **Habits overview** (C/R) | Tab 2, Habits segment | Groups (collapsed/expanded), habits, paused, empty; a collapsed **Archived** section with Restore | **Drawn v4** · 1 frame | v1 |
| HB-02 | **Habit detail** | HB-01 | Density grid (one per time of day) + plain-language read; **no streak numbers**; the last 14 days tappable to correct; per kind: binary · counted · timed · avoid; weekly-target (weeks, never *missed*); paused; healthy / slipping | **Drawn v4** · 2 frames | v1 |
| HB-03 | **Add / edit habit** | HB-01 | **Type picker** first (binary / counted / timed / avoid; the kind is fixed after creation), then a kind form: counted target, timed minutes, avoid allowance; schedule; **Times of day** (up to four, each with optional start, end and reminder); group | **Drawn v4** · 1 frame | v1 |
| HB-04 | Custom recurrence | HB-03 | Day picker, times a week | **Drawn** v3·17 · not redrawn in v4 | v1 |
| HB-05 | Group create / assign | HB-03 / HB-01 | Visual bundle: name, members, collapsed preview (no emoji) | **Drawn** v3·18 · not redrawn in v4 | v1 |
| HB-06 | **Pause with reason** | HB-02 | Travel · illness · cycle · other; open-ended allowed | **Drawn v4** · 1 frame | v1 |
| HB-07 | Edit / archive | HB-02 | History is never deleted | **Drawn v4** · 1 frame | v1 |
| HB-08 | Avoid logging | TD-01 / HB-02 | **Log a slip**, **Held today**, allowance — *needs a design pass* | **Drawn v4** · 1 frame | v1 |
| HB-09 | Add minutes by hand | TD-01 / HB-02 | Timed habits only; stored as a `manual` session | **Drawn v4** · 1 frame | v1 |

### Anchors (`AN`)

| ID | Screen | Entry | Content and states | Design | Phase |
|---|---|---|---|---|---|
| AN-01 | **Anchor rules list** | Habits tab → Anchors segment | Rules with next instance; enabled; "needs attention"; a collapsed **Archived** section with Restore | **Drawn v4** · 1 frame | v1 |
| AN-02 | Rule detail | AN-01 | Schedule summary, exceptions, upcoming instances; edit · pause · archive | **Drawn v4** · 1 frame | v1 |
| AN-03 | **Add rule — type** | AN-01 | Prayer times · School run · Bin night · Plant watering · Custom | **Drawn v4** · 1 frame | v1 |
| AN-04 | **Prayer form** | AN-03 | Location, method, madhab, prayers, Isha end; advanced: adjustments, high-latitude rule | **Drawn v4** · 1 frame | v1 |
| AN-05 | **Scheduled form** | AN-03 | Recurrence (weekly · every N days · every N weeks · N–M days after last done), named slots, duration, placement | **Drawn v4** · 2 frames | v1 |
| AN-06 | Exceptions editor | AN-02 / AN-05 | Term · holiday · travel · illness · other; open-ended | **Drawn v4** · 1 frame | v1 |
| AN-07 | "Needs attention" state | AN-01 / AN-02 | Undecodable or newer-version rule; never deleted | **Drawn v4** · 1 frame | v1 |
| AN-08 | **Add one-off Anchor** | TD-04 / NP-03 | Title, date, window, optional duration | **Drawn v4** · 1 frame | v1 |
| AN-09 | Anchor rows on Today | TD-01 | Plain · grouped (collapsed/expanded) · window bar · multi-day (plants) | **Drawn v4** · 1 frame | v1 |
| AN-10 | Anchor actions | TD-01 row | Attended (only while open) · Not today · Someone else did it | **Drawn v4** · 2 frames | v1 |
| AN-11 | Location permission and city search | AN-04 | When-in-use prompt, in context; city search fallback | **Drawn v4** · 2 frames | v1 |

### Night Planning (`NP`)

| ID | Screen | Entry | Content and states | Design | Phase |
|---|---|---|---|---|---|
| NP-01 | **Review today** | Evening entry | Plain counts, time spent vs estimate | **Drawn v4** · 1 frame | v1 |
| NP-02 | **Carry forward** | NP-01 | Keep · Later · Drop per task; 3rd-deferral behaviour; skipped if nothing incomplete | **Drawn v4** · 1 frame | v1 |
| NP-03 | **Build tomorrow** | NP-02 | Opens on tomorrow's working day: fixed commitments and named free gaps (list on compact, proportional timeline on regular); task and habit list; importance and date; flag for tasks that won't fit a gap; Add one-off Anchor | **Drawn v4** · 1 frame | v1 |
| NP-04 | **Check the load** | NP-03 | Level (weekday default pre-selected), suggested level, budget used, overflow past the day's end, one move | **Drawn v4** · 1 frame | v1 |
| NP-05 | **Close the day** | NP-04 | "Tomorrow is ready…"; nights-planned count; Good night | **Drawn v4** · 1 frame | v1 |
| NP-06 | Skip tonight | Any step | Closes with no plan | **Drawn v4** · 1 frame | v1 |
| NP-07 | Wide canvas (step rail) | Regular width | Five stops on one canvas | **Drawn v4** · 2 frames | v1 |

### Wellbeing (`WB`)

| ID | Screen | Entry | Content and states | Design | Phase |
|---|---|---|---|---|---|
| WB-01 | Wellbeing — steady | Tab 3 | Score, trend, plain read, completion, heavy days | **Drawn v4** · 1 frame | v1 |
| WB-02 | Wellbeing — strained | Tab 3 | As above, with a suggested action ("Lighten Saturday" / Not now) | **Drawn v4** · 1 frame | v1 |
| WB-03 | Gathering data | Tab 3 | Seven-day progress | **Drawn v4** · 1 frame | v1 |
| WB-04 | "What makes this score" view | WB-01 | Derivation of the score | **Spec** X-04 · not redrawn in v4 | *to decide* |

### Settings (`ST`)

| ID | Screen | Entry | Content and states | Design | Phase |
|---|---|---|---|---|---|
| ST-01 | Settings home | Tab 4 | Sections below; trial status row | **Drawn v4** · 1 frame | v1 |
| ST-02 | **Capacity & day** | ST-01 | Normal-day length (+ quiet suggestion), default level per weekday, working-day start/end, rollover (Advanced; changeable only after both old and new times have passed today), note when planning time precedes day end | **Drawn v4** · 1 frame | v1 |
| ST-03 | **Notifications & times** | ST-01 | Evening planning time and morning list (synced); **Send reminders on this device** switch (local; on for iPhone, off for iPad and Mac); habit reminders; warning card if denied | **Drawn v4** · 1 frame | v1 |
| ST-04 | **Categories** | ST-01 | List, rename, add, archive (with a collapsed **Archived** section and Restore), colour from a fixed set | **Drawn v4** · 1 frame | v1 |
| ST-05 | **Subscription** | ST-01 | Days left or status, manage, restore | **Drawn v4** · 1 frame | v1 |
| ST-06 | iCloud status | ST-01 | Signed in · Not signed in · Restricted · Storage full · Sync trouble (three failures over a day); offline is never a problem | **Drawn v4** · 1 frame | v1 |
| ST-07 | Appearance | ST-01 | Theme, larger text | **Drawn v4** · 1 frame | v1 |
| ST-08 | About, privacy, data export | ST-01 | Privacy statement, Export my data (JSON), Delete my data (two confirmations; local and iCloud) | **Drawn v4** · 1 frame | v1 |

### Onboarding (`OB`)

| ID | Screen | Content | Design | Phase |
|---|---|---|---|---|
| OB-01 | Meet Jamaal | Companion intro | **Drawn** v3·25 · not redrawn in v4 | v1 |
| OB-02 | The idea | One list, three ways of tracking; not projects or tags | **Drawn v4** · 1 frame | v1 |
| OB-03 | iCloud check | Waits briefly for sync; silent when fine; problem state; **Welcome back** for a second device (skips onboarding) | **Drawn v4** · 1 frame | v1 |
| OB-04 | **Your normal day** | Normal-day length, working-day end, capacity slider | **Drawn v4** · 1 frame | v1 |
| OB-05 | **Reminders & evening time** | Evening time, morning list, permission request | **Drawn v4** · 1 frame | v1 |
| OB-06 | First task | Category intro | **Drawn v4** · 1 frame | v1 |
| OB-07 | First habit | Presets or custom | **Drawn v4** · 1 frame | v1 |
| OB-08 | First Anchor | Type choice, forms, **Not now** | **Drawn v4** · 1 frame | v1 |
| OB-09 | Ready | "Tonight, we'll plan tomorrow"; trial line | **Drawn v4** · 1 frame | v1 |

### Subscription and system (`SB`, `SY`)

| ID | Screen | Content | Design | Phase |
|---|---|---|---|---|
| SB-01 | **Paywall** | Calm full-screen; monthly, yearly, restore, Not now Frames show placeholder prices; the app shows StoreKit's `Product.displayPrice` (prices stay $2.99/month, $24.99/year). | **Drawn v4** · 1 frame | v1 |
| SB-02 | Trial reminders | Notification copy only (days 12, 14, 15) | **Drawn v4** · 1 frame | v1 |
| SB-03 | Read-only banner | Explains what is locked; offers to subscribe | **Drawn v4** · 1 frame | v1 |
| SY-01 | Notifications-denied fallbacks | Today banner (switch on, permission off; once a day; *Don't remind me*); Settings warning card listing what isn't delivered | **Drawn** v3·24 · not redrawn in v4 | v1 |
| SY-02 | Empty and finished states | Four fixed lines (today, first launch, habits, history) | **Drawn v4** · 1 frame | v1 |
| SY-03 | Undo toast | Quiet, 5 seconds | **Drawn v4** · 1 frame | v1 |
| SY-04 | Sheets vs panels | Sheets on compact; panels beside the list on regular | **Drawn** v3·D2 · not redrawn in v4 | v1 |
| SY-05 | Problem states | iCloud problem line (dismissible; says the data is safe); account-changed notice; store-won't-open recovery screen; the quiet timer-clash line | **Drawn v4** · 3 frames | v1 |
| SY-06 | App icon and launch screen | Three icon directions exist in the earlier mockups | **Drawn v4** · 1 frame | v1 |

### Layout variants that need their own frames

Not extra screens, but frames Design must draw: **Today** (compact, iPad two-panel, Duo folded and unfolded), **Night Planning** (compact steps; wide one-canvas), **Task detail** (sheet; panel), **Habits** and **Anchors** (compact; content pane with detail). Design status: the iPad and Duo unfolded frames exist for Today and Night Planning (**Drawn** v3·D0–D4) but predate the session chip, the Anchors section and the load check.

## 5. Global states (every screen must handle)

| State | Effect |
| ----- | ------ |
| **First day** | Sparse history: Review is minimal; no wellbeing score; "gathering data" |
| **Nothing planned / all done** | Fixed single-line empty states; no illustration, no button |
| **Overloaded / past the day's end** | Meter turns terracotta; named overflow with a one-tap move; never blocks |
| **Session running** | Chip on every tab; "Maghrib in 12 min" near an Anchor; nothing blocks |
| **Paused habit** | Hidden from Today and Night Planning; shown as paused in Habits |
| **Read-only (trial ended)** | Living the day allowed (ticking off, logging, Anchor outcomes, timers); creating, editing, planning and capacity locked, behind a calm sheet; data export still works |
| **Notifications denied** | In-app banner at planning time; Settings warning card |
| **No iCloud / sync problem** | Surfaced only when there is a problem |
| **Large text / right-to-left** | Everything scales (labels cap at the `.xxLarge` accessibility size); layouts mirror; the density grid fills from the trailing edge |

## 6. Out of v1 (decided)

Natural-language capture (live parse chips, ambiguous date, "landed" — Design A-02, A-03, A-05) · manual ordering of Today (engine order only) · recovering a dropped task after the 5-second undo (no History screen) · Live Activity and Dynamic Island (`FS-08`, **v1.1**) · detected habits (the offer to promote a repeating task, **v1.1**) · sharing and referral (**v1.1**) · native Android (later) · Jumu'ah handling and Anchor reminder lead time (undecided, left out of the forms).

## 7. Decisions still needed before this can be locked

Each has a recommendation so the register can be locked in one pass.

| # | Question | Recommendation |
|---|----------|----------------|
| 1 | **History.** Design's empty-state line "Nothing logged yet." implies a History surface (what was done, sessions, attendance over time). No screen or tab exists for it. | **Not in v1.** Density grids, Night Planning's review and Wellbeing already show the past; revisit after launch. Drop the "history" empty line. |
| 2 | **Data export and privacy.** Read-only mode promises that export "always works", and the App Store needs a privacy route, but no screen or format is defined. | **v1:** one `ST-08` screen with a privacy statement, *Export my data* (JSON) and *Delete my data*; nothing more. |
| 3 | **Backlog view.** Undated low tasks form a backlog, shown only as a collapsed Today section. Is there a full list? | **No separate screen in v1**: the collapsed section on Today plus Night Planning's task picker are enough. |
| 4 | **Anchor instance detail.** Tapping an Anchor row: a detail screen, or inline actions only? | **Inline actions only** (`AN-10`); the rule's detail (`AN-02`) holds the rest. |
| 5 | **Widgets, share extension, App Intents.** Not designed. | **v1.1**; none in v1. |
| 6 | **Calendar events / Reminders import.** The app's goal is fewer apps, but nothing reads a calendar. | **Out of v1**; one-off Anchors cover fixed-time events. |
| 7 | **"What makes this score" (`WB-04`).** | **v1.1**; ship the score and plain read without a derivation view. |
| 8 | **Avoid habits (`HB-08`).** Design has only a title. | Design draws **two options** from the brief; the owner picks; the screen stays in v1 because it was chosen for v1. |
| 9 | **Category colours (`ST-04`).** | **Decided** (Journey 11): `accent`, `blue`, `ochre`, `plum`, `slate`; new ThreadsKit 1.2.0 tokens; hues to confirm against Design. |
| 10 | **Onboarding skippability.** | Notifications (`OB-05`) and the Anchor step (`OB-08`) skippable; everything else required. |
| 11 | **Mood** (`NP-01`). | **Removed** — no self-reporting anywhere; wellbeing derives from behaviour only. |
| 12 | **Search.** None designed. | **None in v1** — "one list, today only". |
