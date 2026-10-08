# Brief for Claude Design: widgets and the watch

Jamaal has no widget or watch frames yet. This is what to draw, in the v4 language (ink on `app`, `terra` as the only action colour, Fraunces for headlines, Hanken Grotesk for text, JetBrains Mono for labels, no red, no streaks, no scores, calm copy). The architecture is in [Widgets and the watch](../architecture/widgets-and-watch); the decision is [ADR 0003](../architecture/decisions/0003-widgets-in-v1-watch-in-v1-1).

## v1: widgets

**Next Anchor**
- Home Screen small.
- Lock Screen: circular (time left as a ring), rectangular (*Dhuhr · until 15:32*, and a line beneath), inline.
- States: an Anchor window upcoming, open, closing soon, none left today, an Anchor that needs attention (shown plainly, not as an error).

**Today**
- Small (the count and the capacity bar), medium (the headline, the bar, the next two tasks) and large (the next five, and the Anchor line).
- States: a normal day, all done, a blank day, the evening with *Plan tomorrow*, and read-only (the trial ended; same data, no prompts).

**For every widget**
- Light, dark, and the system's **tinted** (accented) and **vibrant Lock Screen** renderings: say which parts take the accent.
- The **privacy-redacted** look for task titles on a locked Lock Screen (a dot or a plain bar, not "hidden").
- Dynamic Type at the largest sizes, and right-to-left.
- iPad and Mac (desktop and Notification Center) variants where they differ from iPhone.

## v1.1: Apple Watch (companion app)

- **Today:** the next task large with a tap to mark done; the crown scrolls the rest; the done state.
- **Anchors:** the current window and time left; the Smart Stack card.
- **Habits:** the list; Water with the crown; *Held today* and *Slip* for an avoid habit; the timed habit's *Begin*.
- **Focus:** the timer running, paused and finished (large digits, no alarm).
- **Complications:** circular, corner, rectangular and inline.
- A calm state for when the iPhone hasn't been reached for a while (a pending mark on a queued action).

Watch sizes: 40/41/42, 44/45/46 and 49 mm. OLED: lean on the deep ground (`#071B27`) and ink-and-glass, with `terra` only for the one action.

## Not in scope here

Interactive widgets, Control Center controls, Live Activity (already drawn, v1.1), sounds and motion (a separate pass).
