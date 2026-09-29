# Onboarding

> **Status: reconciled with master summary v2 — draft, needs review.** Merges v2's five-screen intro (meet Jamaal, concept, capacity, notifications, ready) with the repo's guided creation of one example of each primitive.

Walks a new user through setting up the app and creating one example of each primitive, so all three are demonstrated (and something is on Today) before first real use. It also sets up the evening Night Planning reminder so the first planning session actually happens (see [app-flow.md](app-flow)).

## Flow

1. **Meet Jamaal** — the companion introduces itself: calm, supportive, non-judgmental. Tagline: "One list. Just today. Beautifully ordered."
2. **The idea** — one list for everything; three ways of tracking: things you **do** (Tasks), things you **cultivate** (Habits), things your life **moves around** (Anchors). A general productivity app — Islamic practices are presets, not a mode.
3. **Account readiness** — CloudKit / iCloud check. Silent when signed in; surfaced only if there's a problem (sync is in from v1).
4. **Baseline capacity** — introduce the capacity slider (`low`/`medium`/`high`) and set an initial value, so it isn't unset on first Today view.
5. **Notifications & evening planning time** — request notification permission, framed around the evening planning reminder, with a time picker (default 20:00). Skippable: if skipped or denied, the in-app planning banner takes over (see [today-list.md](today-list)).
6. **Your first Task** — create one real task (placeholder like "something you need to do this week"). The user picks or creates a category here, which introduces the three default categories.
7. **Your first Habit** — presets (Qur'an reading, dhikr, exercise, running) or custom; creates the `Habit` plus its first `HabitTimeWindow`.
8. **Your first Anchor** — guides the user through creating an **`AnchorRule`** (prayer times, school run, bin night, plant watering, custom), which generates the first `Anchor` instance(s). Users who don't have any of these can choose "Not now" — Today's Anchors section then explains what Anchors are and offers to add one (see open questions).
9. **Ready** — land on Today with a Task, a Habit and (usually) an Anchor present, plus a card: "Tonight, we'll plan tomorrow."

## Open questions

- **Skippable steps**: proposal — steps 1–4 and 6–7 are required; step 5 (notifications) and step 8 (Anchor) can be skipped, since a non-Muslim user with no school run shouldn't be forced to invent an Anchor. Needs confirmation; it trades "all three primitives demonstrated" for honesty.
- **Anchor setup** follows the settled positioning ([ADR 0001](../architecture/decisions/0001-anchor-object-type)): onboarding step 8 creates a recurring commitment (an `AnchorRule`). One-off Anchors aren't part of onboarding; they're introduced from Today's add button.
- **`AnchorRule.configData` shapes** must be settled before step 8's per-type forms can be designed, at least for the four built-in `sourceKey`s. Prayer times additionally need location permission and a calculation method.
- **Sample content**: whether steps 6–8 pre-fill sample values the user can edit, or start blank with placeholders.
