# Onboarding

> **Status: draft, needs review.** First-pass proposal — guided primitive setup, per review decision.

Walks a new user through creating one example of each primitive, so all three are demonstrated (and something is in the Today List) before first real use.

## Flow

1. **Welcome** — brief framing: one list for everything, three ways of tracking (do / cultivate / attend), not an Islamic-only app (per CLAUDE.md's positioning) but supports those practices as presets.
2. **Account readiness** — CloudKit sign-in check (sync is in from v1, not deferred), handled silently if already signed into iCloud; only surfaced if there's a problem.
3. **Baseline capacity** — introduce the capacity slider (see [today-list.md](today-list)) and have the user set an initial value, so it isn't unset on first Today List view.
4. **Guided Task creation** — create one real Task (e.g. prompted with a placeholder like "something you need to do this week").
5. **Guided Habit creation** — offer presets (Qur'an reading, dhikr, exercise, running — see [habit.md](../schema/habit)) or a custom habit; creates the `Habit` plus its first `HabitTimeWindow`.
6. **Guided Anchor setup** — since `Anchor` instances are generated, not user-created (see [anchor.md](../schema/anchor)), this step actually guides the user through creating an **`AnchorRule`** (e.g. "add your prayer times" or "add bin night"), which then generates the first `Anchor` instance(s) automatically. This keeps onboarding consistent with the schema rather than fabricating a special onboarding-only path for Anchors.
7. **Land on Today List** — with one real Task, Habit, and Anchor already present, so the unified list isn't empty on first real use.

## Open questions

- **Step 6's premise is provisional**: the whole "guide the user through an `AnchorRule`, not a raw `Anchor`" approach rests on the generated-not-user-created positioning decided in `anchor.md` — flagged for revisiting, not settled. If that positioning changes, this step changes with it.
- **Preset content for step 6**: `AnchorRule.configData`'s shape isn't settled yet (see anchor.md's open questions, deferred to #7) — onboarding's Anchor-setup UI depends on that being resolved first, at least for the built-in `sourceKey` options (prayer window, school run, bin night, plant watering).
- **Skippable steps**: can a user skip guided Task/Habit/Anchor creation entirely and land on an empty Today List? Given the "guided primitive setup" decision, at minimum steps 4–6 are meant to be non-skippable for a first-run experience, but worth confirming explicitly.
- **Notification permission prompt**: not included above — CLAUDE.md's rules-engine module 6 (notification/nudge logic) implies this is needed eventually, but whether it's asked during onboarding or deferred to first use of a feature that needs it (e.g. first Night Planning) isn't decided.
