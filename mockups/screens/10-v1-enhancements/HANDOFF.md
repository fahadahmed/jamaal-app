# Jamaal v1 enhancements: design handoff

Source of truth: the "Jamaal v1 enhancements" design canvas (https://claude.ai/artifact/CHhiM9bEiPg4aJubXwcZoM). In this bundle, every frame named below appears twice: `frames/<name>.png` is a 2× render, and `source/<name>.dc.html` is the editable HTML, which opens in a browser with `support.js` beside it. Visual language, tokens and components are unchanged from the Jamaal v4 screens (ThreadsKit). This pass adds behaviour and a few new screens; it introduces **no new tokens or components**.

These enhancements answer three pieces of beta feedback:

1. There's no way to look back at a previous day.
2. Future-dated tasks are invisible until the night before.
3. It isn't clear how to edit a task.

---

## 1. Rules that apply everywhere

| Rule | Detail |
|---|---|
| Capacity counts planned days only | A future-dated task never counts toward any day's capacity until Night Planning (or the morning flow) pulls it into that day. Nothing in Coming up shows a capacity bar. |
| No edit mode | Task detail *is* the editor. Every field edits in place and autosaves. There is no Edit, Save or Cancel button anywhere. The `Saved` tick in the header confirms. |
| Undo instead of Cancel | Leaving a task you changed shows an undo toast for about 4 s. Undo reverts every change made during that visit. Mac also has ⌘Z (Edit › Undo), which outlives the toast. |
| One terracotta fill per surface | Terracotta (`--terra #9A4F2E`) is the only filled button on any surface. On a future task the primary is **Move to today**, which replaces **Begin**. |
| Selected row | Selection = white fill (`--glassOn`) + 1.5 px ink ring. Never terracotta. |
| Past days are read-only | Day review is read-only. A missed tick can be fixed for **two days**; older days are locked. |
| Repeating tasks ask once | The first change to a repeating task asks "Change just this one, or every one after?". |

---

## 2. Screen register

IDs follow the existing register (`TD-`, `TK-`, `SY-`). New IDs: `UP-01`, `DY-01`, `TK-02a/b/c`, `TK-07`.

### iPhone (393 × 852), also Duo folded

| ID | Frame file | What it shows |
|---|---|---|
| TD-01 | `Main.dc.html` | Today with two new rows under *Also today*: **Yesterday · 2 of 3 done ›** and **Coming up · 6 next 14 days ›**. |
| UP-01 | `Upcoming.dc.html` | Coming up: future-dated tasks grouped by day (Tomorrow, In 2 days, Next week), then a collapsed *Later · n*. One-off Anchors appear here too. Rows are dimmed (checkbox at 42 % opacity) because they aren't actionable yet. |
| DY-01 | `DayReview.dc.html` | Day review of a closed day: hero summary, capacity used, Anchors, Habits, Tasks. Arrows step between days. |
| TK-02 | `TaskEdit.dc.html` | Task detail sheet for a future task: title being edited, the field rows, a capacity sentence, then actions: **Move to today** (full width), then Mark done · Defer · Drop. |
| TK-02a | `EditEffort.dc.html` | Effort picker pushed inside the sheet: 15 min, 30 min, 45 min, 1 h, 90 min, 2 h. Tap saves and pops back. |
| TK-02b | `EditDue.dc.html` | Due picker pushed inside the sheet: quick dates (Today, Tomorrow, Thursday, Next week, No date), then a month grid. |
| TK-02c | `EditTitle.dc.html` | Title editing: sheet at full height above the system keyboard. Return/Done ends editing. |
| TK-07 | `RepeatScope.dc.html` | Second sheet over the task: *This and later Mondays* (terracotta) / *Only this Monday* / Cancel. |
| TD-07 | `MorningScheduled.dc.html` | Morning after a skipped night: "Wednesday, unplanned." card with **Pick for today** / **Not now**, then the tasks scheduled for today. |
| SY-03 | `UndoToast.dc.html` | Undo toast above the tab bar after the sheet closes, naming the last change ("Call the clinic back · now 30 min"). |

### iPad 11" landscape (1194 × 834): sidebar 280 · list 440 · detail fills

| ID | Frame file |
|---|---|
| TD-01 + DY-01 | `WideIpadDayReview.dc.html` |
| UP-01 + TK-02 | `WideIpadUpcoming.dc.html` |
| TK-07 | `WideIpadRepeat.dc.html` |
| TD-07 | `WideIpadMorning.dc.html` |
| TK-02a | `WideIpadEditEffort.dc.html` |
| TK-02b | `WideIpadEditDue.dc.html` |
| SY-03 | `WideIpadUndo.dc.html` |

### iPhone Duo inner, landscape (≈ 952 × 673, fold at 476)

| ID | Frame file |
|---|---|
| TD-01 + DY-01 | `WideDuoDayReview.dc.html` |
| UP-01 + TK-02 | `WideDuoUpcoming.dc.html` |
| TK-07 | `WideDuoRepeat.dc.html` |
| TD-07 | `WideDuoMorning.dc.html` |
| TK-02a | `WideDuoEditEffort.dc.html` |
| TK-02b | `WideDuoEditDue.dc.html` |
| SY-03 | `WideDuoUndo.dc.html` |

Duo point sizes are estimates carried over from the v4 handoff; confirm them against Apple's design resources.

### macOS window (1280 × 800): sidebar 250 · list 470 · inspector fills

| ID | Frame file |
|---|---|
| TD-01 + DY-01 | `WideMacDayReview.dc.html` |
| UP-01 + TK-02 | `WideMacTask.dc.html` |
| TK-07 | `WideMacRepeat.dc.html` |
| TD-07 | `WideMacMorning.dc.html` |
| TK-02a | `WideMacEditEffort.dc.html` |
| TK-02b | `WideMacEditDue.dc.html` |
| SY-03 | `WideMacUndo.dc.html` |

---

## 3. Navigation

### Where each thing opens

| From | iPhone / Duo folded / Duo inner portrait | iPad · Duo inner landscape · Mac |
|---|---|---|
| Today › **Yesterday** row | Push DY-01 | DY-01 fills the **detail column** (inspector on Mac). Today stays in the list column; the row shows the selected style. |
| Today › **Coming up** row | Push UP-01 | UP-01 **replaces Today in the list column**, with a back arrow to Today. |
| Tap a task (Today or Coming up) | TK-02 as a sheet | TK-02 in the detail column / inspector |
| Tap a field in TK-02 | Push its picker inside the sheet | iPad and Mac: popover anchored to the row, arrow pointing at it. Duo inner: push inside the right half with a back button. |
| Change to a repeating task | TK-07 as a second sheet | iPad and Mac: centred sheet, 540 pt (480 on Mac). Duo: bottom sheet over the right half. |
| Habits heatmap day / Wellbeing sparkline day | Push DY-01 (unchanged entry points) | Same, in the detail column |

The rule behind this split: **Coming up is a list, so it takes the list column. Day review is a view of one day, so it takes the detail column.** Keep it consistent across devices.

No new tab or sidebar destination is added. The tab bar, the sidebar (Today, Habits, Anchors, Wellbeing, Settings on iPad; Settings in the app menu on Mac) and the Duo vertical bar stay exactly as in v4.

### Gestures and shortcuts

- **iPhone:** swiping right on Today is a shortcut to Yesterday (DY-01). It's optional, and the row is the primary way in.
- **Day review:** previous/next arrows in its toolbar. On Mac, **⌘[** and **⌘]** do the same.
- **Mac pickers:** arrow keys move between options, Return chooses, Esc closes without change.
- **Mac:** Return with a task selected starts editing its title.

### SwiftUI notes (suggested, not prescriptive)

- Use `NavigationSplitView` for the wide layouts, with sidebar, content (list column) and detail. Swapping Today ↔ Coming up in the content column is a state change on the content column, not a new destination.
- On iPhone, present task detail with `.sheet` plus `presentationDetents([.large])`. Put a `NavigationStack` inside the sheet so field pickers push within it.
- On iPad and Mac, field pickers are `.popover(attachmentAnchor:)` on the row.
- TK-07 on iPad and Mac is a sheet sized to 540/480 pt, not a `confirmationDialog`. It carries a title, a sentence and three buttons, as drawn.
- Undo: register edits with the scene's `UndoManager` as one group per task visit. The toast calls `undo()`. ⌘Z comes for free on Mac.

---

## 4. Screen behaviour

### TD-01 · Today rows

- **Yesterday · {done} of {planned} done** appears whenever yesterday was a planned day. If yesterday wasn't planned, show **Yesterday · not planned** (still tappable). If there's no data at all (first day), hide the row.
- **Coming up · {n} next 14 days**: count of future-dated tasks plus one-off Anchors in the next 14 days. If n = 0, show **Coming up · nothing scheduled** and keep it tappable so users learn where future tasks go.
- Row order under the task list: *Also today*, *Yesterday*, *Coming up*. Past above future.

### UP-01 · Coming up

- Grouped by day for the next 14 days. The relative label (Tomorrow, In 2 days, Next week) is on the right of each day header.
- Anything after 14 days goes into a collapsed **Later · n** section.
- Row metadata: effort, plus "Due {weekday}" when the task has a deadline that differs from its scheduled day. Anchors show their time and "one-off Anchor".
- Checkboxes are dimmed but still work: marking a future task done is allowed.
- Copy: *"Nothing here counts toward capacity until you plan its day."*

### DY-01 · Day review

- Header: date (mono eyebrow) and previous/next arrows. Next is disabled on yesterday when going forward would reach today.
- Hero (two lines, second in italic accent), e.g. "A steady day. / Two of three done."
- Capacity used vs set, with **Closed {time}** if the day was closed in Night Planning.
- **Anchors:** attended count, with one square per occurrence (`--d3` attended, `--missed` missed).
- **Habits:** progress, one square (`--d1`/`--d2`/`--d3` by completion).
- **Tasks:**
  - Done tasks are struck through, with the time done.
  - Deferred tasks show "Deferred to {date}", dimmed.
  - Not-done tasks show "Not done · carried to {date}" and an outlined **Mark done** button. That button only appears within the two-day fix window.
- Footer: *"Past days are read-only. A missed tick can be fixed for two days."*

### TK-02 · Task detail (editor)

- **Header:** grabber (iPhone sheet), the `✓ Saved` mono label, and an ellipsis menu for less common actions (Duplicate, Move to another day; also Drop on Duo).
- **Category line**, then the **title**.
  - The title is plain serif text until tapped, then becomes an outlined field (`1.5px --accent` border, `--card` fill).
  - **Open design question:** add a persistent affordance (a small pencil icon or a faint tinted box) so the title reads as editable?
- **Fields**, each a full-width row with a chevron: Category, Effort, Matters, Due, Repeats, then History (read-only, no chevron).
- **Future task:** show *"This counts toward {weekday}'s capacity once you plan that day. It stays off Today until then."*
- **Actions:**
  - Future task: **Move to today** (terracotta), then Mark done · Defer · Drop (Drop uses `--alertSoft` / `--alert`).
  - Today task: **Begin** replaces Move to today.
  - Layout: one row on Mac. Stacked on iPhone, iPad and Duo (primary full width, the other three below), because the detail column is too narrow for four.
- **Move to today:** moves the task into today's plan and *does* count against today's capacity. If that overflows capacity, reuse the existing "Day is full" handling (TK-01).

### TK-02a · Effort

- Options: 15 min, 30 min, 45 min, 1 h, 90 min, 2 h. Two hours is the maximum; the helper copy suggests splitting bigger tasks.
- Selection uses the selected style (white + ink ring), with `aria-pressed` / accessibility selected trait.
- Choosing an option saves it and closes the picker (pops on iPhone and Duo, dismisses the popover on iPad and Mac).

### TK-02b · Due

- Quick options: Today, Tomorrow, the current due weekday if set, Next week (Monday), No date. Then a month grid starting on Monday.
- Today has a terracotta ring; the chosen date is filled ink; past dates are dimmed and disabled.
- Choosing a future date keeps or moves the task into Coming up. Choosing Today moves it into today's plan, the same as Move to today.

### TK-02c · Title

- Tapping the title focuses it. On iPhone the sheet expands to full height so the fields stay above the keyboard.
- The header becomes **Editing title** with a **Done** text button; Return also ends editing.
- The title saves continuously. An empty title on blur reverts to the previous value.

### TK-07 · Repeating task scope

- Eyebrow: the repeat rule ("Weekly on Monday").
- Hero: "Change just this one, / or every one after?"
- One sentence naming the change ("Effort goes from 30 to 45 min.").
- Buttons: **This and later {weekday}s** (terracotta), **Only this {weekday}** (outlined), **Cancel** (text). Cancel reverts the field change.
- Asked once per visit. Further edits in the same visit use the same answer.

### TD-07 · Morning card, scheduled tasks

- Shown on Today the morning after a skipped Night Planning, when tasks are scheduled for today.
- Hero: "{Weekday}, / unplanned."
- Card copy: *"No plan for today. {n} tasks are scheduled for it, so two minutes to confirm?"*
- **Pick for today** opens the shortened morning flow with these tasks offered. **Not now** dismisses the card for the day and leaves the tasks listed under *Scheduled for today*.
- On iPad, Duo and Mac the detail column shows a quiet "Nothing selected" message until a task is chosen.

### SY-03 · Undo toast

- Pill on `--deep` with `--onAccent` text: "{Task title} · {what changed}" plus an outlined **Undo** button (Mac shows ⌘Z beside it).
- **When it appears:** after the sheet closes (iPhone) or the user leaves an edited task (wider screens). Positioned above the tab bar on iPhone, and at the foot of the list column on iPad, Duo and Mac.
- **Duration:** about 4 s, extended while VoiceOver focus is on it. It doesn't appear if nothing changed.

---

## 5. Data and logic notes

- Tasks need a scheduled **day** (nullable) that is distinct from an optional **due** date. Coming up groups by scheduled day; "Due {weekday}" shows when the two differ.
- A task with a scheduled day after today is excluded from Today and from today's capacity. Night Planning (NP-02/NP-03) offers tomorrow's scheduled tasks; the morning flow (TD-07) offers today's.
- Day review needs a per-day snapshot or derivation of:
  - planned vs used capacity and the close time
  - Anchor occurrences with attended/missed
  - habit progress
  - task outcomes (done at, deferred to, carried to)
- Fix window: allow ticking a missed task or habit on a past day only if that day is today − 1 or today − 2.
- Undo groups are per task visit. A repeat-scope answer is part of the same group.

---

## 6. Accessibility

- Every control drawn is a real button; icon-only buttons have labels:
  - Back to Today
  - Previous day / Next day
  - Mark done
  - More
  - Back to task
- Picker options expose a selected state.
- Coming up rows are dimmed visually, but text contrast stays ≥ 4.5:1. Only the checkbox ring is dimmed.
- Touch targets are ≥ 44 pt everywhere except Mac, which uses 28–32 pt pointer targets, as in v4.
- The undo toast is announced as a status update.

---

## 7. Open questions for the build

1. Should the title get a persistent "editable" affordance (pencil or tinted box)?
2. What should the Yesterday row say after an unplanned day: "not planned", or hide the row?
3. Should Day review's previous arrow be capped (e.g. 90 days) or go back to the first day?
4. Should "Move to today" warn before pushing today over capacity, or use the existing TK-01 "Day is full" handling only?
