# Accessibility

What has been checked and fixed so far, how to run the check again, and what is still for a person to judge. The first pass (#227) covers the custom components and the main screens on iPhone. It was done before the first TestFlight build.

## What was already sound

- **Text scales.** Every ThreadsKit type role uses a Dynamic Type text style and `ScaledMetric`, up to the largest accessibility size. The one exception is on purpose: the `label` role (the small uppercase mono text) stops at `.xxLarge` (Design handoff §3).
- **Reduce Motion** is honoured by ThreadsKit's `threadsAnimation`.
- **Custom components speak.** The capacity slider is a three-step adjustable slider for VoiceOver ("Capacity for today"); the load meter reads its value and state; each heatmap cell reads "Day 5, done" with a hint; decorative bars (window bar, sparkline, day-shape bar, check circle, companion mark) are hidden, with the same information in text beside them; selected chips and segments carry the selected trait. State is never colour alone: load has its word, habits and Anchors have text.

## Found and fixed in #227

Apple's automated audit (`performAccessibilityAudit`) plus looking at the screens at the *Accessibility Extra Large* text size found layouts that broke when text grew:

- **Habits group header** split a word ("Mornin / g") beside a squeezed count. Now the title and count stack at accessibility sizes (`AdaptiveRow`). The same row is used for the Anchors group on Today and the load meter.
- **Button pairs** ("Look at it" · "Not now", "Plan tomorrow" · "Not today", "Pick for today" · "Not now", "Set it" · "Not now") stack at accessibility sizes (`AdaptiveButtons`) instead of squeezing.
- **The companion mark** sits above its line, not beside it, at accessibility sizes (`CompanionRow`): a long word ("tomorrow.") beside the mark needed more width than was left and **widened the whole Today column past its margins**.
- **Today's column is pinned to the visible width on a phone**, so one long unbreakable word in a title wraps inside the margins instead of moving them. **Not beside a detail panel (iPad, Mac):** there `containerRelativeFrame` measures the whole window, not the list column, and the content was laid out at window width, centred, and clipped by its pane (found on a real iPad, #241; a UI test now checks the load meter stays inside the 440 pt column).
- **The Habits | Anchors pill** had a fixed height of 38 pt while its text scales; it now grows with the text.

## The audit, and what it is not

`AccessibilityAuditUITests` runs the audit on Today, Habits, Anchors, Wellbeing, Settings and two Night Planning steps at the default size, and on Today, Habits, Settings and the Night Planning Load step at *Accessibility Extra Large*. Run it with `xcodebuild test … -only-testing:JamaalUITests/AccessibilityAuditUITests` on an iPhone simulator. It finds mechanical problems (contrast, clipped or fixed-size text, missing descriptions, small hit areas). It **cannot judge whether VoiceOver reads a screen well**.

Two kinds of finding are accepted, and the test skips them:
1. **"Dynamic Type font sizes are partially unsupported"** on the small uppercase labels (the date, the load word, "ANCHORS", "0/2", step counts). This is the `label` cap above. **Owner decision:** raise the cap in ThreadsKit (for example to `.accessibility2`) so those labels keep growing, at some cost to layouts that hold them. Several labels carry meaning (the load word, a count), so I'd lean to raising it; it is a ThreadsKit release, not an app change.
2. **Contrast in the strip just above the floating tab bar.** iOS 26 fades scrolling content into the bar, and the audit reads the fade as low contrast. The same text measures 7.7:1 away from the fade, and the palette's text pairs are 5.0:1 or better in light mode (`ink3` on `app` 5.0, `ink2` 7.9, `ink` 10.8). Small text should use `ink2` or `ink`; `ink3` is the weakest and passes by a small margin. The capacity slider's unselected labels use `ink3` (a note for Design).

## Still to do (needs a person or a later pass)

- **Listen with VoiceOver** on a real iPhone: Today (rows, Anchor group, the meter and slider), Night Planning (the rail and the Load step), the focus timer, and a habit's log buttons. Check the reading order, the labels and what each action says. Turn it on with Settings → Accessibility → VoiceOver (triple-click the side button once set up under Accessibility Shortcut).
- **Larger sizes** (*Accessibility XXL* and *XXXL*) and the iPad and Mac layouts at large sizes were not covered.
- **Right-to-left and Arabic-Indic numerals** (a roadmap item, not started).
- **Mac:** VoiceOver and keyboard focus order on the sidebar and panel.
- **Voice Control and Switch Control:** the heatmap cells and the slider should be reachable by name; not tested.
- **Increase Contrast and Differentiate Without Colour** settings were not tried.
