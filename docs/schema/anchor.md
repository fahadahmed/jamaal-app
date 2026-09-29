# Anchor

> **Status: reviewed, resolved for v1.** Positioning settled (recurring rules plus one-offs) and `configData` shapes defined. Anchor postdates the earlier planning chat (master summary v2 has no Anchor) — see [ADR 0002](../architecture/decisions/0002-reconcile-master-summary-v2). Rationale for Anchor as a third primitive: [ADR 0001](../architecture/decisions/0001-anchor-object-type).

Something the user's life **moves around**. Created by the user in one of two ways: a **recurring commitment** (an `AnchorRule`, from which the app **generates** the instances) or a **one-off** Anchor added directly with no rule (a dentist appointment, a parents' evening). Tracked via attendance rather than streaks. Timing and the consequence of a miss are external to the user. Examples: prayer windows (including salah — see [habit.md](habit) for why salah lives here and not as a Habit), school runs, bin night, watering plants, and one-off fixed-time events.

Users see these as **"Anchors"** — the name is the same in the UI and the code.

**Anchor vs. Task**: an Anchor has a fixed time the user can't move and is tracked by attendance; a Task with a due date is flexible and tracked by completion. A dentist appointment is an Anchor; "book a dentist appointment" is a Task.

## Fields

| Field             | Type       | Default    | Notes |
| ----------------- | ---------- | ---------- | ----- |
| `id`              | `UUID`     | `UUID()`   | |
| `title`           | `String`   | `""`       | e.g. "Fajr", "School run — pickup", "Bin night". |
| `occurrenceDate`  | `Date`     | `.now`     | Day granularity. The day this Anchor **belongs to** — the day its window starts, even if the window ends after midnight (Isha in summer). Today and Night Planning filter on this, not on `windowStart`. |
| `slotKey`         | `String`   | `""`       | Stable identity of the slot within its rule: the prayer name (`"fajr"`) or the slot's id from `configData`. Empty for one-offs. With `rule` and `occurrenceDate` it uniquely identifies a generated instance even if its times later change. |
| `windowStart`     | `Date`     | `.now`     | Start of the external window this instance is anchored to. |
| `windowEnd`       | `Date`     | `.now`     | End of the window; after this, a miss is final for this instance. May fall after midnight. |
| `effortMinutes`   | `Int?`     | `nil`      | How long attending takes. Copied from `AnchorRule.effortMinutes` when an instance is generated; set directly on one-offs. Counts toward committed time in the load check. `nil` = unknown, counts as zero. |
| `attendanceStatus`| `String`   | `"pending"`| One of `pending` / `attended` / `missed` / `skipped`. `skipped` ("Not today" — school holidays, a bin night that isn't happening) is **not a miss**: it is excluded from wellbeing patterns and shown neutrally. Sufficient on its own for v1 — no separate "consequence" field; any messaging about what a miss means is UI/copy, not data (confirmed in review). |
| `generatedAt`     | `Date`     | `.now`     | |

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
| `isEnabled`     | `Bool`   | `true`     | |
| `createdAt`     | `Date`   | `.now`     | |

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
  "endDate": null
}
```

**Recurrence** (`kind`):

| `kind` | Fields | Meaning |
| ------ | ------ | ------- |
| `weekly` | `weekdays` (ISO Mon=1 … Sun=7, non-empty) | Those weekdays, every week. |
| `everyNDays` | `n` (≥ 1), `startDate` | Every *n* days counted from `startDate` (e.g. plant watering every 3 days). |
| `everyNWeeks` | `n` (≥ 1), `weekdays`, `startDate` | Those weekdays every *n*th week from the week of `startDate` (e.g. fortnightly bin rotation). |

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
| `plantWatering` | everyNDays, n = 3 | all-day | 10 |
| `custom` | weekly, no default days | none — user adds at least one | none |

### Prayer shape (`prayerWindow`)

```json
{
  "version": 1,
  "method": "northAmerica",
  "madhab": "shafi",
  "highLatitude": "middleOfNight",
  "ishaEnds": "midnight",
  "prayers": ["fajr", "dhuhr", "asr", "maghrib", "isha"],
  "adjustmentsMinutes": { "fajr": 0, "dhuhr": 0, "asr": 0, "maghrib": 0, "isha": 0 },
  "location": { "mode": "device", "latitude": -36.85, "longitude": 174.76, "name": "Auckland" }
}
```

| Field | Values / notes |
| ----- | -------------- |
| `method` | Calculation method, e.g. `northAmerica`, `muslimWorldLeague`, `ummAlQura`, `karachi`, `egyptian`. The final list follows whichever prayer-time library is chosen at implementation; onboarding suggests a default from the user's region and lets them change it. |
| `madhab` | `shafi` (standard Asr) or `hanafi`. |
| `highLatitude` | `middleOfNight` / `seventhOfNight` / `twilightAngle`. Only matters far from the equator. |
| `ishaEnds` | `midnight` (default: Islamic midnight, the midpoint between Maghrib and the next Fajr) or `fajr`. |
| `prayers` | Subset of the five to generate. Slot keys are the prayer names. |
| `adjustmentsMinutes` | Per-prayer offset (may be negative) for matching a local mosque timetable. |
| `location` | See below. |

**Windows**: Fajr → sunrise · Dhuhr → Asr · Asr → Maghrib · Maghrib → Isha · Isha → `ishaEnds`. Adjustments shift each prayer's computed start, and windows derive from the adjusted times. Times are computed on-device from date, location and these settings, so the result is deterministic. Isha's window may end after civil midnight in summer; the Anchor still belongs to the day it starts.

**Location** (`location.mode`):

- `device` (default): when-in-use location permission, requested only when prayer times are chosen (not up front). Only a **coarse coordinate** (rounded to about 1 km) and a place name are stored — precise coordinates never sync to iCloud. Refreshed when the app opens or the user travels; when the coarse position changes materially, future pending instances are regenerated (past ones are never touched).
- `manual`: a city the user searches for and picks; used automatically if location permission is denied. Never changes unless edited.

## CloudKit constraints applied

- All properties have defaults or are optional.
- No unique constraints — instance uniqueness is enforced by the engine (see [rules-engine.md](../architecture/rules-engine), module 3), keyed by `(rule, occurrenceDate, slotKey)`.
- The `rule` relationship is optional.

## Open questions

- **Editing behaviour** (proposal): editing or disabling an `AnchorRule` updates pending instances from today onward in place and never rewrites attended, missed or skipped ones; details in [rules-engine.md](../architecture/rules-engine). Editing a one-off changes just that Anchor; deleting one removes it.
- **Deleting a rule**: removes its future *pending* instances and keeps attended/missed history (proposed).
- **Pausing a rule until a date** (school holidays, travel) instead of skipping instance by instance. Proposal: a `pausedUntil: Date?` on `AnchorRule`; not added yet.
- **Jumu'ah**: on Fridays Dhuhr is replaced by the Friday prayer. Not modelled — needs a label or a separate slot rule, and the user's call.
- **Anchor reminders**: no per-rule reminder lead time (before window start / before it closes) yet — see [rules-engine.md](../architecture/rules-engine), module 6.
- **Per-slot duration**: `effortMinutes` is one value per rule, so every prayer or slot gets the same duration. Fine for v1.
- **One-off boundary**: should one-offs support notes or a location? Not modelled; likely not needed for v1.
- **Sharing/referral**: deferred to v1.1 (see CLAUDE.md), no schema impact for now.
