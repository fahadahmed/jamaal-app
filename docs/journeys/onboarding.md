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
8. **Your first Anchor** — the user picks a type — prayer times, school run, bin night, plant watering or custom — and fills its short form, creating an **`AnchorRule`** that generates the first `Anchor` instance(s). Users who don't have any of these can choose "Not now" — Today's Anchors section then explains what Anchors are and offers to add one (see open questions). The forms (shapes in [anchor.md](../schema/anchor#configdata-shapes)):
   - **Prayer times** — asks for *when-in-use location* only now, in context (never earlier), and falls back to searching for a city if the user declines. Then: calculation method (suggested from the region), madhab (standard or Hanafi), which prayers to include, and whether Isha closes at Islamic midnight (default) or Fajr. Advanced (collapsed): per-prayer minute adjustments and the high-latitude rule.
   - **School run, bin night, plant watering, custom** — one shared form: days (or "every N days / every N weeks" with a start date, or "N–M days after I last did it" for things like plants), one or more named time slots with an open window (or all day), and how long it takes. Each type opens with its own preset filled in and editable; custom opens blank with one empty slot. Exceptions (term breaks, holidays, travel, illness) are added later from the rule's edit screen, not during onboarding.
9. **Ready** — land on Today with a Task, a Habit and (usually) an Anchor present, plus a card: "Tonight, we'll plan tomorrow."

## Open questions

- **Skippable steps**: proposal — steps 1–4 and 6–7 are required; step 5 (notifications) and step 8 (Anchor) can be skipped, since a non-Muslim user with no school run shouldn't be forced to invent an Anchor. Needs confirmation; it trades "all three primitives demonstrated" for honesty.
- **Anchor setup** follows the settled positioning ([ADR 0001](../architecture/decisions/0001-anchor-object-type)): onboarding step 8 creates a recurring commitment (an `AnchorRule`). One-off Anchors aren't part of onboarding; they're introduced from Today's add button.
- **Prayer setup length**: method, madhab, prayers, Isha end and location is a lot for one onboarding step. Proposal: the visible form is location + method (with a region-based default) and a "Customise" disclosure for the rest.
- **Sample content**: whether steps 6–8 pre-fill sample values the user can edit, or start blank with placeholders.
