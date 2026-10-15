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
| Avoid habits (`HB-08`) | one treatment, *Slip* and *Held today*, three moments | owner to choose between two | **Owner confirmed Option A on 8 Oct 2026** (the treatment in the `HB-08` frame: *Slip* and *Held today*, both explicit; option B, inferring the hold from the day, is dropped) |
| App icon | monogram 1d, layered SVGs | none | Added at [`assets/icon/`](../../assets/icon) for Icon Composer |

## Still to do from the handoff

- ~~**ThreadsKit**~~ **Done in 2.0.0** (palette protocol, categories, space, elevation, motion, fonts and the type roles; the app depends on it). The handoff specified a `ThreadsTokens` target (a palette protocol with 21 names, six type roles, space, elevation, motion) with fonts bundled as package resources. That renames and extends the 1.1.0 tokens, so it is a **major version**; the app's dependency needs a bump when it ships.
- **Draw `TD-04`** (the Add button's *Task | Anchor* entry).
- Assemble the icon in Icon Composer (default, dark, clear, tinted) and place the mark in the other spots the handoff lists.

## Batches 8 and 9

The widgets (batch 8) and Apple Watch (batch 9) frames came later and are reconciled in [widgets and watch reconciliation](widgets-and-watch-reconciliation).

## Tab and sidebar icons (#247)

The frames draw their own icons as inline SVG on a 24 pt grid (1.75 stroke, round caps and joins), not SF Symbols: **Today** three left-aligned lines (16, 16 and 10 wide), **Habits** four outlined rounded squares, **Anchors** a clock, **Wellbeing** a pulse line, **Settings** three sliders. The app drew the nearest SF Symbols, which are heavier, and which the system swaps for their solid variant when selected (Habits became four filled squares). The drawings are now template vector assets (`TabToday`, `TabHabits`, `TabAnchors`, `TabWellbeing`, `TabSettings` in `Assets.xcassets`, from the design's own paths) used by the tab bar and by the iPad and Mac sidebars (`AppTab.icon`). **Not matched:** the design shows unselected tabs in `ink3` (a muted teal) and the selected one in `ink`; the iOS 26 glass tab bar ignores a custom unselected colour, so unselected icons and labels follow the system colour.

## The Add task form's controls (#253)

The frames draw "How much does this matter?" and the Task | Anchor toggle as full-width pill segments, and Category and Repeat as full-width rows with a chevron. SwiftUI's own segmented picker and `Menu` look the same on an iPhone but become small AppKit controls on a Mac, beside the large Due chips, and a `Menu` with a custom label was not reliably clickable there. The form now uses our own `PillSegment` (`fills: true` gives the three equal segments) for both, and the Category and Repeat menus use the button menu style (`.menuStyle(.button)`, plain button style, no indicator) so the whole row is the control. Other screens still use the system segmented picker (Settings' weekday levels, Appearance, the Anchor and prayer forms, onboarding); change them the same way if they look small on a Mac.

## The selected tab is teal (#263)

The frames draw the selected tab in `ink`. By the owner's decision (15 Oct 2026) it is the accent teal (`#1F6A58` light, `#8FCBB8` dark) instead: the tab view's tint is `accent` (so it also colours the selected iPad sidebar row) and the tab bar appearance sets the chosen item's icon and label to it. Each tab's content keeps the ink tint, so toggles, links and the like are unchanged. Unselected tabs still follow the system colour (see "Tab and sidebar icons").

