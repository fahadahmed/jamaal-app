# ThreadsKit usage

ThreadsKit ([fahadahmed/threads-kit](https://github.com/fahadahmed/threads-kit)) is the shared design-token package for Jamaal, Riqa and Hashiya. Jamaal consumes it as a remote Swift Package ("Up to Next Major Version"), product `ThreadsTokens`, **from 2.0.0** — the release that built the Claude Design v4 handoff: a palette contract, the category colours, space, elevation, motion, and the bundled fonts with the six type roles. (1.x used `Color.Threads.<name>`; that API is gone — see the ThreadsKit README's migration table.) ThreadsKit's own floor is iOS 18 / macOS 15; Jamaal's minimum OS is **iOS 26 / macOS 26** (a package may be lower than the app).

ThreadsKit is **tokens only**. `ThreadsUI` (components) is deliberately not started — it begins only once a real Jamaal screen has shipped on tokens alone. Every Jamaal component is therefore built in `Jamaal/Components/`, not sourced from ThreadsKit.

> Source of truth is the ThreadsKit repo and its README. If this doc and the package disagree, the package wins — update this doc.

## In the app

- **At launch:** `ThreadsFonts.registerAll()` (in `JamaalApp.init`) registers Fraunces, Hanken Grotesk and JetBrains Mono; it returns any failures and is idempotent.
- **Colours:** `@Environment(\.threads)` gives the palette (`JamaalPalette`, set at the root). Views never use a raw hex, `.opacity()` on a token, or a literal point value.
- **Type:** `.threadsType(.body)` and the other roles; the timer numeral is `ThreadsNumeral`, because Fraunces has no tabular figures.
- **Elevation and motion:** `.threadsElevation(.lift | .float | .hair, in: shape)`, `.threadsAnimation(.state | .surface, value:)` (Reduce Motion aware).

## The palette

A palette is a **conformance, not a copy**: `ThreadsPalette` declares all 21 names plus four status roles, so a missing one is a compile error. Names stay separate even where two values match in one appearance (`terra` / `line`, `accent` / `d3` in dark). Light and dark are baked into the asset catalog, so views never branch on colour scheme.

| Name | Role | Light | Dark |
|---|---|---|---|
| `app` | Screen ground | `#EFF4F0` | `#12303F` |
| `card` | Content surface | `#FFFFFF` | `#FFFFFF` @ 5% |
| `deep` | Timer and focus ground | `#0C4767` | `#071B27` |
| `onDeep` | Type on `deep` (same in both) | `#EAF3F6` | `#EAF3F6` |
| `selected` | An opaque selected task row (was `glassOn`) | `#FFFFFF` | `#1D4052` |
| `ink` · `ink2` · `ink3` | Titles · body · labels and meta (4.5:1 floor) | `#0A3A53` · `#14506E` · `#3F6E80` | `#E7F1F4` · `#BCD3DA` · `#8FAAB4` |
| `terra` · `terraPress` | The primary action — **the only filled button colour**; its pressed fill | `#9A4F2E` · `#7E3F24` | `#DDA080` · `#C08868` |
| `accent` · `accentPress` | Done / settled; its pressed fill | `#1F6A58` · `#175245` | `#8FCBB8` · `#74B3A0` |
| `onAccent` | Type on a filled `terra` or `accent` (flips dark in dark mode; never hardcode white) | `#EAF3F6` | `#16242E` |
| `d1` · `d2` · `d3` · `missed` | Habit-grid density and a missed day (not an error) | `#D3E3DB` · `#71A393` · `#0C4767` · `#E3BEAB` | `#2B4A46` · `#4E7D72` · `#8FCBB8` · `#6B4A38` |
| `line` | Hairlines (alpha baked in) | `#0A3A53` @ 14% | `#E7F1F4` @ 14% |
| `glass` | The tint of an action surface (alpha baked in) | `#FFFFFF` @ 62% | `#FFFFFF` @ 9% |
| `alert` · `alertSoft` | Destructive text · its soft fill — never a filled red button | `#A32E22` · `#F2D4CE` | `#F09A90` · `#5A2A22` |
| `success` · `warning` · `lapsed` · `info` | Status roles | `accent` · `terra` · `missed` · `ink2` | |

**Derived, not assets:** `line2` (`ink` at 24%), `glassEdge` (`line` in light, white 16% in dark) and `scrim` (`rgba(4,26,38,.32)` light, `rgba(0,0,0,.45)` dark).

Roles, per the design: `terra` is the action colour and the only filled button; `accent` marks what is settled. Density cells are graphics — never put a numeral in one. A press changes fill, never position and never `.opacity()`. There is **no red anywhere except `alert`**. The status roles are not severity colours: use position, iconography and copy.

### Category colours (Jamaal only)

`JamaalPalette.categories`: `accent` (teal), `blue` `#2F5E9E` / `#9DB9E8`, `ochre` `#836312` / `#D8BA6A`, `plum` `#7B4474` / `#D5A6CC`, `slate` `#52636E` / `#AEBCC6`. The keys are exactly what `TaskCategory.colorKey` stores in JamaalCore (a test in the app checks the two lists agree); `JamaalPalette.categoryColor(forKey:)` falls back to slate for an unknown key. A label is always a dot plus the name in ink. `terra` is excluded: it carries warning and overload.

## Space, radius, hit

`ThreadsSpace`: `gutter` 26 (a minimum, resolved against each edge's own inset) · `section` 22 · `row` 14 · `tight` 10 · `hair` 4; row padding 12×14, chip 9×20, pill button 12×20. `ThreadsRadius`: cell 3 · field 8 · card 14 · pill (a `Capsule`, for every button, chip and checkbox). `ThreadsHit`: 44 pt (28 pt for a Mac pointer); `.threadsHitTarget()`.

## Type

| Role | Face | pt | Scales with | Leading |
|---|---|---|---|---|
| `label` | JetBrains Mono 500, tracked 0.16 em, uppercase (capped at `.xxLarge`) | 12 | `.caption2` | 1.35 |
| `meta` | Hanken Grotesk 400 | 15 | `.subheadline` | 1.35 |
| `body` | Hanken Grotesk 400 | 17 | `.body` | 1.6 |
| `row` | Hanken Grotesk 600 | 18 | `.headline` | 1.35 |
| `lede` | Hanken Grotesk 400 | 19 | `.callout` | 1.6 |
| `display` | Fraunces 500 (SOFT 60, WONK 1) | 28 / 34 / 38 | `.title2` / `.title` / `.largeTitle` | 1.08 |

The fonts are **static instances** (SwiftUI can't set variable axes) under the SIL Open Font License, with the licences shipped in the package; Fraunces is cut at optical size 36. `ThreadsType.displayItalicFontName` is the italic for an emphasised fragment of a display line. **Fraunces has no tabular figures**, so `ThreadsNumeral("12:34")` sets each digit in a cell as wide as the widest digit — that is how the timer numeral stays still.

## What stays custom in Jamaal

Built in `Jamaal/Components/` on top of the tokens above:

- Capacity slider
- Habit group completion ring
- Habit heatmap grid
- Wellbeing sparkline (Swift Charts)
- Capacity meter (8 pt tall pill: budget used; terracotta when overloaded or past the day's end)
- Ambient session chip and focus screen (timer numeral with `ThreadsNumeral`; the chip is filled only while a session is live)
- Window bar (Anchor window states: upcoming / open / closing soon / closed; the design draws it 6 pt tall and pill-shaped)
- Night Planning 5-step wizard (review today → carry forward → build tomorrow → check the load → close the day), including the tomorrow-gaps list and the wide-layout proportional timeline

Navigation chrome (floating pill tab bar, translucent nav circles) uses the iOS 26 Liquid Glass **system** components, tinted with `glass` where a tint is needed. It must be the system tab bar and toolbars, not custom-built ones, so iPad sidebars and iPhone Duo's side-mounted controls adapt automatically (see [app-flow.md](../journeys/app-flow#iphone-duo-foldable-iphone)).

## Decisions and open items

1. **Palette.** The cool palette (teal accent, blue-based ink, terracotta as the one action colour) replaced the warm ceramic one; the HTML mockups in `mockups/legacy/` are layout/flow reference only. The current visual truth is `mockups/screens/` (Design v4).
2. **Heatmap.** Binary habits use `empty` / `missed` / `d3`; counted and timed habits use `empty` / `missed` / `d1` (1–49%) / `d2` (50–99%) / `d3` (complete). Still open: the habit group completion ring and the wellbeing sparkline colours.
3. **Fonts — done.** Bundled in ThreadsKit 2.0.0 (see above). Two judgement calls are recorded in the ThreadsKit PR: Fraunces' optical size is fixed at 36, and the timer numeral uses `ThreadsNumeral`.
4. **A gap in the design.** `ink3` on the **dark** `selected` row is 4.4965:1, 0.0035 short of AA (fine on every other surface). ThreadsKit pins it with a test; raise it with Design.
5. **Dependency wired.** ThreadsKit 2.0.0 is a remote package of `Jamaal.xcodeproj` (Up to Next Major from 2.0.0), with `Package.resolved` committed for reproducible builds; the app's unit tests prove it links, the fonts register, and the category keys agree. The app's minimum (iOS 26 / macOS 26) is above ThreadsKit's own iOS 18 / macOS 15 floor, which is fine. iPhone Duo-specific APIs (`ArrangementView`, `ReservedRegion`) are iOS 27.1 (beta), so they are availability-gated rather than raising the floor.
