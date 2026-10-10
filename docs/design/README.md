# Handoff: ThreadsKit (Swift package) + Jamaal v4 screens

## Overview
ThreadsKit is the shared SwiftUI design-token package for fhdamd's apps. Jamaal is the first and only product palette. This bundle has:
1. the **token contract** to build as the `ThreadsTokens` target, with `Palettes/Jamaal.swift` and `Colors-Jamaal.xcassets`;
2. **Jamaal v4 screens**: nine batches covering iPhone, iPad, iPhone Duo, macOS, Live Activity, widgets and the Apple Watch (batches 8 and 9 came later: see [widgets and watch reconciliation](widgets-and-watch-reconciliation)). They are named by register ID (TD-, TM-, HB-, AN-, NP-, WB-, ST-, OB-, PW-, DUO-, LA-…) and match `docs/journeys/screens.md` in the `jamaal-app` repo;
3. the **app icon** (chosen: monogram 1d) as three layer SVGs for Icon Composer.

The first task is the package. The screens are for reference when building views after that.

## About the design files
The `.dc.html` files are **design references built in HTML**. They are not production code. Open them in a browser (keep `support.js` next to them). Each file has a light/dark toggle at top right. Rebuild everything in **SwiftUI** in the existing `jamaal-app` Xcode project and `JamaalCore` package, following that codebase's patterns. Don't port the HTML or CSS.

## Fidelity
**High fidelity.** Colours, type, spacing, radii and copy are final. Point sizes are iOS points: 1 CSS px in the frames equals 1 pt. Frame sizes are: iPhone 393×852, iPad 11″ landscape 1194×834, Mac 1280×800. **iPhone Duo** frame sizes are estimates. Take the real point sizes from Apple's design resources and trust the layout rules below over the drawn pixels.

---

## 1. Package shape
```
ThreadsKit/
└── Sources/
    ├── ThreadsTokens/               // shared contract — no colour values
    │   ├── ThreadsType.swift        // 6 roles, leading + text style bound in
    │   ├── ThreadsSpace.swift       // named steps + 4 radii + hit
    │   ├── ThreadsElevation.swift   // lift / float / hair × appearance
    │   ├── ThreadsMotion.swift      // 2 durations, 1 curve
    │   ├── ThreadsPalette.swift     // protocol: 21 names + 4 status roles
    │   └── Palettes/
    │       └── Jamaal.swift         // the only conformance that exists
    └── Resources/
        └── Colors-Jamaal.xcassets   // light + dark pairs, one colour set per name
```
- A palette is a **conformance, not a copy**. `ThreadsPalette` is a protocol declaring every name, so a product that leaves out a name gets a compile error.
- Status roles (`success`, `warning`, `lapsed`, `info`) are computed properties with defaults. Jamaal maps them to `accent`, `terra`, `missed` and `ink2`.
- **Category colours** are Jamaal-only and user-assigned, so they're a separate `categories` array in `Jamaal.swift`, outside the 21 names.
- Don't write Riqa or Hashiya palettes yet.
- Views never use raw hex, literal points or literal durations. Everything goes through tokens.

## 2. Colour: 21 names (light / dark)
| Name | Light | Dark | Use |
|---|---|---|---|
| app | #EFF4F0 | #12303F | screen ground |
| card | #FFFFFF | white α0.05 | content surface |
| deep | #0C4767 | #071B27 | timer / focus ground |
| onDeep | #EAF3F6 | #EAF3F6 (fixed) | type on deep |
| ink | #0A3A53 | #E7F1F4 | titles |
| ink2 | #14506E | #BCD3DA | body |
| ink3 | #3F6E80 | #8FAAB4 | labels, meta (4.5:1 floor) |
| terra | #9A4F2E | #DDA080 | primary action. **Only filled button colour** |
| terraPress | #7E3F24 | #C08868 | pressed terra |
| accent | #1F6A58 | #8FCBB8 | done / settled |
| accentPress | #175245 | #74B3A0 | pressed accent |
| onAccent | #EAF3F6 | #16242E | type on filled terra/accent. **Flips dark in dark mode; never hardcode white** |
| d1 | #D3E3DB | #2B4A46 | density step 1 |
| d2 | #71A393 | #4E7D72 | density step 2 |
| d3 | #0C4767 | #8FCBB8 | density step 3 |
| missed | #E3BEAB | #6B4A38 | missed day (not an error) |
| line | #0A3A53 α0.14 | #E7F1F4 α0.14 | hairlines; ship **with alpha** |
| glass | white α0.62 | white α0.09 | action-surface tint (measured) |
| selected | #FFFFFF | #1D4052 | opaque selected task row (content layer) |
| alert | #A32E22 | #F09A90 | destructive **text** |
| alertSoft | #F2D4CE | #5A2A22 | destructive soft fill |

