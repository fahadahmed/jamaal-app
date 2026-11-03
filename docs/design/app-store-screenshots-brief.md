# Brief: the App Store pictures

For Claude Design (#362). **Status: decided with the owner, 3 Nov 2026.** The real app has been captured on every device with a curated dataset; **your job is to turn those captures into the store slides**. The captures are in `assets/appstore/design-handoff/` (one folder per device; `README.md` there lists every file and its size).

## What you are making

| Set | Where it goes | Canvas | Source captures |
|---|---|---|---|
| **iPhone 6.9"** | App Store Connect, iPhone | **1320 × 2868** | `iphone-6.9/` (1320 × 2868) |
| **iPad 13", landscape** | App Store Connect, iPad | **2752 × 2064** | `ipad-13-landscape/` (2752 × 2064) |
| **Mac** | App Store Connect, Mac | **2880 × 1800** (or 2560 × 1600) | `mac/` (the window, 2048 × 1250; the Settings window is smaller) |
| **iPhone Duo** | The website, social and product-page art. App Store Connect has **no Duo slot** | your choice, one for the outer display (portrait) and one for the inner (landscape, plus the tabletop) | `iphone-duo/` (the displays as the system draws them) |

Upload slots take up to 10 pictures per device; **six per device is the aim**. The first three iPhone pictures are what shows in search results, so the order matters: **Today, Night Planning, Habits**.

## The look

The direction is **one very large, bold headline; a flat brand-colour ground, a different one per slide; the real screen shown large and slightly tilted; and one part of the UI lifted out as a crisp card floating in front of it**, with the screen fading into the ground behind. (An earlier attempt at exactly this is in `assets/appstore/` as `build.py`, to show the idea; its output is a placeholder, not the answer.)

- **Voice:** calm, supportive, never urgent. No exclamation marks, no "don't miss out", no streaks, no scores to chase. Short. The tagline is **"One list. Just today. Beautifully ordered."**
- **Colours** (ThreadsKit, `docs/design/threadskit-usage.md`): deep blue `#0C4767`, paper `#EFF4F0`, ink `#0A3A53`, green `#1F6A58`, mint `#8FCBB8`, terracotta `#9A4F2E` and `#DDA080`. Soft grounds from them: mint `#CFE6DC`, terracotta tint `#F3E0D4`, blue tint `#D6E4EE`.
- **Fonts:** Fraunces for the headline (the accent phrase in its italic), Hanken Grotesk for anything smaller; both ship in ThreadsKit. Never DM Sans.
- **Light appearance only**, as captured.

## Rules

- **No status bar, anywhere.** A simulated clock, signal and battery is not what Apple wants shown; the captures already have it taken out, so do not draw one back in. The same goes for the iPadOS window grip.
- **Show the real app**, as captured; do not redraw the UI. Crop and rotate freely.
- **Nothing that is not built:** no Apple Watch, no Live Activity, no interactive widgets, no sharing or referral, no tvOS or visionOS.
- **No client names, no real people.** The names in the captures (Priya, Sam, Yusuf, the clinic) are fictional sample data.
- **Prices only as the app says them:** a 14-day trial, then **$2.99 a month or $24.99 a year**. Better not to mention price at all.
- **iPhone Duo is a marketing set only** (see above). Don't present it as an App Store Connect upload.

## The screens, and a headline for each

The headlines are suggestions in the product's voice; change them if you have better.

| File (per device) | What it is | Suggested headline | A part worth lifting out |
|---|---|---|---|
| `01-today` (iPad, Mac: `-task-open`) | The one Today list: the day's load, the capacity slider, Jamaal's evening card, Anchors and Habits | **One list. *Just today.*** | The Anchors rows with their progress bars, or the capacity slider |
| `02-night-planning-build` | Night Planning, step 3 of 5: tomorrow's shape with its fixed commitments and free time | **Plan tomorrow, *tonight.*** | The "About right" load check (`02b-…-load`) or the commitments grid |
| `03-habits` (`-open` on iPad, Mac) | Habits as a grid of days, never a streak | **Habits as a grid *of days.*** | The Morning group strip, or the Water habit's six-week grid |
| `04-anchors` (`-open` on iPad, Mac) | Anchors: prayer times, the school run, bin night, plants | **What your day *moves around.*** | The School run rule with its coming-up times |
| `06-focus` | The focus timer with its note's checklist | **Begin a task. *Stay with it.*** | The checklist or the Pause and Finish buttons |
| `05-wellbeing` | The gentle wellbeing reading | **A gentle read on *how it's going.*** | The Jamaal suggestion card, or the metrics list |
| `07-settings-window` (Mac only) | The Mac's own Settings window | optional, for the Mac set | the Day pane |

Alternates are in the folders as `02b`, `02c`, `01b`.

## iPhone Duo

The Duo is the foldable iPhone. Its captures are the displays as the system draws them, so the pills at the side are part of the device. The set:

- **outer** (closed): the outer display, 466 × 678 pt. Today, Habits, Anchors, Focus, Wellbeing.
- **inner landscape** (fully open): two panes, a list beside its detail: Today with a task open, Night Planning, Habits with a habit open, Anchors with a rule open, Wellbeing.
- **tabletop**: the focus timer split at the crease, a teal half above and the checklist below (the Duo section of `docs/journeys/app-flow.md` describes it).
- Optionally **inner portrait** and **half open**.

A good Duo slide shows what only a foldable can: the two-pane layouts, and the tabletop timer. Keep the **crease** (a thin gap) honest and don't paint over it.

## Regenerating

If the app changes, the captures can be remade (`assets/appstore/capture-ios.sh`, `capture-ipad.sh`, `capture-mac.sh`, `capture-duo.sh`) and cleaned with `prepare-handoff.py`. They use the debug-only store dataset (`-JamaalStoreShots`), so the screens are the same every time.
