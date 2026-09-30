# ThreadsKit usage

ThreadsKit ([fahadahmed/threads-kit](https://github.com/fahadahmed/threads-kit)) is the shared design-token package for Jamaal, Riqa and Hashiya. Jamaal consumes ThreadsKit as a remote Swift Package ("Up to Next Major Version"), product `ThreadsTokens`, **from 1.1.0** — the first version with the corrected `onAccent`/`deep` values (1.0.1) and the density, pressed, glass and destructive tokens (1.1.0). Do not depend on 1.0.0: its `onAccent` fails contrast. ThreadsKit's own floor is iOS 18 / macOS 15; Jamaal's minimum OS is **iOS 26 / macOS 26** (a package may be lower than the app).

ThreadsKit is **tokens only** today. `ThreadsUI` (components) is deliberately not started — it begins only once a real Jamaal screen has shipped on tokens alone. Every Jamaal component is therefore built in `Jamaal/Components/`, not sourced from ThreadsKit.

> Source of truth is the ThreadsKit repo. If this doc and the package disagree, the package wins — update this doc.

## Colour tokens

Accessed as `Color.Threads.<name>`. Each token has light and dark appearances baked into an asset catalog, so views never branch on colour scheme and never use raw hex.

| Token | Role | Light | Dark |
|---|---|---|---|
| `app` | Page / window background | `#EFF4F0` | `#12303F` |
| `card` | Card, panel, sheet surface | `#FFFFFF` | `#FFFFFF` @ 5% |
| `ink` | Primary text and icons | `#0A3A53` | `#E7F1F4` |
| `ink2` | Secondary text | `#14506E` | `#BCD3DA` |
| `ink3` | Tertiary / muted text | `#3F6E80` | `#8FAAB4` |
| `accent` | Primary accent (teal) | `#1F6A58` | `#8FCBB8` |
| `onAccent` | Text/icons on `accent` (and on `terra` / the pressed fills) | `#EAF3F6` | `#16242E` |
| `terra` | Secondary accent (terracotta) | `#9A4F2E` | `#DDA080` |
| `deep` | Deepest elevated surface | `#0C4767` | `#071B27` |
| `glassOn` | Opaque fill for selected rows and glass surfaces (the design calls this `selected`) | `#FFFFFF` | `#1D4052` |
| `line` | Subtle border (alpha baked in) | `#0A3A53` @ 14% | `#E7F1F4` @ 14% |
| `line2` | Stronger border (alpha baked in) | `#0A3A53` @ 24% | `#E7F1F4` @ 24% |
| `onDeep` | Text/icons on `deep` (same in both appearances) | `#EAF3F6` | `#EAF3F6` |
| `terraPress` | Pressed fill for `terra` | `#7E3F24` | `#C08868` |
| `accentPress` | Pressed fill for `accent` | `#175245` | `#74B3A0` |
| `d1` | Density ramp — light | `#D3E3DB` | `#2B4A46` |
| `d2` | Density ramp — mid | `#71A393` | `#4E7D72` |
| `d3` | Density ramp — full | `#0C4767` | `#8FCBB8` |
| `missed` | A closed / missed density cell | `#E3BEAB` | `#6B4A38` |
| `glass` | Glass material tint (alpha baked in) | `#FFFFFF` @ 62% | `#FFFFFF` @ 9% |
| `alert` | Destructive text and icons | `#A32E22` | `#F09A90` |
| `alertSoft` | Destructive fill — soft fill with `alert` text, never a filled alert button | `#F2D4CE` | `#5A2A22` |

Roles, per the design: `terra` is the action colour and the only filled button; `accent` marks what is settled. Density cells are graphics — never put a numeral in one. A press changes fill (`terraPress` / `accentPress`), never position and never `.opacity()`.

Derived, no asset:

- `focusRing` — alias of `accent`.
- `pressed(_:)` — base colour at 85% opacity, for colours with no dedicated pressed token. Prefer `terraPress` / `accentPress` where they apply.

### Shadow

One elevation value, `.threadsShadow()`, colour-scheme aware. No multi-step scale.

- Light: `0 18px 40px -26px rgba(6,32,46,0.42)`
- Dark: `0 22px 50px -28px rgba(0,0,0,0.7)`

## Not available in ThreadsKit yet

| Area | Status | Consequence for Jamaal |
|---|---|---|
| Typography | Not bundled. The display face needs a static instance (width axis can't be set from SwiftUI) and licences need confirming. | Design with the intended faces, but expect system-font fallbacks in early builds. |
| Spacing / radius scale | Not ported from the web system. | Define values locally and record them here until upstream has them. |
| Status colours (success/warning/info) | Absent by design; only `alert` / `alertSoft` (destructive) exist. Success is `accent`, warning is `terra`, a lapsed item is `missed`, info is plain `ink2`. | Use position, iconography and copy, not colour severity. Adding more is an explicit decision. |
| Components | `ThreadsUI` not started. | Everything is local to `Jamaal/Components/`. |

## What stays custom in Jamaal

Built in `Jamaal/Components/` on top of the tokens above:

- Capacity slider
- Habit group completion ring
- Habit heatmap grid
- Wellbeing sparkline (Swift Charts)
- Capacity meter (8 pt tall pill: budget used; terracotta when overloaded or past the day's end)
- Ambient session chip and focus screen (timer numeral in the display face with monospaced digits; the chip is filled only while a session is live)
- Window bar (Anchor window states: upcoming / open / closing soon / closed; the design draws it 6 pt tall and pill-shaped)
- Night Planning 5-step wizard (review today → carry forward → build tomorrow → check the load → close the day), including the tomorrow-gaps list and the wide-layout proportional timeline

Navigation chrome (floating pill tab bar, translucent nav circles) uses the iOS 26 Liquid Glass **system** components, tinted with `glassOn` where a tint is needed. It must be the system tab bar and toolbars, not custom-built ones, so iPad sidebars and iPhone Duo's side-mounted controls adapt automatically (see [app-flow.md](../journeys/app-flow#iphone-duo-foldable-iphone)).

## Open decisions

1. **Palette change vs. existing mockups.** ThreadsKit moved from the warm ceramic palette (off-white, charcoal, terracotta, sage) to the cool palette above — a major-version-level change per ThreadsKit's own versioning notes. The existing HTML mockups (`mockups/legacy/`) are all on warm palettes and have little Liquid Glass styling, so they are layout/flow reference only.
2. **No sage — heatmap colours now specified by the design.** Habits are tracked by density, so the density grid is the main habit visual ([habit.md](../schema/habit#density-not-streaks)). The design project defines its colours as four tokens (light / dark): `d1` `#D3E3DB` / `#2B4A46`, `d2` `#71A393` / `#4E7D72`, `d3` `#0C4767` / `#8FCBB8`, `missed` `#E3BEAB` / `#6B4A38`. They shipped in ThreadsKit 1.1.0 as `Color.Threads.d1`, `d2`, `d3` and `missed`. Binary habits use `empty` / `missed` / `d3`; counted habits use `empty` / `missed` / `d1` (1–49%) / `d2` (50–99%) / `d3` (complete). Still open: the habit group completion ring and the wellbeing sparkline colours.
   - **Category colours — decided** (see [task.md](../schema/task#taskcategory)): five label colours, `accent` (teal, existing) plus four **new ThreadsKit 1.2.0 tokens** `blue`, `ochre`, `plum`, `slate`, each with a light/dark pair contrast-tested on the surface; `terra` is excluded because it carries warning and overload. A label is a dot plus the name in ink. The **hues are still to be confirmed against the Claude Design tokens** before they are cut; until then the app uses placeholders. Per ThreadsKit's rule, a new colour is a token upstream, not an `.opacity()` at the call site.
3. **Fonts.** The Claude Design project draws **Fraunces** (display, SOFT 60 / WONK 1), **Hanken Grotesk** (text) and **JetBrains Mono** (labels), and styling follows Design, so these are the intended faces (`CLAUDE.md`'s earlier "DM Sans" is superseded). ThreadsKit does not bundle any font yet: Fraunces needs a static instance (its width axis can't be set from SwiftUI) and licences for all three must be confirmed before they ship in the binary.
4. **Dependency wired.** ThreadsKit 1.1.0 is a remote package of `Jamaal.xcodeproj` (Up to Next Major from 1.1.0), with `Package.resolved` committed for reproducible builds; a smoke test proves it links. The app's minimum (iOS 26 / macOS 26) is above ThreadsKit's own iOS 18 / macOS 15 floor, which is fine. iPhone Duo-specific APIs (`ArrangementView`, `ReservedRegion`) are iOS 27.1 (beta), so they are availability-gated rather than raising the floor.
