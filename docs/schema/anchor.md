# Anchor

> **Status: reviewed, resolved for v1.** Positioning settled (recurring rules plus one-offs) and `configData` shapes defined. Anchor postdates the earlier planning chat (master summary v2 has no Anchor) — see [ADR 0002](../architecture/decisions/0002-reconcile-master-summary-v2). Rationale for Anchor as a third primitive: [ADR 0001](../architecture/decisions/0001-anchor-object-type).

Something the user's life **moves around**. Created by the user in one of two ways: a **recurring commitment** (an `AnchorRule`, from which the app **generates** the instances) or a **one-off** Anchor added directly with no rule (a dentist appointment, a parents' evening). Tracked via attendance rather than streaks. Timing and the consequence of a miss are external to the user. Examples: prayer windows (including salah — see [habit.md](habit) for why salah lives here and not as a Habit), school runs, bin night, watering plants, and one-off fixed-time events.

Users see these as **"Anchors"** — the name is the same in the UI and the code. (The design project's flow spec calls the same idea a "ritual"; that label is retired in favour of Anchor, and the design should be relabelled.)

**Anchor vs. Task**: an Anchor has a fixed time the user can't move and is tracked by attendance; a Task with a due date is flexible and tracked by completion. A dentist appointment is an Anchor; "book a dentist appointment" is a Task.

## Fields

| Field             | Type       | Default    | Notes |
| ----------------- | ---------- | ---------- | ----- |
| `id`              | `UUID`     | `UUID()`   | |
| `title`           | `String`   | `""`       | The **slot label** ("Fajr", "Drop-off"), or the rule's title when the slot has none; for a one-off, whatever the user typed. Display composition: see [Titles on Today](#titles-on-today). |
| `occurrenceDate`  | `Date`     | `.now`     | A **floating calendar date** (see [The day boundary](../architecture/rules-engine#the-day-boundary)). The day this Anchor **belongs to**: `logicalDate(windowStart)` — the day its window starts, even if the window ends after midnight (Isha in summer) or, with a user-set rollover, an Anchor starting at 01:00 belongs to the previous day. Today and Night Planning filter on this, not on `windowStart`. |
| `slotKey`         | `String`   | `""`       | Stable identity of the slot within its rule: the prayer name (`"fajr"`) or the slot's id from `configData`. Empty for one-offs. With `rule` and `occurrenceDate` it uniquely identifies a generated instance even if its times later change. |
| `windowStart`     | `Date`     | `.now`     | Start of the external window this instance is anchored to. |
| `windowEnd`       | `Date`     | `.now`     | End of the window; after this, a miss is final for this instance. May fall after midnight. |
| `effortMinutes`   | `Int?`     | `nil`      | How long attending takes. Copied from `AnchorRule.effortMinutes` when an instance is generated; set directly on one-offs. Counts toward committed time in the load check. `nil` = unknown, counts as zero. |
| `attendanceStatus`| `String`   | `"pending"`| One of `pending` / `attended` / `missed` / `skipped` / `delegated`. `skipped` ("Not today" — a bin night that isn't happening) is **not a miss**. `delegated` ("Done by someone else" — another person did the school run) is handled, not a miss. Both are excluded from wellbeing patterns and from the day's load once set, and shown neutrally. See [Window state and logging rules](#window-state-and-logging-rules). Sufficient on its own for v1 — no separate "consequence" field; any messaging about what a miss means is UI/copy, not data (confirmed in review). |
| `resolvedAt`      | `Date?`    | `nil`      | When the status left `pending` (attended, skipped or delegated; or set to `missed` when a window closes), and updated by a late correction. Shows "attended 12:52" and dates a plants-style rule's *last handled* day. |
| `remindBeforeStartMinutes` | `Int?` | `nil` | A reminder this many minutes before the window opens; `0` = at the start; `nil` = none. Copied from the rule's `reminder` at generation; set directly on one-offs. |
| `remindBeforeEndMinutes` | `Int?` | `nil` | A closing reminder this many minutes before the window ends; `nil` = none. Opt-in. |
| `generatedAt`     | `Date`     | `.now`     | |

### Titles on Today

A **plain row** shows `rule.title`, adding the slot label when it differs ("School run · Drop-off"). A **grouped row** (a rule with several Anchors today) is titled `rule.title` and lists its members by slot label (Fajr, Dhuhr, …). A one-off shows its own title.

## Relationships

- `rule: AnchorRule?` (optional, per CloudKit relationship constraint) — the rule that generated this instance. **`nil` means a one-off Anchor** created directly by the user (derived, not a separate flag).

### `AnchorRule`

Anchor instances are generated from a persisted `AnchorRule` (not computed on the fly), so user-defined recurring commitments work without code changes.

| Field           | Type     | Default    | Notes |
| --------------- | -------- | ---------- | ----- |
| `id`            | `UUID`   | `UUID()`   | |
| `title`         | `String` | `""`       | |
| `sourceKey`     | `String` | `"custom"` | One of `prayerWindow` / `schoolRun` / `binNight` / `plantWatering` / `custom`. |
| `configData`    | `String` | `"{}"`     | JSON, versioned; shape depends on the rule's family — see [`configData` shapes](#configdata-shapes). |
| `effortMinutes` | `Int?`   | `nil`      | How long attending takes (Fajr ≈ 10, school run ≈ 30) — **not** the window length (Fajr's window may be 90 minutes). Applies to every instance the rule generates. `nil` = unknown, counts as zero. |
| `placement`     | `String` | `"fixed"`  | `fixed` or `flexible`. **Fixed** = a busy block from the window start for `effortMinutes`, which *cuts* the working day into free blocks (school run, an appointment). **Flexible** = it takes minutes but has no fixed position inside its window, so it only reduces total free time (bin night). `afterLast` rules are always flexible; one-off Anchors are always fixed. Used by the capacity check — see [rules-engine.md](../architecture/rules-engine), module 7. |
| `isEnabled`     | `Bool`   | `true`     | Paused / resumed by the user. |
| `isArchived`    | `Bool`   | `false`    | Soft-delete. A rule is **never hard-deleted**: `Anchor.rule == nil` means a one-off, so deleting a rule would make all its past instances look like one-offs. Archiving hides the rule and removes its future pending instances; history stays linked. |
| `createdAt`     | `Date`   | `.now`     | Also the floor for generation: an instance is never created for a window that ended before it (see [rules-engine.md](../architecture/rules-engine), module 3). |

## `configData` shapes

`configData` is a JSON string (CloudKit-safe, no extra models). It always carries `"version"`. JamaalCore decodes it into a versioned, `Codable` type, and there are exactly **two families**:

- **Computed** — `prayerWindow`. Windows come from astronomy.
- **Scheduled** — `schoolRun`, `binNight`, `plantWatering` and `custom`. These differ only in labels, icons and defaults, not structure: a *recurrence* plus one or more *time slots*. `custom` is simply the scheduled shape with no preset.

If `configData` can't be decoded (invalid, or a newer `version` than this app understands — possible when another device runs a newer build), the rule is **not generated and not deleted**: it shows as "needs attention" in the rules list. Nothing crashes, and nothing is lost.

### Scheduled shape

```json
{
  "version": 1,
  "recurrence": { "kind": "weekly", "weekdays": [1,2,3,4,5] },
  "slots": [
    { "id": "3F2A…", "label": "Drop-off", "start": "08:15", "windowMinutes": 30 },
    { "id": "9C71…", "label": "Pick-up",  "start": "15:00", "windowMinutes": 30 }
  ],
  "endDate": null,
  "reminder": { "atStart": false, "beforeEndMinutes": null }
}
```

**Recurrence** (`kind`):

| `kind` | Fields | Meaning |
| ------ | ------ | ------- |
| `weekly` | `weekdays` (ISO Mon=1 … Sun=7, non-empty) | Those weekdays, every week. |
| `everyNDays` | `n` (≥ 1), `startDate` | Every *n* days counted from `startDate` (e.g. plant watering every 3 days). |
| `everyNWeeks` | `n` (≥ 1), `weekdays`, `startDate` | Those weekdays every *n*th week from the week of `startDate` (e.g. fortnightly bin rotation). |
| `afterLast` | `minDays` (≥ 1), `maxDays` (≥ `minDays`), `startDate` | **Interval from last done**, not the calendar: the window opens `minDays` after the last time it was handled and closes at the end of day `maxDays` (e.g. plants, "every 3–4 days"). Here `startDate` is **the date it was last handled**. See below. |

**`afterLast` semantics.** It is a *floating* Anchor — it takes time but doesn't cut the day into fixed gaps (calendar-based kinds are the day's fixed "spine"). There is exactly one live instance per slot. `startDate` is the date the thing was **last handled**: the form asks *"When did you last do this?"* (default today, or *Due now*, which sets it `minDays` ago), and the first window opens `minDays` after it. Each next instance is created when the current one is resolved, and opens `minDays` after the **logical date of its `resolvedAt`** (for an `attended`, `skipped` or `delegated` instance). If an instance ends `missed`, the next one opens the following day and stays open for the same length, so a missed watering isn't pushed a further 3 days away. Its slots are always all-day (`start` / `windowMinutes` are ignored). Its window may span several days, so it appears on Today on every day it is open, and `occurrenceDate` is the day it opened.

Monthly patterns are intentionally not offered for Anchors; recurring monthly things ("pay rent") are [repeating Tasks](task#repeating-tasks).

**Slots** (at least one). Each occurrence-day generates one Anchor per slot.

| Field | Notes |
| ----- | ----- |
| `id` | Stable string, used as `slotKey`. Never reused, so reordering or deleting slots can't mismatch instances. |
| `label` | e.g. "Drop-off". Used in the instance title. |
| `start` | Local wall-clock `"HH:mm"`, interpreted in the device's current time zone, so travelling keeps 08:15 as 08:15. |
| `windowMinutes` | How long the Anchor stays open after `start`; the window may cross midnight. |
| `allDay` | Optional, default `false`. If `true`, the window is the whole day and `start` / `windowMinutes` are ignored (plant watering). |

`endDate` (optional) stops generation after that date.

**Preset defaults** (placeholders, all editable and tunable):

| `sourceKey` | Recurrence | Slots | `effortMinutes` |
| ----------- | ---------- | ----- | --------------- |
| `schoolRun` | weekly Mon–Fri | "Drop-off" 08:15, 30 min (user can add "Pick-up") | 30 |
| `binNight` | weekly, one weekday (default Wed) | "Bin night" 19:00, 180 min | 10 |
| `plantWatering` | afterLast, 3–4 days | all-day | 10 |
| `custom` | weekly, no default days | none — user adds at least one | none |

**Placement defaults**: `schoolRun` fixed, `binNight` flexible, `plantWatering` flexible (always, as `afterLast`), `custom` fixed, and `prayerWindow` **fixed at the start of each window** — each prayer then cuts the day at its time, as the design draws it (Maghrib at 18:40 splitting the evening). The user can switch prayers to flexible. Only busy time inside the working day counts, so prayers after the day's end don't cut it.

### Prayer shape (`prayerWindow`)

```json
{
  "version": 1,
  "method": "northAmerica",
  "madhab": "shafi",
  "highLatitude": "middleOfNight",
  "ishaEnds": "midnight",
  "fridayLabel": true,
  "reminder": { "atStart": true, "beforeEndMinutes": null },
  "prayers": ["fajr", "dhuhr", "asr", "maghrib", "isha"],
  "adjustmentsMinutes": { "fajr": 0, "dhuhr": 0, "asr": 0, "maghrib": 0, "isha": 0 },
  "location": { "mode": "device", "latitude": -36.85, "longitude": 174.76, "name": "Auckland" }
}
```

| Field | Values / notes |
| ----- | -------------- |
| `method` | Calculation method — exactly the set the prayer-time library (`adhan-swift`) provides: `muslimWorldLeague`, `egyptian`, `karachi`, `ummAlQura`, `dubai`, `moonsightingCommittee`, `northAmerica`, `kuwait`, `qatar`, `singapore`, `tehran`, `turkey` (its `other` is for custom angles and is not offered). Suggested from the user's region by the [method suggestion table](#prayer-method-suggestion) and always editable. |
| `madhab` | `shafi` (standard Asr) or `hanafi`. |
| `highLatitude` | `middleOfNight` / `seventhOfNight` / `twilightAngle`. Only matters far from the equator. |
| `fridayLabel` | `true` (default) titles **Friday's Dhuhr Anchor "Jumu'ah"**: same window, same time, same `slotKey` (`dhuhr`); only the name changes. `false` keeps "Dhuhr" on Fridays. |
| `ishaEnds` | `midnight` (default: Islamic midnight, the midpoint between Maghrib and the next Fajr) or `fajr`. |
| `prayers` | Subset of the five to generate. Slot keys are the prayer names. |
| `adjustmentsMinutes` | Per-prayer offset (may be negative) for matching a local mosque timetable. |
| `location` | See below. |

### Prayer method suggestion

The prayer-time library has no region helper, so a small table is **bundled in JamaalCore** (keyed by ISO country code, from the location's country or the device region). It only pre-selects the method and madhab in the form; the user can change both. Drafted from the library's own notes on where each method is used; **the owner should review it**.

| Country | Method | Asr (madhab) |
| ------- | ------ | ------------ |
| US, CA, GB | `moonsightingCommittee` (the library recommends it for North America and the UK; `northAmerica` / ISNA is offered as the alternative) | standard |
| SA | `ummAlQura` | standard |
| AE | `dubai` | standard |
| KW | `kuwait` | standard |
| QA | `qatar` | standard |
| SG, MY, ID | `singapore` | standard |
| TR | `turkey` | Hanafi |
| IR | `tehran` | standard |
| EG | `egyptian` | standard |
| PK, IN, BD, AF | `karachi` | Hanafi |
| anywhere else | `muslimWorldLeague` | standard |

**Windows**: Fajr → sunrise · Dhuhr → Asr · Asr → Maghrib · Maghrib → Isha · Isha → `ishaEnds`. Adjustments shift each prayer's computed start, and windows derive from the adjusted times. Times are computed on-device from date, location and these settings, so the result is deterministic. Isha's window may end after civil midnight in summer; the Anchor still belongs to the day it starts.

**Location** (`location.mode`):

- `device` (default): when-in-use location permission, requested only when prayer times are chosen (not up front). Only a **coarse coordinate** (rounded to about 1 km) and a place name are stored — precise coordinates never sync to iCloud. The coordinate is synced with the rule, so only one device should move it: **a device writes it only when *it* has moved materially (about 25 km) since its own last check**, never merely because its position differs from the stored value. A Mac at home never writes; a travelling iPhone does. When the coordinate changes, future pending instances are regenerated (past ones are never touched).
- `manual`: a city the user searches for and picks; used automatically if location permission is denied. Never changes unless edited.

## Exceptions

Both families accept an optional `exceptions` list in `configData` — date ranges when the rule's windows **don't exist at all** (term break, holiday, travel, illness):

```json
"exceptions": [
  { "from": "2026-12-15", "to": "2027-01-27", "reason": "holiday" },
  { "from": "2027-03-02", "to": null, "reason": "illness" }
]
```

- `reason` is one of `term` / `holiday` / `travel` / `illness` / `other` and is for display only.
- `to: null` means open-ended, until the user ends it.
- Inside an exception no instances are generated — they are not `skipped` and not `missed`, and simply don't appear. Adding an exception removes pending instances inside it; attended, missed, skipped and delegated ones are kept.
- For `afterLast` rules the interval clock pauses: no window opens during the exception, and the next one opens when it ends.
- Exceptions replace the earlier "pause a rule until a date" idea. Per-instance `skipped` remains for one-off cases ("no bins this week").

## Reminders

Both families accept an optional `reminder` object in `configData`: `atStart` (a reminder when the window opens) and `beforeEndMinutes` (a closing reminder that many minutes before it ends, or `null`). Generated Anchors copy it into `Anchor.remindBeforeStartMinutes` (`0` when `atStart`, else `nil`) and `Anchor.remindBeforeEndMinutes`; one-offs set those two fields directly.

- **Defaults:** prayer times remind **at the start**; every other rule has reminders **off**. A closing reminder is always opt-in — nothing nags.
- **Scheduling:** notifications are planned over the next **five days** using the generator's preview (not just the two stored days), inside the 64-pending-notification budget, and re-planned on launch, on foreground and on background refresh. See [rules-engine.md](../architecture/rules-engine), module 6.

## Window state and logging rules

Each Anchor has a **window state** derived from the clock — never stored:

| State | When |
| ----- | ---- |
| `upcoming` | now is before `windowStart` |
| `open` | inside the window |
| `closingSoon` | inside the last part of the window (proposal: the last 25%, at least 10 minutes — tunable) |
| `closed` | now is at or after `windowEnd` |

The state is what an Anchor row shows on Today (with a window bar); the attendance status is the outcome. Logging rules:

- **`attended` can only be logged while the window is `open` or `closingSoon`.** An `upcoming` Anchor can't be ticked (the control is disabled and shows when the window opens). This also covers cases like a second medication dose logged early, without a medication-specific rule — each dose is its own Anchor with a single status.
- **`skipped` and `delegated` can be set any time before the window closes**, including while `upcoming`.
- **`closed` is final, with one exception:** a still-`pending` Anchor becomes `missed`, but a **missed** Anchor offers *"Mark as done after all"* until the end of that logical day (the day containing the instant its window closed), with a neutral confirmation showing the time. It sets `attended` and updates `resolvedAt`. It never reopens `skipped` or `delegated`, and it does not weaken the rule that `attended` can't be logged before a window opens.
- An accidental tap can be undone within the window (a quiet undo).

## CloudKit constraints applied

- All properties have defaults or are optional.
- No unique constraints — instance uniqueness is enforced by the engine (see [rules-engine.md](../architecture/rules-engine), module 3), keyed by `(rule, occurrenceDate, slotKey)`.
- The `rule` relationship is optional.

## Open questions

- **Editing behaviour** (proposal): editing or disabling an `AnchorRule` updates pending instances from today onward in place and never rewrites attended, missed, skipped or delegated ones; details in [rules-engine.md](../architecture/rules-engine). Editing a one-off changes just that Anchor; deleting one removes it.
- **Deleting a rule** archives it (`isArchived`): it disappears from the rules list, its future *pending* instances are removed, and attended / missed / skipped / delegated history stays linked to it.
- **`afterLast` details**: whether a rule may combine several slots with `afterLast` (probably one slot), and whether `minDays`/`maxDays` should adapt with season (the design mentions drift) or stay user-set.
- **Per-slot duration**: `effortMinutes` is one value per rule, so every prayer or slot gets the same duration. Fine for v1.
- **One-off boundary**: should one-offs support notes or a location? Not modelled; likely not needed for v1.
- **Sharing/referral**: deferred to v1.1 (see CLAUDE.md), no schema impact for now.
