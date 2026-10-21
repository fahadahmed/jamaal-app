# Brief: the TestFlight emails

A self-contained brief for Claude Design. **Status: draft for the owner, 21 Oct 2026.** It covers the emails Jamaal sends itself, through **Resend**, to the people waiting for the beta. It does **not** cover the emails Apple sends (see the first section).

## What you are designing

A short, calm sequence of emails from Jamaal to people who asked to hear about the beta:

| # | Email | When | Job |
|---|---|---|---|
| 1 | **Heads-up** | Before the beta opens | Say TestFlight is very soon, what to expect, and what to do. No date promised. |
| 2 | **It's ready** | The day the beta opens | The install link and the three steps to install. |
| 3 | **How to use Jamaal** (a short series, one email each) | After they install | One link to one article each: Night Planning, the Today list and capacity, Habits, Anchors, the widgets. |
| 4 | **New build** (optional, later) | When a build has something worth saying | What changed, and how to send feedback. |

Design **one template** that all four use (a header, a hero line, one block of body text, one button, a short "what to expect" or "what changed" list, a footer), so each email is mostly new words and not a new layout.

## Not Apple's emails

TestFlight's own emails (the invitation, the new-build notice) are sent by Apple in Apple's format and **cannot be restyled**; only their text can be changed (the Beta App Description and the *What to Test* note, set in App Store Connect). Don't design a copy of them. Our emails should be clearly **from Jamaal, and different** from Apple's, and email 1 should tell people what Apple's email looks like so they recognise it.

## Open question for the owner: which way in?

This changes the words in emails 1 and 2, so it needs deciding before they are written.

- **Route A, the public link:** email 2 contains the TestFlight public link. The person taps it, TestFlight opens, they accept and install. **Apple sends no email.** This is the dependable route: we saw an Apple invitation email fail to arrive for an internal tester, and the link needs none.
- **Route B, Apple's invitation:** the owner adds each person's address to the external group, and Apple emails them an invitation. Email 1 would say "expect an email from Apple". It works only if Apple's email arrives and isn't filtered.

**Recommendation:** Route A as the main route, with Route B as an extra only if the owner wants it. If both are used, email 2 must carry the public link so nobody depends on Apple's email.

## Voice

Jamaal is calm, supportive and non-judgmental. It never nags, never counts down, and has no urgency. No exclamation marks, no "don't miss out", no streaks or scores. Short sentences. The tagline is **"One list. Just today. Beautifully ordered."** Write to one person, not "users".

## Look

Use the app's own design tokens (the full set is in [ThreadsKit usage](threadskit-usage) and the [Design v4 handoff](README)). The email must work in a light and a dark client.

| Role | Light | Dark |
|---|---|---|
| Ground | `#EFF4F0` | `#12303F` |
| Card (the content panel) | `#FFFFFF` | white at 5% |
| Titles (ink) | `#0A3A53` | `#E7F1F4` |
| Body (ink2) | `#14506E` | `#BCD3DA` |
| Labels and small print (ink3) | `#3F6E80` | `#8FAAB4` |
| **The one button** (terracotta) | `#9A4F2E`, text `#EAF3F6` | `#DDA080`, text `#16242E` |
| Done / accent line | `#1F6A58` | `#8FCBB8` |
| Hairline | `#0A3A53` at 14% | `#E7F1F4` at 14% |

- **One filled button only, in terracotta.** Everything else is a text link in the teal accent. No red anywhere.
- **Type:** the app uses Fraunces for headlines (with the second half in *italic teal*, like "Four things, *gently paced.*"), Hanken Grotesk for text and JetBrains Mono for small labels. **Email clients can't be relied on to load fonts**, so specify a **fallback stack** (Georgia for the headline, the system sans for text, a monospace for labels) and make sure the design still looks right with only the fallbacks.
- **Imagery:** the app's screenshots and design frames are in `mockups/screens/` (Today, Night Planning, Habits, Anchors and the widgets in `8-widgets/`). Use at most one image per email, with alt text, and don't rely on it to carry meaning (many clients block images).

## Constraints (Resend and email in general)