Frames also use these values, which are derived rather than named: `line2` = ink α0.24 (strong border), `glassEdge` = `line` in light and white α0.16 in dark, `scrim` = rgba(4,26,38,0.32) in light and rgba(0,0,0,0.45) in dark.

**Categories (Jamaal only, final):**
| Name | Light | Dark | Contrast on app (light / dark) |
|---|---|---|---|
| catTeal (= accent) | #1F6A58 | #8FCBB8 | 5.8 / 7.5 |
| catBlue | #2F5E9E | #9DB9E8 | 5.9 / 6.9 |
| catOchre | #836312 | #D8BA6A | 5.0 / 7.3 |
| catPlum | #7B4474 | #D5A6CC | 6.5 / 6.7 |
| catSlate | #52636E | #AEBCC6 | 5.6 / 7.1 |
All pass 4.5:1 as text on app, card and the iPad sidebar (#E4ECE7). Ochre changed from #8C6A14, which failed on the sidebar.

Rules:
- There is **no red anywhere** except `alert`. Destructive actions are a **soft fill (`alertSoft`) with `alert` text**, never a filled red button.
- Keep names separate even where their hex values match in dark (terra/rule, accent/d3).

## 3. Type: six roles (Dynamic Type)
Families: **Hanken Grotesk** (UI and body), **Fraunces** (display; opsz auto, SOFT 60, WONK 1), **JetBrains Mono** (labels). Bundle them as package resources and register them at launch.
| Role | Font | pt | relativeTo | Leading | Use |
|---|---|---|---|---|---|
| label | JetBrains Mono 500, tracking 0.16em, UPPERCASE | 12 | .caption2 | 1.35 | eyebrows, chip labels, times |
| meta | Hanken 400 | 15 | .subheadline | 1.35 | row secondary line |
| body | Hanken 400 | 17 | .body | 1.6 | all prose |
| row | Hanken 600 | 18 | .headline | 1.35 | task / habit title |
| lede | Hanken 400 | 19 | .callout | 1.6 | sheet intros, empty states |
| display | Fraunces 500 | 28 / 34 / 38 | .title2 / .title / .largeTitle | 1.08 | screen titles, timer numeral |
- Leading is part of each role and isn't exposed to callers.
- The timer numeral uses `display` with **monospaced digits**. It's the only place that needs them.
- Every role scales up to the largest accessibility size except `label`, which caps at `.xxLarge`.
- The iOS status bar in the frames is mockup furniture, not an app type role.
- Mac density: 32–40 pt rows, 15 pt body, same tokens.

## 4. Space, radius, hit
- Named steps: `.gutter 26` · `.section 22` · `.row 14` (the workhorse gap) · `.tight 10` · `.hair 4`. Row padding is 12×14. Chip padding is 9×20, or 12×20 for PillButton.
- The **gutter is a minimum**: resolve each edge against its own safe-area or layout-margin inset. Duo insets are asymmetric.
- Radii: `3` density cell · `8` field / inline block · `14` card, selected row, sheet · `pill` (capsule) for every button, chip and checkbox. The 30–48 px radii in the frames are device bezels and must not go in the package.
- `.hit = 44`. Visual marks stay 20–22 pt and get a 44 pt `contentShape`. On Mac the pointer target is 28 pt.

## 5. Elevation, glass, motion, haptics
- `lift` (light): y18 blur40 spread−26, rgba(6,32,46,0.42). `float` (light): y10 blur26 spread−14, rgba(6,32,46,0.50). `hair`: 0 1 0 in `line`.
- Dark: rgba(0,0,0,0.70) at y22 blur50 spread−28 for both.
- SwiftUI's `.shadow` can't do a negative spread, so shadow an inset shape behind the view. Wrap it once as a modifier.
- **Liquid Glass on action surfaces only**: tab bar, toolbars, sidebar, capture bar, timer chip, secondary PillButtons and the Duo side column. Content (rows, cards, sheets' bodies) is opaque. Use the **system** iOS 26 glass components, tinted with `glass`. Measured reference blur: 20 pt at 140% saturation on bars and chips, 28 pt at 160% on sidebars. The system material supplies the blur.
- Motion: **140 ms** for state change (press, check, chip) and **260 ms** for a surface arriving (sheet, screen). Both use the curve `cubic-bezier(0, 0, 0.2, 1)`. With Reduce Motion both are 0 and sheets cross-fade.
- Haptics: **completion is one soft impact**. Defer and drop are silent. A ritual window closing is a light notification. Nothing buzzes to ask for attention.

## 6. The eight components (closed list)
| Component | Geometry | Notes |
|---|---|---|
| TaskRow | 12×14 pad, 14 gap | row + meta; selected fill at radius 14 |
| Chip | 9×20 pad, pill | label type; outline by default, filled only as the live timer |
| PillButton | 12×20 pad, pill, 44 hit | filled (terra) / outline / destructive (soft). **One filled per surface** |
| SettleSheet | 26 gutter, radius 14 | Done / Defer / Drop |
| DensityGrid | 18 cell (14 on iPad), 3 gap, radius 3 | d1–d3 + missed, fills toward today, **never holds a numeral** |
| WindowBar | 6 tall, pill | Anchor window: upcoming / open / closing / closed |
| CapacityMeter | 8 tall, pill | longest free block; terra past the limit |
| SectionHeader | label + 24 pt terra rule | the only decorative mark |

## 7. Product rules (acceptance checklist)
- No streaks, "best", or day counters. Habits read by **density**, Anchors by **attendance**.
- No mood tracking. No red, apart from the `alert` rules above. Terracotta is the only filled button.
- No emoji anywhere, **including habit groups** (names only; drop or ignore the schema's emoji field).
- **Avoid habits (HB-08):** a row has **Log a slip** (undoable) and **Held today**. A day counts as `complete` only if slips are within the allowance **and** the user tapped Held today, or engaged that day (G-40). It's `missed` if slips exceed the allowance, otherwise it stays empty. There's no "days since last slip".

## 8. Navigation and adaptive layout
- Tabs: **Today · Habits · Wellbeing · Settings**, using the system `TabView` with `.tabViewStyle(.sidebarAdaptable)`.
- **Anchors**: on phone it's a segment inside Habits. On iPad and Mac it's its own sidebar item directly under Habits (`Tab("Anchors").defaultVisibility(.hidden, for: .tabBar)`), and the segment hides at regular width.
- **Settings**: a sidebar item on iPad. On Mac it moves to the app menu (`Settings` scene, ⌘,), not the sidebar.
- iPad: sidebar, then a list (440), then detail. Mac: the same with menu-bar commands (⌘N Add).
- **iPhone Duo**: the outer display is compact width, with bars in a **right-hand column** (Add, Filter, tabs) per Apple's "Raise the bar with iPhone Duo" guidance. The inner display is regular width, with the fold falling between list and detail. Nothing interactive sits on the fold. Confirm point sizes against Apple's resources.
- Live Activity and Dynamic Island: see file 7. Use ink-and-glass on unknown wallpaper.

## 9. Paywall
Placeholders in the frames: **$29.99/year ($2.50/month)** and **$3.99/month**. In code, show `Product.displayPrice` from StoreKit so the price appears in the user's local currency. Never hardcode a currency.

## 10. App icon: monogram (1d)
The Fraunces italic **J** (weight 500, SOFT 60, WONK 1) in `#EFF4F0`, with a terracotta full stop `#DDA080` on deep `#0C4767`. Dark uses a #071B27 background with a #E7F1F4 J. `icon/` has three 1024×1024 layer SVGs: `1-background`, `2-J` and `3-stop`. **The J is already outlined**, cut from Fraunces Italic at wght 500, opsz 144, SOFT 60, WONK 1. The J and full stop are centred as one group on their real ink bounds. `icon/small/` has a small-size J (wght 620, opsz 48, larger full stop) for Icon Composer's small-size appearance at 29 pt and below. `icon/preview/` has flattened default, dark, tinted and small composites for checking. `icon/JamaalMark.svg` is the mark without a tile, for in-app use. Assemble the layers in Icon Composer for Default, Dark, Clear and Tinted (SY-06). The same mark (same geometry, viewBox 0–100) also appears in three other places. **Notifications** (SB-02) show the 38 pt app icon; the system draws it. The **Live Activity** header uses the J with its full stop at 22 pt, with no tile. **Jamaal's voice avatar** is the mark in a 30 pt deep circle (26 pt in Night Planning). Ship the mark as one vector asset (`JamaalMark`) and reuse it. Colours per appearance: Default uses a #0C4767 background, #EFF4F0 J and #DDA080 full stop. Dark uses #071B27, #E7F1F4 and #DDA080. For Tinted, let the system tint the greyscale layers.

## Files
The package mirrors the repo layout, so `mockups/` copies straight into `jamaal-app/mockups/`. It replaces the empty `mockups/README.md` and fills the empty `mockups/screens/`. `legacy/` is untouched.

- `README.md`: this file. Keep it as `docs/design/threadskit-handoff.md` or similar.
- `mockups/README.md`: the new top-level index for the mockups folder.
- `mockups/screens/README.md`: index of every frame (110 in batches 1–7, then batches 8 and 9), by batch and register ID.
- `mockups/screens/<batch>/*.png`: 2× light-mode exports, one per frame, named `<REGISTER-ID>-<state>.png`.
- `mockups/screens/source/`: the editable HTML (nine `Jamaal v4 · …` batches, `ThreadsKit Tokens`, `Jamaal App Icon`) and `support.js`, which they need to open.
- `icon/`: the outlined icon layers, the small-size variant, previews and `JamaalMark.svg`. Move these into the Xcode project or an `assets/` folder rather than `mockups/`.
