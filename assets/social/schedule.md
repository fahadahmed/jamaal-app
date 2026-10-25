# Jamaal social schedule (Instagram @jamaal_app)

Working file for planning and publishing. Status values: `published`, `built` (images made, not posted), `drafted` (draft in Buffer), `planned`.
Dates marked **TBC** were not recorded and need confirming. Update this file in the same PR as each post.

## Feed posts, carousels and reels

| # | Post | Format | Date | Status | Linked article |
|---|------|--------|------|--------|----------------|
| 2 | How much it matters (Low / Medium / High) | Carousel 1080x1350 | Thu 15 Oct | published | none |
| 3 | Founder post | Carousel, 3 slides | Sat 17 Oct | built (confirm posted) | `why-i-built-jamaal` |
| 4 | Several clients. One day. | Carousel, 7 slides | TBC | built | `planning-across-clients` |
| 5 | What's an Anchor? | Carousel, 7 slides | TBC (was planned 30 Oct) | built | `whats-an-anchor` |
| 6 | The beta announcement | Carousel, 4 slides | TBC | built, needs wording update (see below) | `join-the-jamaal-beta` |
| 7 | Four things, gently paced | Reel (animated Today screen) | Mon 2 Nov | planned | `how-jamaal-knows-what-fits-today` |
| 8 | Devices carousel | Carousel | TBC | planned | `one-list-on-iphone-ipad-and-mac` |
| 9 | Habits measured in weeks | Carousel | TBC | planned | `habits-measured-in-weeks` |
| 10 | Why things keep slipping | Carousel | TBC | planned | `why-things-keep-slipping` |

Carousel 6 still says "The beta is coming" on slide 1 and "Join the waitlist" on slide 4. The beta is open, so change these to "The beta is open" and "Join the beta · link in bio".

## Stories (1080x1920)

| # | Story | Date | Status | Link sticker |
|---|-------|------|--------|--------------|
| 1 | The beta is open | Sun 25 Oct | built (`2026-10-25-beta-open/`), not yet drafted | yes, added by hand |
| 2 | What's an Anchor? (one frame teaser for the article) | TBC | planned | yes, article link |
| 3 | What to try first (tasks, one Anchor, Night Planning tonight) | TBC | planned | optional |
| 4 | Feedback ask: "tell me what feels wrong" | TBC | planned | optional (reply or DM) |
| 5 | Reel teaser for 2 Nov | Sun 1 Nov | planned | no |

## Journal articles (website)

| Article | Date | Status |
|---------|------|--------|
| `planning-across-clients` | 22 Oct | published |
| `whats-an-anchor` | 22 Oct | published |
| `join-the-jamaal-beta` | 28 Oct (placeholder) | written, needs public-link wording and minimum OS versions |
| `how-jamaal-knows-what-fits-today` | 3 Nov (placeholder) | written |
| `habits-measured-in-weeks` | 17 Nov (placeholder) | written |
| `why-things-keep-slipping` | 24 Nov (placeholder) | written |
| `one-list-on-iphone-ipad-and-mac` | 1 Dec (placeholder) | written |

## Story rules

- Size 1080x1920. Keep text clear of the top and bottom ~250px, and about 88px from the sides.
- Brand: deep blue `#0C4767`, paper `#EFF4F0`, ink `#0A3A53`, green `#1F6A58`, mint `#8FCBB8`, terracotta `#9A4F2E` / `#DDA080`. Fraunces (display), Hanken Grotesk (text), JetBrains Mono (labels). Use the real app icon from `Jamaal/Jamaal/Assets.xcassets/AppIcon.appiconset/AppIcon-default.png`.
- Buffer posts Stories as an image or video only. Link stickers, polls and question boxes are added by hand in Instagram.
- Link format: `https://jamaal.app/<page>?utm_source=instagram&utm_medium=story&utm_campaign=<campaign>`.
- Never name EY or any client. Say "consulting" or "several clients".
- Do not promise widgets, Apple Watch or Live Activity. They are 1.1.
- Jamaal 1.0 does not read the calendar or sync with trackers.
- Prices: $2.99/month, $24.99/year, 14-day trial. The beta is free.
- Never name the matrix (Eisenhower) in the UI or in copy.

## Publishing workflow

1. Build the images and write alt text (see the notes file next to each set).
2. Commit them under `assets/social/<date>-<slug>/` on a branch and open a PR.
3. After merge, check the raw image link returns 200: `https://raw.githubusercontent.com/fahadahmed/jamaal-app/main/assets/social/<date>-<slug>/<file>.png`.
4. Create a Buffer draft for `@jamaal_app` (type `story`, alt text on each image, drafts by default).
5. Review in Buffer. Add the link sticker in Instagram if the Story needs one.
6. Update the status in this file.

Buffer free plan: 10 scheduled posts per channel at a time.