- **600 px wide**, one column, readable at phone width with no horizontal scroll. Text at least 16 px; the button at least 44 px high.
- **Always send a plain-text version** with the same content and the full link written out.
- **HTML that survives clients:** table-based layout, inline styles, no scripts. Resend can send React Email components, so a React Email component is a good target for the template.
- **Dark mode:** supply real dark colours (`prefers-color-scheme`) and keep the logo and any image legible on both grounds.
- **Sender and reply:** from **Jamaal**, replies to **support@jamaal.app** (a mailbox the owner reads). The sending domain (`jamaal.app`) must be verified in Resend (SPF and DKIM) before the first send.
- **Footer on every email:** why they are getting it (they asked to hear about the beta), an **unsubscribe link**, and the sender's postal or contact details if the law where the list lives requires it. Keep it small and calm.
- **Links:** the TestFlight link and the article links are plain, visible links as well as buttons. Don't use link shorteners.

## The content, so nothing has to be invented

### Email 1: heads-up
- **Subject ideas:** "Jamaal's beta is nearly here" · "A quiet heads-up about the Jamaal beta".
- **Hero:** "The beta is *nearly here.*"
- **Say:** TestFlight, Apple's way of testing apps before release, opens very soon. When it does you'll get the way to install it. (Route A: *an email from us with a link*. Route B: *an email from Apple, from TestFlight*.) It's free and there's nothing to pay for.
- **What you'll need:** an iPhone or iPad on **iOS or iPadOS 26 or later**, or a Mac on **macOS 26 or later** (the Mac installs through the TestFlight app on the Mac); an Apple ID; iCloud turned on if you want your lists on more than one device.
- **Links:** one or two of the how-to articles, as a taste.
- **No date.** "Very soon" and nothing more specific.

### Email 2: it's ready
- **Hero:** "Jamaal is *ready to try.*"
- **The three steps:** (1) install the free **TestFlight** app from the App Store; (2) open the link below on the same device; (3) tap **Accept**, then **Install**.
- **One button:** "Open in TestFlight" (the public link).
- **What to try first:** add a few tasks; make a habit and an Anchor; plan tomorrow in the evening; add the Today and Next Anchor widgets (on the Lock Screen too).
- **What the beta is:** the full app, nothing to pay for, no trial to count down.
- **Feedback:** *Settings → iCloud sync → Email support* opens a message to support@jamaal.app with some technical details filled in, or just reply to this email. Say plainly that what's filled in is the app's version and device and what it was doing, **never your tasks, notes or places**.

### Email 3: the how-to series (one link each, one short email each)
The article titles and the one-line promise for each, taken from how the app really works:
- **Night Planning:** a five-step evening ritual (look back at the day, decide what happens to what's left over, build tomorrow around what's fixed, check how full it is, close the day), and you can skip it any night without losing anything.
- **The Today list and your capacity:** one list for today, with how full the day is shown against the energy you chose, and no projects or tags.
- **Habits:** a grid of days, not streaks: some are done or not, some are counted, some are timed with a focus timer, and some are about *not* doing something.
- **Anchors:** the things your day moves around (prayer times, the school run, bin night): a window each, and you say whether you made it.
- **Widgets:** Today and Next Anchor on the Home Screen, Next Anchor on the Lock Screen.
- Each article URL lives on jamaal.app (the owner supplies them); the email only needs a title, one sentence and one link.

### Email 4: a new build (optional)
A short "what changed" list in plain words, and the feedback line again.

## True at send time (check before each send)

Say only what is true on the day. In particular:
- **"Jamaal doesn't collect your data"** is true **until** crash reporting ships; after that the honest line is that reports contain no tasks, notes or places and can be turned off. The App Store privacy answers and the [privacy page](https://jamaal.app/privacy) must say the same as the email.
- **"Nothing to pay for"** is true for the beta only; don't imply it is free forever. The App Store version has a 14-day trial and then a subscription.
- **No date** for the release, and no promise of a feature that isn't built.

## Deliverables

The template for the four emails in light and dark, the hero treatments for each, the plain-text version of email 2, and a React Email (or plain HTML) source Resend can send. Keep the first two emails as the priority.
