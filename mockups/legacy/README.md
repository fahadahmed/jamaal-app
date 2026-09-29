# Legacy mockups

HTML mockups from the earlier planning chat (May 2026), imported as **layout and flow reference only**. They predate the repo restart, the Anchor primitive and ThreadsKit's cool palette, so they are **not** visual truth. Colours, fonts and terminology in them are out of date — see `docs/design/threadskit-usage.md` for current tokens and `docs/journeys/` for current flows.

## `2026-05-warm/` — first generation (13–20 May)

Warm off-white/terracotta/sage palette (`#E8E4DC`, `#B5623A`, `#6B8C72`) with Fraunces + DM Sans. This is the set the master summary v2 describes.

| File | Screen | Notes |
|---|---|---|
| `jamaal-today.html` | Today | Newest Today file (20 May), larger than `-v2` |
| `jamaal-today-v2.html` | Today | Earlier (14 May); guidance highlight + Jamaal card |
| `jamaal-night-planning.html` | Night Planning | Earlier flow |
| `jamaal-night-planning-v2.html` | Night Planning | Full-screen 5-step flow incl. carry-forward (Keep/Later/Drop) |
| `jamaal-onboarding.html` | Onboarding | 5 screens: meet Jamaal, concept, capacity, notifications, ready |
| `jamaal-habits.html` | Habits | Groups, counted habits, heatmap |
| `jamaal-wellbeing.html` | Wellbeing | Score + sparkline, gathering-data state |

## `2026-05-ceramic/` — second generation (27 May)

"Ceramic keyboard" palette (cream, coffee brown, clay, eucalyptus) with Bricolage Grotesque/Fraunces/Inter Tight, sharing `system.css`. Built on an earlier Threads design system; superseded by the cool palette. Contains Habits, Night Planning, Onboarding and Wellbeing only (no Today).

## Not imported

- `jamaal-landing.html` — marketing site (belongs in the jamaal.app web project, not the app).
- `jamaal-onboarding_1.html` — byte-identical duplicate of `jamaal-onboarding.html`.

## Known gaps versus the current design

- No Anchor anywhere (salah appears as a habit group).
- No cool ThreadsKit palette; no Liquid Glass styling to speak of.
- Capacity shown in minutes; the repo uses low/medium/high plus effort estimates.
- No category editing UI.
