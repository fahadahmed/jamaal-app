# Today: a compact top (#406)

**Status: built, awaiting Design's eye.** It departs from the v4 Today frame (`TD-01`), so it needs a look from Design before the App Store pictures are made.

## Why
The owner's own use: the task list, the thing used most, started far down the screen, below the headline, the capacity meter and slider, the wellbeing strip, any cards, every Anchor and every habit.

## What changed
| Part | Before | Now |
|---|---|---|
| Capacity | meter, then the slider with its three labels | one row: **"Medium · 2h 15m of 3h"** and the load word over the bar, with a chevron that unfolds the slider |
| Wellbeing strip | a row with the sparkline under the slider | **gone from Today**; the Wellbeing tab is one tap away (the once-a-day pattern card stays) |
| Anchors | every Anchor (plain rows, grouped rows, window bars) | **one line**: "Asr · until 5:58 pm · 3 of 7"; opened by its chevron |
| Habits | every habit and group | **one line**: "2 of 6 done"; opened by its chevron |

The order of the rest is unchanged: header, banners, cards, Anchors, Habits, **Tasks**, Also today, Yesterday, Coming up.

## Rules
- **Anchors are still shown at every capacity level**: the line *is* the section, and it names the next one still to do. A missed or closed Anchor is never "next"; skipped and delegated ones are left out of the count, as in a grouped row.
- **Open or closed is remembered per device** (not synced): the slider, the Anchors and the Habits each keep their own state.
- The first launch starts them **closed**. Debug runs on the in-memory store (the UI tests) start them **open** so older tests keep working; `-JamaalCompactToday` gives a test the real default.
- No new tokens or components beyond one collapsible section header (eyebrow, summary, chevron).

## Not decided
- Whether the Anchors line should stay open automatically while a window is **open now** (needs you), since an Attended tap is one more tap away when folded.
- A "next gap" line above the tasks (the owner's question 3) would sit beside these lines and is a separate piece of work.
