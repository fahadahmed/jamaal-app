# Journey 4 — Anchors: an Anchor's day, and creating them

> **Status: done — gaps G-27 … G-36 raised, decided and applied** (see the [gap log](overview#gap-log)). The text below is the walkthrough as first written, with the proposals it raised. Register flows **F06** (an Anchor's day) and **F07** (creating and managing Anchors); screens **AN-01 … AN-11** and the Anchors section of **TD-01**. Behaviour is in [Anchor](../../schema/anchor) and [Rules engine → module 3](../../architecture/rules-engine); this page tests it against the schema and engine.

**In one line:** the user sees today's fixed commitments with how much time is left to honour each, marks them attended, not today or done by someone else, and — when something new appears in their life — creates a rule or a one-off for it.

**Preconditions:** Journeys 1–3 done. Examples: a prayer-times rule (Fajr … Isha), a school run (drop-off 08:15), a plants rule (3–4 days after last watered) and a one-off dentist appointment tomorrow at 15:00.

---

## Part A — An Anchor's day (F06)

### TD-01 The Anchors section

- **Sees:** Anchors sorted by window start. A **plain row** for an Anchor, or a **grouped row** for a rule that yields several today (*"Salah 3/5 · Asr · until 17:58"*) that expands into its members. Each row shows its **window bar** (upcoming · open · closing soon · closed) and its outcome once decided. A plants-style Anchor shows **"open · closes Thu"** and stays on Today for every day it is open.
- **Reads:** Anchors with `occurrenceDate` = today's logical date, plus pending `afterLast` Anchors whose multi-day window overlaps today; each one's rule (`rule.title`); the clock, to derive window states.
- **Does:** taps a row to act; taps a grouped row to expand (local UI state).
- **Assumes:**
  - the list needs only stored Anchors — ✓ (generation covers today and tomorrow; one-offs are stored when created);
  - a grouped row can name itself and its members — **✗ G-27** (`Anchor.title` is "Fajr"; "Salah" lives on the rule, and a rule with two slots needs both names — the composition rule isn't written);
  - Anchors are never hidden by the capacity level — **✗ G-35** (still an open question; the register says always shown);
  - a window that has closed while the app was closed reads as missed at once — ✓ (closed and pending is shown as missed immediately; the stored status is finalised at the next evaluation).

### AN-10 Acting on an Anchor

- **Does:** taps the row and chooses **Attended**, **Not today** or **Someone else did it**.
- **Rules:** *Attended* only while the window is open or closing soon (an upcoming row is disabled and says when it opens); the other two any time before it closes; a closed window is final.
- **Writes:** `Anchor.attendanceStatus` (`attended` / `skipped` / `delegated`).
- **Assumes:**
  - when the decision happened is known — **✗ G-29** (there is no `resolvedAt`; it is needed to show "attended 12:52", to date a plants-style Anchor's *last done*, and to support late correction);
  - a forgotten tap can be fixed — **✗ G-28** (the docs leave "closed is final" as an open question, but someone who prayed and simply didn't tap cannot fix it);
  - the next plants-style window is scheduled from the right date — **✗ G-29** (the base date is the day it was *handled*, not the day its window opened).

### Reminders and the clock

- **Sees:** a notification at a window's start and/or shortly before it closes, if the rule says so (nothing nags by default).
- **Reads:** generated Anchors within the notification horizon.
- **Assumes:**
  - reminders are defined — **✗ G-30** (module 6 mentions Anchor guidance, but there is no per-Anchor reminder setting, none for one-offs, and generation only reaches tomorrow, so reminders would stop after two days without opening the app).

---

## Part B — Creating and managing Anchors (F07)

### AN-01 The rules list (Habits tab → Anchors)

- **Sees:** each rule with a one-line schedule (*"Mon–Fri · 08:15 · 30 min"*), its next Anchor, and a state: active, paused, **needs attention**. **Add** at the top.
- **Reads:** `AnchorRule` (not archived), the next generated Anchor per rule.
- **Assumes:** archived rules are hidden but keep their history — ✓ (`isArchived`; never hard-deleted).

### AN-02 A rule's detail

- **Sees:** its schedule, exceptions, **upcoming days** (*"Tomorrow · Thu · Fri …"*), and Edit · Pause · Archive.
- **Assumes:** upcoming days beyond tomorrow exist — **✗ G-34** (only today and tomorrow are stored; showing a week ahead needs a **dry-run preview** of the generator, a pure function with no writes).

### AN-03 Choose a type

- **Sees:** Prayer times · School run · Bin night · Plant watering · Custom; each opens its form with a preset.
- **Reads/writes:** nothing until the form is saved.

### AN-04 Prayer times (with AN-11 location)

- **Sees:** location (*Use my location* → the system prompt, in context; or a city search), calculation **method** (suggested from the region), madhab, which prayers, **Isha ends at** (Islamic midnight by default), an *Advanced* disclosure (per-prayer minute adjustments, the high-latitude rule), duration (default 10 min), and reminders.
- **Writes:** an `AnchorRule` with `sourceKey = prayerWindow`, the `configData` shape, `effortMinutes`, `placement = fixed`; the engine generates Anchors for today (only windows that haven't closed) and tomorrow.
- **Assumes:**
  - a method can be suggested from the region — **✗ G-31** → *resolved*: the prayer-time library exists (`adhan-swift`), but has no region helper, so a small suggestion table is bundled in `JamaalCore`;
  - the stored location is right on several devices — **✗ G-32** (in *device* mode every device with location could overwrite the same rule's coordinate; an iPhone travelling and a Mac sitting at home would fight);
  - Friday is handled — **✗ G-36** → *decided*: a **Friday label** (the Friday Dhuhr Anchor is titled "Jumu'ah");
  - city search works without location — ✓ (needs network; offline the user can still enter the rule later).

### AN-05 The scheduled form (school run, bin night, plants, custom)

- **Sees:** recurrence (weekdays · every *N* days · every *N* weeks · *N–M* days after I last did it), named time slots (start, window length, or all-day), duration, placement, optional end date, reminders.
- **Writes:** an `AnchorRule` (`configData` scheduled shape, slot ids as `slotKey`s).
- **Assumes:**
  - the preset fills sensible defaults — ✓;
  - a plants-style rule knows when it was last done — **✗ G-33** (`afterLast` has only a `startDate`, described as when the first window opens; the form must ask *"When did you last do this?"*, with *Due now* as the other answer).

### AN-06 Exceptions

- **Sees:** a list of date ranges (term break, holiday, travel, illness, other; the end can be open) and **Add**. Overlapping ranges are merged; an end before its start is rejected.
- **Writes:** `configData.exceptions`. Adding one removes pending Anchors inside it; attended, missed, skipped and delegated ones stay.
- **Assumes:** ✓ (module 3 covers it).

### AN-07 "Needs attention"

- **Sees:** a rule whose `configData` can't be read — *"Update Jamaal to see this rule"* (a newer version) or *"This rule couldn't be read"* with Edit and Archive. It is never generated and never deleted.
- **Assumes:** ✓.

### AN-08 A one-off Anchor

- **Sees:** title, date, window start and end (the end after the start, and in the future), optional duration, and reminders.
- **Writes:** an `Anchor` with `rule = nil`, `occurrenceDate = logicalDate(windowStart)`, `slotKey = ""`, `effortMinutes`, `placement` implicitly fixed.
- **Assumes:**
  - a one-off on a future date is stored now and appears on its day — ✓ (Today filters by `occurrenceDate`);
  - a one-off can carry a reminder — **✗ G-30** (only generated Anchors would inherit one from a rule; a one-off has no rule).

---

## What the user sees at each point

After creating prayer times at 14:05 with the rest of the day to go: Today shows **Salah 0/3**, the next being Asr — Fajr and Dhuhr were already closed when the rule was created and were never generated. As Asr's window nears its end the row's bar turns to *closing soon*; if a focus session is running, the chip says *"Asr closes in 10 min"*. Tapping **Attended** while it is open marks it done; after it closes, the row reads *missed* (and, with G-28, *"Mark as done after all"* is offered until the end of that day).

## Data that exists afterwards (end-state check)

| Model | Change |
|---|---|
| `AnchorRule` | + 1 per rule (`sourceKey`, `configData` incl. exceptions, `effortMinutes`, `placement`) |
| `Anchor` | generated for today and tomorrow (`occurrenceDate`, `slotKey`, window, `effortMinutes`, `attendanceStatus`); one-offs stored when created |
| Fields that don't exist yet | `Anchor.resolvedAt` (G-29); `Anchor.remindBeforeStartMinutes` and `remindBeforeEndMinutes`, and a `reminder` object in `configData` (G-30) |

Everything else is storable now.

## Rules and changes this journey implies

If the proposals are accepted:

1. **Titles (G-27):** `Anchor.title` stores the **slot label** (or the rule's title when the slot has none). A plain row shows `rule.title`, adding the slot label when it differs (*"School run · Drop-off"*); a grouped row is titled with `rule.title` and lists members by slot label (*Fajr, Dhuhr, …*). A one-off's title is whatever the user typed.
2. **Late correction (G-28):** a **missed** Anchor offers *"Mark as done after all"* until the end of that logical day (a neutral confirmation showing the time). It never reopens *skipped* or *delegated*, and it does not weaken the rule that *attended* can't be logged before a window opens.
3. **`Anchor.resolvedAt: Date?` (G-29):** set when the status leaves `pending` (and updated by a late correction). A plants-style rule's next window is scheduled from the logical date of `resolvedAt` of an attended, skipped or delegated instance.
4. **Reminders (G-30):** rule config gains `reminder: { atStart: Bool, beforeEndMinutes: Int? }`; generated Anchors copy it into `Anchor.remindBeforeStartMinutes` (0 = at the start) and `Anchor.remindBeforeEndMinutes`; one-offs set them directly. **Defaults:** prayer times remind **at the start**, everything else **off**, and a closing reminder is always opt-in (nothing nags). Notifications are scheduled over a **five-day** horizon using the generator's preview (not only the two stored days), inside the 64-notification budget, and re-planned on launch, on foreground and on background refresh.
5. **Prayer method (G-31, resolved):** the prayer-time library is **`adhan-swift`** (MIT, maintained, builds on Xcode 27, and its methods, madhabs and high-latitude rules match our config names). It has no region helper, so a bundled **region → method and madhab table** in `JamaalCore` pre-selects the form (table in [anchor.md](../../schema/anchor#prayer-method-suggestion); the owner reviews it). No separate package is needed unless the owner wants to reuse the table outside Jamaal.
6. **Location on several devices (G-32):** in *device* mode a device writes the rule's coordinate **only when that device has itself moved** materially (about 25 km) since its own last check, never merely because its position differs from the stored one. A Mac at home never writes; a travelling iPhone does.
7. **Plants-style start (G-33):** for `afterLast`, `startDate` means **the date it was last handled** (the form asks *"When did you last do this?"*, default *Today*, or *Due now*, which sets it `minDays` ago). The first window opens `minDays` later.
8. **Preview (G-34):** the engine exposes a dry-run `preview(rule, days)` that returns the Anchors a rule *would* generate, used by the rule detail and by reminder scheduling.
9. **Capacity level (G-35):** Anchors are **always shown**, at every level.
10. **Jumu'ah (G-36, decided):** the prayer rule has a `fridayLabel` option (on by default): Friday's Dhuhr Anchor is titled *"Jumu'ah"* — same window, same time, only the name changes.
