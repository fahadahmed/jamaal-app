# TestFlight readiness

> How builds are made and sent from here on (Xcode Cloud, tag-driven) is in [Release process](release-process).


The plan agreed on 11 Oct 2026: the **first TestFlight build around 18 Oct** with what is solid (the App Group, the store move and CloudKit sync on real devices, the widget extension if it fits), and **purchases and the App Store listing in the next build**. The paid Apple Developer Programme is expected around **14 Oct**. This page is the checklist for that build; tick things off as they land.

## Ready now (no programme needed)

- [x] **Bundle id** `dev.fhdamd.Jamaal`; version **1.0 (build 1)**.
- [x] **iOS app icon:** default, dark and tinted, 1024 px, in `AppIcon.appiconset`.
- [x] **Privacy manifest** (`Jamaal/PrivacyInfo.xcprivacy`, ships in the iOS and Mac builds): no tracking, no data collected by the developer, and `UserDefaults` declared with reason `CA92.1` (the app reads and writes only its own preferences). Apple requires a declaration for that API. **Add to it when a dependency or a new feature uses another listed API** (file timestamps, disk space, system boot time, active keyboards) or any analytics.
- [x] **Export compliance:** `ITSAppUsesNonExemptEncryption` is `NO` (the app uses only the system's encryption: HTTPS, CloudKit and StoreKit), so TestFlight doesn't ask on every build. This is a statement to Apple; if the app ever ships its own cryptography, change it.
- [x] **App category** `public.app-category.productivity` (the Mac App Store requires one).
- [x] **Location wording:** "Jamaal uses your location to work out prayer times for where you are. It checks only while the app is open."
- [x] **Mac sandbox** entitlements (`Jamaal-Mac.entitlements`: app sandbox, network client, location, user-selected files).
- [x] **`jamaal://` scheme** registered (widgets will use it).

## Switch-on steps once the programme is active

The paid programme is active (15 Oct 2026): Xcode shows the Individual team `Y395QDPS3G` as paid, the same ID as the free Personal Team, so the project's `DEVELOPMENT_TEAM` and the Mac group identifier needed no change. Progress (#239):
1. [x] **Paid team on the targets:** nothing to change (same Team ID).
2. [x] **App Groups:** `com.apple.security.application-groups` with `$(APP_GROUP_ID)` is in `Jamaal.entitlements`, `Jamaal-Mac.entitlements`, `JamaalWidgets.entitlements` and `JamaalWidgets-Mac.entitlements`. **Registered (15 Oct 2026)** by a signed `xcodebuild -allowProvisioningUpdates` build for iOS: provisioning profiles exist for `dev.fhdamd.Jamaal` and `dev.fhdamd.Jamaal.Widgets`, and the signed app and widget both carry `group.dev.fhdamd.Jamaal`. **Mac (15 Oct 2026, #249):** a signed `xcodebuild -allowProvisioningUpdates` build for macOS registered this Mac as a development device and created the Mac profile for `dev.fhdamd.Jamaal`; the signed Mac app carries the sandbox, `Y395QDPS3G.dev.fhdamd.Jamaal` (the Mac's team-prefixed group), the iCloud container with CloudKit, push, network client, location and user-selected files, and the signature verifies; the widget carries the sandbox and the group. The Mac app launches without crashing. **Still to check by eye:** that your iPad and iPhone data arrives in the Mac app (it needs the Mac signed in to iCloud), and the Mac widget on the desktop.
3. [x] **iCloud container** `iCloud.dev.fhdamd.Jamaal` is listed (with CloudKit and push) in the iOS and Mac entitlements, **Debug uses the full entitlements**, and the signed iOS app carries the container, CloudKit and `aps-environment = development`.
4. [x] **CloudKit is on (#243):** the store opens with `cloudKitDatabase: .private("iCloud.dev.fhdamd.Jamaal")` whenever the app is signed with its App Group (`SyncMode`); tests, previews, unsigned builds, CI and in-memory stores stay local, and the debug argument `-JamaalNoCloudKit` turns it off to rule sync out. Checked on a **signed simulator**: the container opened, CloudKit mirroring set up (so the models are CloudKit-compatible) and the only error was "no iCloud account" (the simulator isn't signed in). **Still to check on two real devices** on one Apple ID: a task added on one appears on the other. The development schema is created in the **Development** environment on first use; **deploy it to Production before any TestFlight build**.
5. [x] **Checked on the iPhone simulator (signed):** the store is `<group>/Library/Application Support/Jamaal.store` and the app's own folder holds no `default.store`. **Still to check** on a real iPhone and the Mac (`~/Library/Group Containers/<id>/Library/Application Support/`). The location rule: `<group>/Library/Application Support/Jamaal.store` (on the Mac, `~/Library/Group Containers/<id>/Library/Application Support/`), and the old `default.store` no longer written.

## The beta is open (25 Oct 2026)

- **Build 4** (tag `beta-1.0-4`) is live in the public group *Jamaal Public Users*, with the public link.
- **15 early testers** were added to the external group (Apple emails each an invitation) and everyone on the list was sent the **Resend email** with the public link, through a Broadcast to an Audience (unsubscribe handled by Resend; replies go to support@jamaal.app).
- **Live on jamaal.app:** the privacy page (updated for TestFlight, location, and Email support), the journal's five new articles and the earlier two, and the sending domain verified in Resend.

**The first week**
- **Each day:** the testers' status, sessions and crashes in App Store Connect (TestFlight), the TestFlight feedback and screenshots, and `support@jamaal.app`. Reply to a tester who writes the same day.
- **What to read in a Share details report:** the *App* line says *TestFlight*, *Last problem* says none (or a hint), the *Records* counts look sane, and no line holds a title.
- **Triage:** a crash or a lost-data report first, then a sync problem (check the Production schema lists all 14 `CD_` types), then something confusing, then a request.
- **Before a new build:** merge, let CI go green, then tag `beta-1.0-N` on that commit (see the [release process](release-process), including the fallback when a tag is missed).
- **After the first week:** decide the Sentry questions, do the VoiceOver pass, and raise the tester limit if it is going well.

## Where it stands (21 Oct 2026)

**Done**
- [x] **Paid programme, App Group, iCloud container and CloudKit sync**, checked across the iPhone, iPad and Mac: Anchors, a running timer and a habit's minutes all arrive within seconds.
- [x] **CloudKit schema deployed from Development to Production.** From here on, model changes must be additive and the schema is deployed again before the next tag (see the [release process](release-process)).
- [x] **App Store Connect app record** (one record for iPhone, iPad and Mac, `dev.fhdamd.Jamaal`).
- [x] **Widgets:** Next Anchor (small, and the three Lock Screen sizes on iOS) and Today (small, medium, large), on iPhone, iPad and Mac. The widget extension builds for the Mac too.
- [x] **Mac app icon** (an Icon Composer file for the Mac) and the iOS icons.
- [x] **Release builds** of the iOS and Mac apps compile (unsigned); signing is done by Xcode Cloud.
- [x] **Support and privacy pages** (https://jamaal.app/support and /privacy) load.
- [x] **Xcode Cloud is connected** to the repository (it created a *Default* workflow that builds on every merge; it needs to be turned into the two tag-triggered workflows below).
- [x] **A beta keeps full access after 14 days** (a TestFlight build never goes read-only, Settings shows *Beta · full access*), and **a beta never starts the trial**, so the App Store version's 14 days begin on each person's first launch of it (#291).
- [x] **Diagnostics:** an on-device event log and *Share details* (Settings → iCloud sync). Sentry is planned, not built ([Observability and debugging](../architecture/observability)).

**Waiting on you**
- [ ] **Xcode Cloud workflows:** edit *Default* into **TestFlight beta** (tags starting `beta-`, Archive iOS and macOS, post-action to TestFlight) and create **App Store release** (tags starting `v`). Steps in the [release process](release-process#one-time-setup).
- [x] **TestFlight external group** *Jamaal Public Users* with the public link and the test details saved; build 2 (made with *App Store Connect* distribution) is **waiting for Beta App Review**.
- [x] **Support address, age rating and the URLs (21 Oct 2026):** support is **support@jamaal.app** (a mailbox you read), the age rating is **4+** (not the Kids category), and the privacy-policy and support URLs are entered. **Still to enter in App Store Connect:** the **privacy answers**, which stay **"Data Not Collected"** until Sentry ships (then *Data Not Linked to You: Diagnostics*, see [Observability and debugging](../architecture/observability#what-changes-for-privacy-when-layer-4-ships)).
- [ ] **Sentry decisions:** the plan and region (EU proposed), and whether the reporting switch is on by default in TestFlight builds.
- [ ] **VoiceOver pass** before the public link goes out (not needed for an invite-only first beta).
- [ ] Install the latest build on the **iPad**.

**After the first TestFlight install (check each, on two devices if you can, since a TestFlight build syncs through the Production iCloud, separate from the Development one your own builds use)**
- [ ] **Settings → Subscription** says *Beta · full access*; no trial banner or paywall appears on Today.
- [ ] **Settings → iCloud sync → Share details** says the build is *TestFlight*, shows the version and build, and sync is on with no problem listed.
- [ ] **Sync:** add a task, mark an Anchor done, and finish a habit timer on one device; the others show the same within about 20 seconds (and the habit's day total matches).
- [ ] **Widgets:** add Next Anchor (small and the Lock Screen sizes) and Today (small, medium, large); each shows today's data and opens the app.
- [ ] **Notifications:** the permission prompt appears when asked, and the evening Night Planning reminder arrives at the chosen time.
- [ ] **Prayer times:** the place search and the times work (this uses the location permission).
- [ ] **Night Planning**, a **focus session** and **Export my data** each work end to end.
- [ ] Nothing in **Share details** contains a title, a note or a place.

**Mine, once the workflows exist**
- [ ] Push `beta-1.0-1` on a tested commit and check the run: the scheme is found, the build number comes from Xcode Cloud, the iOS and Mac builds upload.
- [ ] Install from TestFlight and check, on the **Production** iCloud environment, that Settings reads *Beta · full access* and that sync works across two devices, **before** sharing the link.
- [ ] **Beta App Review notes** for the first external build: the beta has full access with no sign-in and no payment, and subscriptions aren't on yet (an App Store build uses the app-managed 14-day trial, then read-only).
- [ ] Sentry (slice 4) once the decisions are made.

**Known and not blocking the first beta**
- Widgets read the trial as if it were still running, because the subscription answer isn't shared with the extension yet. A beta never reaches read-only, so this only matters for the App Store build (the widgets' *View only* note).
- The Mac's pill sizes and the other screens that still use the system's segmented pickers (Settings levels, Appearance, Anchor and prayer forms, onboarding) have not had a visual pass on a Mac.

## Not for the first build

Subscriptions ($2.99 a month, $24.99 a year, one subscription group, and sandbox testers): the next build, set up in App Store Connect first. The App Store listing text and screenshots (the next build). Sounds and animation (not decided), the watch app (v1.1), Live Activity and interactive widgets (v1.1).
