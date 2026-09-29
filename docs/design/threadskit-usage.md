# ThreadsKit usage

ThreadsKit ([fahadahmed/threads-kit](https://github.com/fahadahmed/threads-kit)) is the shared design-token package for Jamaal, Riqa and Hashiya. Jamaal consumes version **1.0.0** as a remote Swift Package ("Up to Next Major Version"), product `ThreadsTokens`. Platforms: iOS 18+, macOS 15+.

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
| `onAccent` | Text/icons on `accent` | `#16242E` | `#EAF3F6` |
| `terra` | Secondary accent (terracotta) | `#9A4F2E` | `#DDA080` |
| `deep` | Deepest elevated surface | `#071B27` | `#0C4767` |
| `glassOn` | Tint for glass/blur overlays | `#FFFFFF` | `#1D4052` |
| `line` | Subtle border (alpha baked in) | `#0A3A53` @ 14% | `#E7F1F4` @ 14% |
| `line2` | Stronger border (alpha baked in) | `#0A3A53` @ 24% | `#E7F1F4` @ 24% |

Derived, no asset:

- `focusRing` — alias of `accent`.
- `pressed(_:)` — base colour at 85% opacity, for pressed/hover states.

### Shadow

One elevation value, `.threadsShadow()`, colour-scheme aware. No multi-step scale.

- Light: `0 18px 40px -26px rgba(6,32,46,0.42)`
- Dark: `0 22px 50px -28px rgba(0,0,0,0.7)`

## Not available in ThreadsKit yet

| Area | Status | Consequence for Jamaal |
|---|---|---|
| Typography | Not bundled. The display face needs a static instance (width axis can't be set from SwiftUI) and licences need confirming. | Design with the intended faces, but expect system-font fallbacks in early builds. |
| Spacing / radius scale | Not ported from the web system. | Define values locally and record them here until upstream has them. |
| Status colours (success/warning/error/info) | Absent by design — consistent with a non-punitive tone. | Use position, iconography and copy, not colour severity. Adding any is an explicit decision (see open decisions). |
| Components | `ThreadsUI` not started. | Everything is local to `Jamaal/Components/`. |

## What stays custom in Jamaal

Built in `Jamaal/Components/` on top of the tokens above:

- Capacity slider
- Habit group completion ring
- Habit heatmap grid
- Wellbeing sparkline (Swift Charts)
- Window bar (Anchor window states: upcoming / open / closing soon / closed; the design draws it 6 pt tall and pill-shaped)
- Night Planning 5-step wizard (review & carry forward → reflect → plan → capacity & load check → confirm)

Navigation chrome (floating pill tab bar, translucent nav circles) uses the iOS 26 Liquid Glass **system** components, tinted with `glassOn` where a tint is needed. It must be the system tab bar and toolbars, not custom-built ones, so iPad sidebars and iPhone Duo's side-mounted controls adapt automatically (see [app-flow.md](../journeys/app-flow#iphone-duo-foldable-iphone)).

## Open decisions

1. **Palette change vs. existing mockups.** ThreadsKit moved from the warm ceramic palette (off-white, charcoal, terracotta, sage) to the cool palette above — a major-version-level change per ThreadsKit's own versioning notes. The existing HTML mockups (`mockups/legacy/`) are all on warm palettes and have little Liquid Glass styling, so they are layout/flow reference only.
2. **No sage — heatmap colours now specified by the design.** Habits are tracked by density, so the density grid is the main habit visual ([habit.md](../schema/habit#density-not-streaks)). The design project defines its colours as four tokens (light / dark): `d1` `#D3E3DB` / `#2B4A46`, `d2` `#71A393` / `#4E7D72`, `d3` `#0C4767` / `#8FCBB8`, `missed` `#E3BEAB` / `#6B4A38`. ThreadsKit 1.0.0 does not have them, so they need adding upstream. Binary habits use `empty` / `missed` / `d3`; counted habits use `empty` / `missed` / `d1` (1–49%) / `d2` (50–99%) / `d3` (complete). Still open: the habit group completion ring and the wellbeing sparkline colours.
   - **Category colours** (see [task.md](../schema/task)): editable categories need a small fixed set of label colours, and the two accents aren't enough. Per ThreadsKit's rule, a new colour is a new asset-catalog token upstream, not an `.opacity()` at the call site.
3. **Fonts.** `CLAUDE.md` names Fraunces + DM Sans. ThreadsKit does not bundle any font yet, and its README does not name the faces. Confirm the faces and licensing upstream.
4. **Dependency not wired yet.** ThreadsKit is not yet added to `Jamaal.xcodeproj`. Check the app's deployment target against ThreadsKit's iOS 18 / macOS 15 minimum when adding it. iPhone Duo-specific APIs (`ArrangementView`, `ReservedRegion`) are iOS 27.1 (beta), so they are availability-gated rather than raising the floor.
