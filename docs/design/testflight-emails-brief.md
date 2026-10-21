# Brief: the TestFlight email

A self-contained brief for Claude Design. **Status: decided with the owner, 21 Oct 2026.** It covers **one email**, sent through **Resend** to the people who asked to hear about the beta, to tell them the beta is open and how to get the most from it. It is designed on **Threads Design System v2** (ThreadsKit 2.0.0, the system the app itself uses). It does **not** cover the emails Apple sends.

## Decisions

- **One email**, with everything in it. No series.
- **The public link, not Apple's invitation.** The email carries the TestFlight public link; the person taps it, TestFlight opens, they accept and install. **Apple sends no email** in this route (so the email must not say "expect an email from Apple"). This is the dependable route: an Apple invitation email failed to arrive for an internal tester.
- **The Threads Design System v2.** Use the Threads v2 tokens and components (the Claude Design project for Threads v2, with the app's `JamaalPalette` as its only palette, listed below as a check). Don't invent colours or a new type scale.

## What you are designing

One email that does five jobs, in this order, on a calm single column:

1. **Say the beta is open** (a hero line and one sentence).
2. **Show how to install** (the one button, then three steps).
3. **Say what to try first** (a short list).
4. **Point to the how-to articles** (a few links, one line each).
5. **Say how to send feedback** (and what is never included).

Then a small footer. Make the **button the only loud thing**; everything after it is quiet and scannable, so a person who only reads the top still knows what to do.

## Not Apple's emails

TestFlight's own screens and emails are Apple's and **cannot be restyled**; only their text can be changed (the Beta App Description and the *What to Test* note, set in App Store Connect). Don't copy them. Our email should look clearly **from Jamaal**, and should say that when the link opens, **Apple's TestFlight app takes over** for the install, so the next screens will look like Apple's.

## Voice

Jamaal is calm, supportive and non-judgmental. It never nags, never counts down, and has no urgency. No exclamation marks, no "don't miss out", no streaks or scores. Short sentences. The tagline is **"One list. Just today. Beautifully ordered."** Write to one person, not "users".

## Look

Use **Threads Design System v2** (ThreadsKit 2.0.0; the full token set is in [ThreadsKit usage](threadskit-usage) and the [Design v4 handoff](README)). The table below is the app's palette on that system, as a check on what you build. The email must work in a light and a dark client.

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
- **Imagery:** the app's screenshots and design frames are in `mockups/screens/` (Today, Night Planning, Habits, Anchors and the widgets in `8-widgets/`). Use at most **one** image (for example the Today screen below the hero), with alt text, and don't rely on it to carry meaning (many clients block images).

## Constraints (Resend and email in general)

- **600 px wide**, one column, readable at phone width with no horizontal scroll. Text at least 16 px; the button at least 44 px high.
- **Always send a plain-text version** with the same content and the full link written out.
- **HTML that survives clients:** table-based layout, inline styles, no scripts. Resend can send React Email components, so a React Email component is a good target for the template.
- **Dark mode:** supply real dark colours (`prefers-color-scheme`) and keep the logo and any image legible on both grounds.
- **Sender and reply:** from **Jamaal**, replies to **support@jamaal.app** (a mailbox the owner reads). The sending domain (`jamaal.app`) must be verified in Resend (SPF and DKIM) before the first send.
- **Footer on every email:** why they are getting it (they asked to hear about the beta), an **unsubscribe link**, and the sender's postal or contact details if the law where the list lives requires it. Keep it small and calm.
- **Links:** the TestFlight link is the button **and** is written out in full below it as a plain link (some clients block buttons); the article links are plain links. Don't use link shorteners.

## The content, so nothing has to be invented

- **Subject ideas:** "Jamaal's beta is open" · "Try Jamaal: the beta is open". Preheader: "A calm daily planner. Free to try, nothing to pay."
- **Hero:** "The beta is *open.*" (the second word in italic teal, as in the app's headlines, e.g. "Four things, *gently paced.*"). Under it: one sentence. For example: "Jamaal is a calm daily planner: one list of what matters today. Here is how to try it."
- **The button:** "Open in TestFlight" (the public link).
- **Three steps under the button:**
  1. Install the free **TestFlight** app from the App Store (Apple's app for trying apps before release).
  2. Open the link above **on the same device**.
  3. Tap **Accept**, then **Install**.
- **What you'll need:** an iPhone or iPad on **iOS or iPadOS 26 or later**, or a Mac on **macOS 26 or later** (on a Mac the install goes through the TestFlight app on the Mac); an Apple ID; iCloud turned on if you want your lists on more than one device.
- **What the beta is:** the full app, nothing to pay for, no trial to count down.
- **What to try first:** add a few tasks; make a habit and an Anchor; plan tomorrow in the evening; add the Today and Next Anchor widgets (on the Lock Screen too). If you use more than one device, check changes show up on the others.
- **How to use it (the article links; the owner supplies the URLs on jamaal.app):** each is a title and one sentence.
  - **Night Planning:** a five-step evening ritual (look back at the day, decide what happens to what's left over, build tomorrow around what's fixed, check how full it is, close the day), and you can skip it any night without losing anything.
  - **The Today list and your capacity:** one list for today, with how full the day is shown against the energy you chose; no projects, no tags.
  - **Habits:** a grid of days, not streaks: some are done or not, some counted, some timed with a focus timer, and some are about *not* doing something.
  - **Anchors:** the things your day moves around (prayer times, the school run, bin night): a window each, and you say whether you made it.
  - **Widgets:** Today and Next Anchor on the Home Screen, and Next Anchor on the Lock Screen.
- **Feedback:** *Settings → iCloud sync → Email support* opens a message to support@jamaal.app with some technical details filled in, or just **reply to this email**. Say plainly that what's filled in is the app's version and device and what it was doing, **never your tasks, notes or places**.
- **A line of reassurance:** it is a beta, so things will change, and your notes on what confuses you are the most useful thing you can send.

## True at send time (check before each send)

Say only what is true on the day. In particular:
- **"Jamaal doesn't collect your data"** is true **until** crash reporting ships; after that the honest line is that reports contain no tasks, notes or places and can be turned off. The App Store privacy answers and the [privacy page](https://jamaal.app/privacy) must say the same as the email.
- **"Nothing to pay for"** is true for the beta only; don't imply it is free forever. The App Store version has a 14-day trial and then a subscription.
- **No date** for the release, and no promise of a feature that isn't built.

## Deliverables

The one email in **light and dark**, built from Threads Design System v2 components; the **plain-text version**; and a **React Email (or plain HTML) source** Resend can send. Also say which Threads v2 components and tokens it uses, so the template can be kept in step with the system.
