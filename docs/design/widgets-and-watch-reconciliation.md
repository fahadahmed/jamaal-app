# Widgets and watch: what the frames decided

Design batches 8 (widgets) and 9 (watch) settle some things the docs left open or didn't mention. Behaviour still comes from `docs/architecture/widgets-and-watch.md`. This records where the frames add to it. Items marked **owner** need sign-off before they're built as final.

## Widgets

1. **No checkboxes on widgets.** v1 widgets aren't interactive, so tasks show a category dot, not a check circle.
2. **Accent group.** `widgetAccentable()` goes on the Anchor name, Today's count, the italic headline line and bar fills. Everything else renders as primary. Category dots render as primary in tinted mode.
3. **Needs attention** (an Anchor window that closed unmarked) shows as a neutral full bar plus *Not marked yet*. It isn't accent and it isn't an error.
4. **Closing soon** keeps the accent colour. Only the word and the bar's length change.
5. **Blank day** shows the next Anchor and no "add something" prompt.
6. **All done** hides the capacity bar and shows *4 of 4 done* plus the next Anchor.
7. **Read-only** shows the same data, drops the *Plan tomorrow* link, and adds one quiet *View only* line. There's no upgrade prompt on a widget.
8. **Plan tomorrow** is the only terracotta on any widget. It appears from the planning time, on medium and large only, and never on the Lock Screen.
9. **Dynamic Type at accessibility sizes.** The medium drops the headline to the count and shows one task, truncated to one line.
10. **Habits stay off the large widget** for now. This answers the doc's open question provisionally (**owner**).
11. **Anchor titles stay visible on a locked Lock Screen**, as the doc proposed (**owner**).

## Watch

12. **Navigation.** Three vertical pages (Today · Anchors · Habits), one level of push at most, and Focus as a full-screen cover. There's no tab bar.
13. **Launch rule.** A running session → Focus. An open, unmarked window → Anchors. Otherwise → Today. After an hour away, the rule runs again.
14. **Task detail exists on the watch.** It shows Begin as the filled button and Done as glass. The checklist is read-only, and *More on your iPhone* points the way to defer and drop.
15. **Finish on the watch** offers FS-05's two choices: **Done** / **Stop for now**. Defer, Drop and the note line stay on the phone.
16. **Anchors on the watch:** Attended is the filled action, and long-pressing a row gives Attended / Skipped. The app says time left in words (*40 min left*). Complications show the clock time.
17. **Counted habits** are saved as you turn the crown, debounced into one queued action. Past the target the ring stays full and the number keeps going.
18. **Pending state.** A queued action shows a dashed ring and *waiting for iPhone*. The *As of 14:20* footer appears only after 15 minutes without a snapshot.
19. **First run.** Before the first snapshot arrives, Today says *Open Jamaal on your iPhone to begin.* Read-only users see the pages without action buttons.
20. **40 mm.** The primary button is 40 pt tall there, the only place below 44.
21. **Watch icon.** The same 1d layers with a circular mask, one appearance, and the small-size J at list and notification sizes.

## Unchanged

Live Activity (FS-08) stays v1.1. No Wellbeing score, streaks, overdue counts or red anywhere. Interactive widgets, Control Center controls and a habit-counter complication wait for App Intents (v1.1+).
