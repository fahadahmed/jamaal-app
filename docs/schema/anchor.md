# Anchor

> **Status: reviewed, resolved for v1.** Fields below reflect decisions made in review. See "Open questions" for what's still unsettled (mainly `AnchorRule`'s schedule representation, and ADR 0001 itself, which is still an empty stub).

Something the user's life **moves around**. **Generated** (not user-created directly), tracked via attendance rather than streaks. Timing and the consequence of a miss are external to the user. Examples: prayer windows (including salah — see [habit.md](habit) for why salah lives here and not as a Habit), school runs, bin night, watering plants.

Full rationale for Anchor as a third primitive (vs. folding into Habit) is meant to live in [ADR 0001](../architecture/decisions/0001-anchor-object-type) — that file is currently an empty stub and needs to be filled in.

## Fields

| Field             | Type       | Default    | Notes                                                                                     |
| ----------------- | ---------- | ---------- | -------------------------------------------------------------------------------------------- |
| `id`              | `UUID`     | `UUID()`   |                                                                                                |
| `title`           | `String`   | `""`       | e.g. "Fajr", "School run — pickup", "Bin night".                                              |
| `windowStart`     | `Date`     | `.now`     | Start of the external window this instance is anchored to.                                   |
| `windowEnd`       | `Date`     | `.now`     | End of the window; after this, a miss is final for this instance.                            |
| `attendanceStatus`| `String`   | `"pending"`| One of `pending` / `attended` / `missed`. Sufficient on its own for v1 — no separate "consequence" field; any messaging about what a miss means is UI/copy, not data (confirmed in review). |
| `generatedAt`     | `Date`     | `.now`     |                                                                                                |

## Relationships

- `rule: AnchorRule?` (optional, per CloudKit relationship constraint) — the rule that generated this instance.

### `AnchorRule`

Anchor instances are generated from a persisted `AnchorRule` (confirmed in review — not computed purely on the fly by the rules engine, so custom user-defined anchors like plant watering are possible without code changes).

| Field         | Type      | Default    | Notes                                                                                          |
| ------------- | --------- | ---------- | -------------------------------------------------------------------------------------------------- |
| `id`          | `UUID`    | `UUID()`   |                                                                                                      |
| `title`       | `String`  | `""`       |                                                                                                      |
| `sourceKey`   | `String`  | `"custom"` | One of `prayerWindow` / `schoolRun` / `binNight` / `plantWatering` / `custom`.                       |
| `configData`  | `String`  | `"{}"`     | JSON-encoded, shape depends on `sourceKey` (e.g. prayer calculation method + location for `prayerWindow`; weekday + time for `schoolRun`; interval in days for `plantWatering`). Placeholder pending the rules-engine design pass ([issue #7](https://github.com/fahadahmed/jamaal-app/issues/7)). |
| `isEnabled`   | `Bool`    | `true`     |                                                                                                      |
| `createdAt`   | `Date`    | `.now`     |                                                                                                      |

## CloudKit constraints applied

- All properties have defaults.
- No unique constraints.
- The `rule` relationship is optional.

## Open questions

- **`AnchorRule.configData` shape**: a JSON blob is a pragmatic placeholder, not a final design — each `sourceKey` needs its own decoded shape, to be defined alongside the rules-engine module boundaries ([issue #7](https://github.com/fahadahmed/jamaal-app/issues/7)).
- **ADR 0001 is still empty**: this doc references it for "why Anchor is a third primitive" but there's no content there yet to point to — worth filling in now that the Habit/Anchor boundary is actually resolved.
- **Sharing/referral**: same note as Task/Habit — deliberately left out of this draft, pending [issue #8](https://github.com/fahadahmed/jamaal-app/issues/8).
