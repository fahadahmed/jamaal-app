# Design v4 reconciliation

> **Status: applied.** The Claude Design v4 handoff ([README](README), the 110 frames and editable HTML in [`mockups/screens/`](../../mockups/screens/README)) was checked against the repo docs. **On visuals, `mockups/screens/` wins; on behaviour and data, `docs/journeys/` wins.** Where they disagreed, this page records which way each went.

## What the check covered

- **Coverage:** every frame is named by a register ID, and none is unknown to the register. Eight register screens have no v4 frame: `HB-04`, `HB-05`, `OB-01`, `SY-01`, `SY-04`, `TD-02` (all drawn earlier in v3 and unchanged), `TD-04` (the *Task | Anchor* entry on the Add button, still to draw) and `WB-04` (v1.1). The register's *Design* column now says **Drawn v4** with a frame count wherever frames exist.
- **Forbidden content:** the editable sources contain no emoji, no exclamation marks, and no streak, best or mood content except in annotations saying it is absent. Spot checks of `TD-01` and `HB-08` match the locked behaviour (density grids, a *Slip* and *Held today* pair, category labels as dot plus name, no streak row).

## Decisions

| Topic | Design v4 | Repo before | Resolved |
|---|---|---|---|
| Habit-group emoji | none anywhere | `HabitGroup.emoji` in the schema | **Field removed** before the freeze; docs updated |
| Category colours | final hexes, `catTeal/Blue/Ochre/Plum/Slate` (ochre `#836312`, changed to pass contrast on the iPad sidebar) | keys `accent/blue/ochre/plum/slate`, hues unconfirmed | Keys unchanged; **hexes adopted** ([task.md](../schema/task#taskcategory)) |
| iPad layout | sidebar, list (440 pt), detail | two panels, list ≈340 pt | **v4 wins** (brief and [app-flow](../journeys/app-flow#adaptive-layout-ipad-and-mac) updated) |
| Navigation | Anchors is its own sidebar item on iPad and Mac; on Mac, Settings moves to the app menu | Anchors only as a segment of Habits | **v4 wins** |
| Night Planning on wide | one canvas with a step rail | app-flow said a centred modal | **Step rail** (matches register and brief) |
| Paywall prices | placeholders $29.99/yr and $3.99/mo | $24.99/yr and $2.99/mo | Product prices unchanged; the UI shows StoreKit's `displayPrice` |
| Avoid habits (`HB-08`) | one treatment, *Slip* and *Held today*, three moments | owner to choose between two | Treated as the **chosen treatment** unless the owner says otherwise |
| App icon | monogram 1d, layered SVGs | none | Added at [`assets/icon/`](../../assets/icon) for Icon Composer |

## Still to do from the handoff

- **ThreadsKit** — the handoff specifies a `ThreadsTokens` target (a palette protocol with 21 names, six type roles, space, elevation, motion) with fonts bundled as package resources. That renames and extends the 1.1.0 tokens, so it is a **major version**; the app's dependency needs a bump when it ships.
- **Draw `TD-04`** (the Add button's *Task | Anchor* entry).
- Assemble the icon in Icon Composer (default, dark, clear, tinted) and place the mark in the other spots the handoff lists.
