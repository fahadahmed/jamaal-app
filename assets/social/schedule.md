# Jamaal social schedule (Instagram @jamaal_app)

Working file for planning and publishing. Status values: `published`, `built` (images made, not posted), `drafted` (draft in Buffer), `planned`.
Dates marked **TBC** were not recorded and need confirming. Update this file in the same PR as each post.

**Plan limit: 5 posts a week** (the Buffer free plan; feed posts, reels and stories all count, and at most 10 can be scheduled at once). Everything for a week is built, committed (one branch per post), and scheduled in Buffer at the start of the week, so it publishes without anyone being at the keyboard. Posts go out at **7:00 pm Melbourne time**.

Last checked against Buffer: Sun 1 Nov 2026.

## This week: Sun 1 to Sat 7 Nov

| Day | Post | Format | Issue / branch | Buffer |
|-----|------|--------|----------------|--------|
| Sun 1 Nov | Post 4: Several clients. One day. | Carousel, 7 slides | #351 `task/351-post-4-several-clients` | scheduled |
| Mon 2 Nov | Story 5: reel teaser | Story | #318 `task/318-story-5-reel-teaser` | scheduled |
| Tue 3 Nov | Post 7: Four things, gently paced | Reel, 9.5 s | #352 `task/352-post-7-four-things-reel` | scheduled |
| Thu 5 Nov | Post 9: Habits, measured in weeks | Carousel, 5 slides | #353 `task/353-post-9-habits-weeks` | scheduled |
| Sat 7 Nov | Post 10: Why things keep slipping | Carousel, 5 slides | #354 `task/354-post-10-why-slipping` | scheduled |

## Next week (proposed): Sun 8 to Sat 14 Nov

Sun 8 Story 2 (What's an Anchor? teaser), Mon 9 post 5 (What's an Anchor?), Wed 11 post 8 (Devices carousel), Thu 12 Story 3 (What to try first), Fri 13 Story 4 (Feedback ask). Build these by Sat 7 Nov so the week is set before it starts.

## Feed posts, carousels and reels

| # | Post | Format | Date | Status | Linked article |
|---|------|--------|------|--------|----------------|
| 2 | How much it matters (Low / Medium / High) | Carousel 1080x1350 | Thu 15 Oct | published | none |
| 3 | Founder post | Carousel, 3 slides | Sat 17 Oct | built (confirm posted) | `why-i-built-jamaal` |
| 4 | Several clients. One day. | Carousel, 7 slides | Sun 1 Nov, 7:00 pm | scheduled (was Wed 28 Oct, missed) | `planning-across-clients` |
| 5 | What's an Anchor? | Carousel, 7 slides | Mon 9 Nov (proposed; was Fri 30 Oct, missed) | built in Desktop, not in the repo yet | `whats-an-anchor` |
| 6 | The beta announcement | Carousel, 4 slides | Sun 25 Oct, 7:09 pm | published (Buffer, `2026-10-25-beta-carousel/`) | `join-the-jamaal-beta` |
| 7 | Four things, gently paced | Reel (animated Today screen) | Tue 3 Nov, 7:00 pm | scheduled | `how-jamaal-knows-what-fits-today` |
| 8 | Devices carousel | Carousel | Wed 11 Nov (proposed) | planned | `one-list-on-iphone-ipad-and-mac` |
| 9 | Habits measured in weeks | Carousel | Thu 5 Nov, 7:00 pm | scheduled | `habits-measured-in-weeks` |
| 10 | Why things keep slipping | Carousel | Sat 7 Nov, 7:00 pm | scheduled | `why-things-keep-slipping` |

Carousel 6 was rebuilt on 25 Oct with "The beta is open" on slide 1 and "Join the beta · link in bio" on slide 4.

## Stories (1080x1920)

| # | Story | Date | Status | Link sticker |
|---|-------|------|--------|--------------|
| 1 | The beta is open | Sun 25 Oct, 6:38 pm | published (Buffer, `2026-10-25-beta-open/`) | yes, added by hand |
| 2 | What's an Anchor? (one frame teaser for the article) | Sun 8 Nov (proposed) | planned | yes, article link |
| 3 | What to try first (tasks, one Anchor, Night Planning tonight) | Thu 12 Nov (proposed) | planned | optional |
| 4 | Feedback ask: "tell me what feels wrong" | Fri 13 Nov (proposed) | planned | optional (reply or DM) |
| 5 | Reel teaser for 3 Nov | Mon 2 Nov, 7:00 pm | scheduled | no |

## Journal articles (website)

Checked on jamaal.app/journal on 1 Nov: the live articles are `why-i-built-jamaal`, `getting-started-with-the-beta`, `your-day-on-one-list`, `habits-without-streaks`, `anchors-the-things-your-day-moves-around`, `widgets-and-the-lock-screen`, `first-night-planning` and `salah-quran-dhikr`. **None of the slugs below are live (404)**, so captions say "link in bio" until they are. Check the dates against what is actually published.

| Article | Date | Status |
|---------|------|--------|
| `planning-across-clients` | 22 Oct | published |
| `whats-an-anchor` | 22 Oct | published |
| `join-the-jamaal-beta` | 26 Oct (with post 6) | written, needs public-link wording and minimum OS versions |
| `how-jamaal-knows-what-fits-today` | 3 Nov (with post 7) | written |
| `habits-measured-in-weeks` | 5 Nov (with post 9) | written |
| `why-things-keep-slipping` | 7 Nov (with post 10) | written |
| `one-list-on-iphone-ipad-and-mac` | 1 Nov (with post 8) | written |

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

Buffer free plan: 10 scheduled posts per channel at a time, and we plan 5 a week.

Images for scheduled posts use commit-pinned raw URLs (`https://raw.githubusercontent.com/fahadahmed/jamaal-app/<commit>/assets/social/...`) so they keep working after a branch is merged and deleted. If an image changes, edit the Buffer post to use the new URL.
