# Journey 11 — Categories

> **Status: done — gaps G-84 … G-89 raised, decided and applied** (see the [gap log](overview#gap-log)). The text below is the walkthrough as first written. Register flow **F14**; screens **ST-04** (Categories), **TK-06** (Category picker), **TD-03** (Category filter), the category field on **TK-01 / TK-02**, the chips in **OB-06** and the label on every Today row. Behaviour is in [Task → TaskCategory](../../schema/task#taskcategory); this page tests it against everything the ten earlier journeys now assume of categories. It also closes **G-08**, the one item still open from Journey 1.

**In one line:** the user keeps a short list of personal labels — *Personal*, *Family*, *Work*, plus their own — puts at most one on a task, and can narrow Today to one of them, without categories ever becoming projects, sections or tags.

**Preconditions:** Journeys 1–10 done. Example: the three seeded categories; a user-created *Errands*; tasks across them; an archived *Family*; an iPhone and an iPad on the same account.

---

## Seeding, and the first chips (OB-06)

- **Sees:** three chips — *Personal*, *Family*, *Work* — none selected; each a small coloured label.
- **Reads/writes:** the three `TaskCategory` rows seeded at first launch (`presetKey`, `name`, `colorKey`, `sortOrder`).
- **Assumes:**
  - the chips have colours — **✗ G-84** (`colorKey` values are not defined: **G-08**, open since Journey 1, and the only tokens that exist are `accent` and `terra`, the second of which already carries warning and overload);
  - the seeds survive two devices — ✓ (merged by `presetKey`, the earliest kept);
  - a user who archived *Family* doesn't get it back on a new device — ✓ (seeding is skipped if a row with that `presetKey` exists, archived or not).

## ST-04 The category list

- **Sees:** active categories in order, each with its colour and its name; **Add**; a collapsed **Archived** section with **Restore** (the pattern of Journey 5's G-41); on regular width this sits in a panel.
- **Does:** renames, reorders, picks a colour from the fixed set, archives, restores, adds.
- **Writes:** `TaskCategory` (`name`, `colorKey`, `sortOrder`, `isArchived`; user-created rows have `presetKey = nil`).
- **Assumes:**
  - names are sensible — **✗ G-85** (an empty name, a 200-character one, or the same name twice — *"Errands"* created on the iPhone and on the iPad before they sync — would leave two identical chips; the dedup table says user-created categories "have no key");
  - the list stays glanceable — **✗ G-89** (nothing limits how many, or says how order is decided, and a long chip row starts to feel like the tags and projects the product rules out);
  - every category can be removed from view — ✓ (archive, never hard delete; defaults can be renamed or archived).

## TK-06 The picker, and the field on TK-01 and TK-02

- **Sees:** active categories as chips plus *None*; the task's current one selected.
- **Writes:** `Task.category` (one or none).
- **Assumes:**
  - a task whose category was archived later still behaves — **✗ G-86** (the label is kept, but the docs don't say whether it still shows on Today, whether it appears in the picker when that task is edited, or what a repeating task copies);
  - a new task starts with a sensible category — **✗ G-88** (none by default, but a user who has narrowed Today to *Work* and then adds a task presumably means *Work*);
  - a read-only user can't change it — ✓ (editing is locked with the rest, Journey 9).

## TD-03 The category filter on Today

- **Sees:** a control in the Today header listing *All* and each active category; choosing one narrows the list, with a visible chip to clear it.
- **Reads:** `Task.category`; **writes:** nothing (local UI state).
- **Assumes:**
  - "narrows the whole list" is well defined — **✗ G-87** (Anchors and habits have no category, so they can't be filtered; the meter and the load describe the *day*, not the view; the *Start here* card picks from tasks; and it isn't said whether the filter survives relaunch or the rollover, or what an empty result says);
  - categories never become sections — ✓ (the filter only hides; Tasks stay one flat list in engine order).

## What categories do *not* touch

Wellbeing, load, capacity, the deferral rules, Night Planning and the engine's order ignore categories entirely ✓; habits have **groups** (a visual bundle) and Anchors have **rules**, neither has a category; export includes categories, and read-only locks creating or editing them (Journey 9).

---

## What the user sees over time

A new user meets three quiet labels and uses none of them for a week. Then *Work* earns its place: a small teal-or-blue dot beside tasks, and one tap in the header narrows Today when they sit down at the desk. The Anchors and habits stay put; the meter still says how the whole day is going. They add *Errands*, find it noisy, and archive it: old tasks keep their label, it leaves the picker, and *Restore* brings it back. On the iPad the same list is waiting.

## Data that exists afterwards (end-state check)

| Model | Change |
|---|---|
| `TaskCategory` | seeded 3; + 1 per user-created; `name`, `colorKey`, `sortOrder`, `isArchived` edited in place |
| `Task` | `category` set or cleared; unchanged when its category is archived |

No new fields; `colorKey` finally gets its values, and one dedup key is added for user-created categories.

## Rules and changes this journey implies

If the proposals are accepted:

1. **Colours (G-84, closes G-08):** a fixed set of five label colours, each a ThreadsKit token with a light/dark pair, contrast-tested on the surface: **`accent`** (the teal — the existing default, so `colorKey = "accent"` stays valid), **`blue`**, **`ochre`**, **`plum`** and **`slate`**. `terra` is deliberately **not** in the set, because it carries warning and overload. The three defaults are *Personal* = `accent`, *Family* = `ochre`, *Work* = `blue`. A label is always a **dot plus the name in ink** — colour is never the only signal — and on narrow rows the name may truncate but the dot never stands alone. New tokens come from ThreadsKit **1.2.0**; until then placeholders. The hues are to be confirmed against the Claude Design tokens before they are cut. An unknown `colorKey` falls back to `slate`.
2. **Names and duplicates (G-85):** a name is trimmed, 1–24 characters and unique (ignoring case) among all categories, archived included; renaming a default keeps its `presetKey`. Because two devices can still create the same name, the engine treats the **normalised name** as the dedup key for user-created categories: it keeps the earliest, moves the tasks onto it and archives nothing else. A category has no settings of its own, so merging identical labels loses nothing.
3. **Archived categories (G-86):** a task keeps its label and **still shows it** on Today; an archived category is absent from the picker and the filter, except that a task being edited shows its current archived label as selected (*"Family — archived"*) so it isn't silently dropped; a repeating task copies it. Tasks under an archived category are found under *All*. Nothing about history changes: it is all in the export. This settles the open question in the app-flow doc.
4. **The filter (G-87):** it applies to the **Tasks section only** — Anchors and habits are always shown — and the **meter, load and *Also today* counts stay whole-day**. The *Start here* card is chosen from the visible tasks (hidden if none qualifies). The filter is **local to the device, clears at the rollover and on relaunch**, and an empty result reads *"Nothing in Family today."* with a *Show all* action. A *No category* option appears only when some live task has none and some has one.
5. **New tasks (G-88):** a new task's category is **none**, unless a filter is active, in which case it **inherits that category** (the user can change it). Quick capture from Night Planning uses none.
6. **A short list (G-89):** at most **eight active** categories; beyond that *Add* explains that fewer, broader labels work better and offers to archive one. Order is `sortOrder`, reordered by dragging in `ST-04`; the picker and filter use the same order; merged duplicates take the earliest's position.
