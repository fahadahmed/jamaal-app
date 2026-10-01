# Schema overview (freeze candidate)

> **Status: freeze candidate — draft, needs review.** One consolidated list of every persisted model, generated from the per-model docs, plus the conventions, relationships, dedup keys and CloudKit limits that the Swift models must follow. The per-model docs ([task](task), [habit](habit), [anchor](anchor), [rules-engine](../architecture/rules-engine)) hold the rationale; **this page holds the shape**. If they disagree, fix the per-model doc and regenerate this list.

## Why a freeze

CloudKit's production schema is effectively **append-only**. Once deployed you can add models, attributes and relationships, but you cannot rename, remove or retype them. So every name and type below has to be right *before* the first production deploy (TestFlight with CloudKit development schema is the last safe moment to change). New raw-string values and additive fields are always safe; renames are not.

## Conventions

- **Every attribute has a default or is optional.** No bare `let` without one.
- **No unique constraints** (`@Attribute(.unique)` is forbidden under CloudKit). Uniqueness is enforced by the engine — see [Dedup keys](#dedup-keys).
- **Every relationship is optional and has an inverse.**
- **Enums are raw `String`s**, wrapped by typed enums in Swift. New cases can be added later without a schema change; see [Raw values](#raw-values).
- **Dates come in two kinds.**
  - *Floating calendar dates* — stored as a `Date` at 12:00 UTC of the calendar date so every device agrees whatever its time zone (see [The day boundary](../architecture/rules-engine#the-day-boundary)): `Task.dueDate`, `DeferralRecord.day`, `DeferralRecord.deferredTo`, `WorkSession.day`, `HabitEntry.date`, `Anchor.occurrenceDate`, `DayPlan.date`, `NightPlanningSession.forDate`.
  - *Instants* — real moments: every `…At` field, `Anchor.windowStart` / `windowEnd`, `WorkSession.startedAt` / `endedAt`, `DeferralRecord.deferredOn`.
  - Times of day are **minutes since local midnight** (`startMinute`, `reminderMinute`, `dayStartMinute` …).
- **JSON-in-a-string fields** (CloudKit-safe, no extra models): `AnchorRule.configData` (versioned; unknown newer versions must be left untouched, never deleted) and `Habit.pausesData`. Dates inside them are ISO `yyyy-MM-dd` strings and times `"HH:mm"`.
- **Soft delete, not hard delete**, wherever history matters: `Task.droppedAt`, and `isArchived` on `TaskCategory`, `Habit`, `HabitGroup` and `AnchorRule`.
- **Derived values are never stored** unless noted (elapsed time, density, urgency, Eisenhower quadrant, window state, load state, streak-like numbers — there are none).
- **Local-only state** (not in the schema): appearance preferences, the per-device "Send reminders on this device" switch, whether a habit group is expanded, the engine's "last processed day". (The planning and morning times are **synced** in `UserSettings`.)

## Field manifest

Format: `name: Type = default`. Relationship attributes are listed here where the docs show them; the full relationship list follows.

**`Task`**

```
id: UUID = UUID()
title: String = ""
notes: String? = nil
dueDate: Date? = nil
effortMinutes: Int? = nil
importance: String = "low"
isCompleted: Bool = false
completedAt: Date? = nil
droppedAt: Date? = nil
deferralCount: Int = 0
repeatKind: String = "none"
repeatWeekdays: String = ""
seriesID: UUID? = nil
createdAt: Date = .now
```

**`TaskCategory`**

```
id: UUID = UUID()
name: String = ""
presetKey: String? = nil
colorKey: String = "accent"
sortOrder: Int = 0
isArchived: Bool = false
createdAt: Date = .now
```

**`DeferralRecord`**

```
id: UUID = UUID()
deferredOn: Date = .now
day: Date = .now
deferredTo: Date? = nil
reason: String = "unspecified"
task: Task? = nil
```

**`WorkSession`**

```
id: UUID = UUID()
startedAt: Date = .now
day: Date = .now
endedAt: Date? = nil
pausedSeconds: Int = 0
pausedAt: Date? = nil
estimateMinutes: Int? = nil
outcome: String = "running"
actualSeconds: Int = 0
task: Task? = nil
habitWindow: HabitTimeWindow? = nil
```

**`Habit`**

```
id: UUID = UUID()
title: String = ""
notes: String? = nil
presetKey: String? = nil
kind: String = "binary"
frequency: String = "daily"
scheduledDays: String = "1,2,3,4,5,6,7"
targetPerWeek: Int = 0
pausesData: String = "[]"
isArchived: Bool = false
createdAt: Date = .now
```

**`HabitTimeWindow`**

```
id: UUID = UUID()
label: String = ""
startMinute: Int = 0
endMinute: Int = 1439
target: Int = 1
effortMinutes: Int? = nil
reminderMinute: Int? = nil
```

**`HabitEntry`**

```
id: UUID = UUID()
date: Date = .now
target: Int = 1
amount: Int = 0
completedAt: Date? = nil
window: HabitTimeWindow? = nil
```

**`HabitGroup`**

```
id: UUID = UUID()
title: String = ""
sortOrder: Int = 0
isArchived: Bool = false
createdAt: Date = .now
```

**`Anchor`**

```
id: UUID = UUID()
title: String = ""
occurrenceDate: Date = .now
slotKey: String = ""
windowStart: Date = .now
windowEnd: Date = .now
effortMinutes: Int? = nil
attendanceStatus: String = "pending"
resolvedAt: Date? = nil
remindBeforeStartMinutes: Int? = nil
remindBeforeEndMinutes: Int? = nil
generatedAt: Date = .now
```

**`AnchorRule`**

```
id: UUID = UUID()
title: String = ""
sourceKey: String = "custom"
configData: String = "{}"
effortMinutes: Int? = nil
placement: String = "fixed"
isEnabled: Bool = true
isArchived: Bool = false
createdAt: Date = .now
```

**`DayPlan`**

```
id: UUID = UUID()
date: Date = .now
capacity: String = "medium"
plannedTaskMinutes: Int = 0
freeMinutes: Int = 0
committedMinutes: Int = 0
completedEffortMinutes: Int = 0
loadScore: Int = 0
wasOverloaded: Bool = false
completionRate: Double = 0
planningCompletedAt: Date? = nil
```

**`NightPlanningSession`**

```
id: UUID = UUID()
forDate: Date = .now
currentStep: String = "review"
isComplete: Bool = false
skippedAt: Date? = nil
createdAt: Date = .now
completedAt: Date? = nil
```

**`NudgeLog`**

```
id: UUID = UUID()
kind: String = ""
subjectKey: String? = nil
sentAt: Date = .now
dismissedAt: Date? = nil
```

**`UserSettings`**

```
id: UUID = UUID()
mediumDayMinutes: Int = 180
dayStartMinute: Int = 480
dayEndMinute: Int = 1140
rolloverMinute: Int = 0
weekdayLevels: String = "{\"6\":\"low\",\"7\":\"low\"}"
planningMinute: Int = 1200
morningMinute: Int = 480
onboardingCompletedAt: Date? = nil
firstLaunchAt: Date? = nil
createdAt: Date = .now
```

## Relationships

| From | To | Inverse | Delete rule |
| ---- | -- | ------- | ----------- |
| `Task.category` | `TaskCategory?` | `TaskCategory.tasks` | nullify (categories are archived, not deleted) |
| `Task.deferrals` | `[DeferralRecord]?` | `DeferralRecord.task` | cascade |
| `Task.sessions` | `[WorkSession]?` | `WorkSession.task` | cascade |
| `Habit.windows` | `[HabitTimeWindow]?` | `HabitTimeWindow.habit` | cascade |
| `Habit.group` | `HabitGroup?` | `HabitGroup.habits` | nullify (archiving a group never deletes its habits) |
| `HabitTimeWindow.entries` | `[HabitEntry]?` | `HabitEntry.window` | cascade |
| `HabitTimeWindow.sessions` | `[WorkSession]?` | `WorkSession.habitWindow` | cascade |
| `AnchorRule.anchors` | `[Anchor]?` | `Anchor.rule` | nullify (rules are archived, never hard-deleted) |

`WorkSession` has exactly one of `task` / `habitWindow` set (engine-enforced). `Anchor.rule == nil` means a one-off, which is why a rule is never hard-deleted. `DayPlan`, `NightPlanningSession`, `NudgeLog` and `UserSettings` have no relationships.

## Dedup keys

CloudKit can't enforce uniqueness, and two devices can each create the same thing, so the engine deduplicates. Each rule must be safe to apply repeatedly and in any order.

| Model | Key | When duplicates exist |
| ----- | --- | --------------------- |
| `UserSettings` | single row | keep the earliest `createdAt`; delete the rest |
| `TaskCategory` | `presetKey` (seeded defaults), else the **normalised name** (trimmed, case-folded) | keep the earliest; move tasks onto it. A category has no settings of its own, so merging identical labels loses nothing |
| `Task` | `(seriesID, dueDate)` for a repeating task's next instance | keep the earliest `createdAt` |
| `DeferralRecord` | `(task, day)` | one per task per day; keep the earliest and refine its reason / `deferredTo` to the latest choice |
| `WorkSession` | at most one live (`endedAt == nil`) | the earliest `startedAt` stays live; the other closes as `abandoned` with its time logged |
| `HabitEntry` | `(window, date)` | keep one; `amount` = the larger (see [limits](#known-cloudkit-limits)) |
| `Anchor` | `(rule, occurrenceDate, slotKey)` for generated instances | keep the earliest; never resurrect a `skipped` one. One-offs have no key |
| `DayPlan` | `date` | keep the one with `planningCompletedAt`, else the most recent |
| `NightPlanningSession` | `forDate` | prefer `isComplete`, then the furthest `currentStep`, then the latest `createdAt` |
| `NudgeLog` | none | "max one per day" checks read every row, so duplicates are harmless |
| `Habit`, `HabitTimeWindow`, `HabitGroup`, `AnchorRule` | none | user-created; two real duplicates are the user's to merge |

## Raw values

**Reading an unknown value.** An older app may read a raw value a newer app wrote. Every raw-string read falls back to an inert `unknown` case: the row is **kept and never rewritten or deleted**, shown neutrally or hidden, excluded from counts and the wellbeing score, and the older app shows a quiet *"Update Jamaal to see this"* where a row can't be displayed.

| Field | Values |
| ----- | ------ |
| `Task.importance` | `low` (default) / `medium` / `high` |
| `Task.repeatKind` | `none` / `daily` / `weekly` / `monthly` |
| `DeferralRecord.reason` | `tooMuch` / `notReady` / `noLonger` / `reschedule` / `unspecified` |
| `WorkSession.outcome` | `running` / `finished` / `deferred` / `dropped` / `abandoned` / `autoClosed` / `manual` |
| `TaskCategory.presetKey` | `personal` / `family` / `work` (seeded); `colorKey`: `accent` / `blue` / `ochre` / `plum` / `slate` |
| `Habit.kind` | `binary` / `counted` / `timed` / `avoid` |
| `Habit.frequency` | `daily` / `weekdays` / `custom` |
| `Habit.presetKey` | `quran` / `dhikr` / `exercise` / `running` (more as presets are defined) |
| `Anchor.attendanceStatus` | `pending` / `attended` / `missed` / `skipped` / `delegated` |
| `AnchorRule.sourceKey` | `prayerWindow` / `schoolRun` / `binNight` / `plantWatering` / `custom` |
| `AnchorRule.placement` | `fixed` / `flexible` |
| `DayPlan.capacity` | `low` / `medium` / `high` |
| `NightPlanningSession.currentStep` | `review` / `carry` / `build` / `load` / `close` |
| `NudgeLog.kind` | `wellbeing` / `guidance` / `fatigue` / `windowClosing` / `overload` / `morningPlanCard` / `habitPromotion` / `normalDaySuggestion` |
| `UserSettings.weekdayLevels` keys | ISO weekday `"1"`…`"7"` → `low` / `medium` / `high` |
| `Habit.pausesData` reasons | `travel` / `illness` / `cycle` / `other` |
| Anchor exception reasons (in `configData`) | `term` / `holiday` / `travel` / `illness` / `other` |

## Known CloudKit limits

- **Last writer wins per record.** If two devices edit the same record at once, one edit is lost. Usually harmless, but counters such as `HabitEntry.amount` can lose a concurrent increment (two taps on two devices). Accepted for v1; the alternative — an append-only event log per tap — is heavier than a single-user app needs, and can be added later as an additive model.
- **No uniqueness, no transactions across records.** The dedup keys above are the substitute; the rollover and generation steps are written to be idempotent for the same reason.
- **Schema is append-only in production** (see above). Adding fields and models later is fine; renames and removals are not.
- **Plan migrations from day one** with versioned schemas (`VersionedSchema` / a migration plan), even while the first version is the only one.

## Additive later (deliberately not in the schema yet)

Safe to add without breaking anything, so they are *not* blockers: `Task.sortOrder` (manual ordering, open), `AnchorRule.sortOrder`, a per-tap event log for habit counters, `ThreadsKit`-dependent colour keys for categories, and the detected-habit offer's supporting data (v1.1).

## Freeze checklist

- [x] 14 models listed, every attribute has a default or is optional
- [x] No unique constraints; every relationship optional with an inverse and a delete rule
- [x] Misleading names corrected: `Task.priority` → `importance`, `targetCount` → `target`, `completedCount` → `amount`
- [x] Day fields added where the dedup key needs a stable day (`DeferralRecord.day`, `WorkSession.day`)
- [x] `AnchorRule.isArchived` so a rule is never hard-deleted; unused `HabitEntry.skippedReason` removed; `HabitGroup.isExpanded` made local
- [x] Every model that two devices can create twice has a dedup key
- [x] Dates classified as floating or instant
- [x] Learning decision made (suggest only), so `UserSettings.weekdayLevels` is in the schema
- [x] Journey 4 (Anchors) added `Anchor.resolvedAt`, `remindBeforeStartMinutes` and `remindBeforeEndMinutes`
- [x] Journey 1 (first launch) added `UserSettings.planningMinute`, `morningMinute` and `onboardingCompletedAt`
- [x] `TaskCategory.colorKey` values decided (`accent` / `blue` / `ochre` / `plum` / `slate`); the tokens ship in ThreadsKit 1.2.0
- [x] `HabitGroup.emoji` removed before the freeze (Design draws no emoji anywhere); nothing was in production
- [ ] Habit preset definitions (`presetKey` is a string, so can follow)
- [ ] Review by the owner, then implement the models in `JamaalCore` with tests first
