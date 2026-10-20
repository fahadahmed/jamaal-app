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

## Needs the paid programme

- [ ] Enrol, then **point Debug back at the full entitlements** (`Jamaal.entitlements`: push and iCloud) and register the **App IDs** with iCloud/CloudKit, Push and **App Groups** for the app (and, later, the widget extension).
- [ ] **One change:** the App Group, moving the SwiftData store into it, and the CloudKit container (so no user ever migrates).
- [ ] **CloudKit:** create the container; run real-device sync between iPhone, iPad and Mac; work through "Welcome back", ST-06 and the G-80 spike. **Before any build outside your own devices, deploy the CloudKit schema from Development to Production** (a TestFlight build uses Production; a schema that was never deployed makes sync fail).
- [ ] **App Store Connect:** create the app record (one record for iPhone, iPad and Mac with the same bundle id); an internal TestFlight group with you in it.
- [ ] **Signing and upload:** an archive with the Release configuration, the Apple Distribution certificate (and the Mac App Distribution and installer certificates for the Mac build), then upload. **Each upload needs a higher build number** (decide: bump by hand, or set it from the CI run number).
- [ ] **Widget extension** (Next Anchor, Today, Lock Screen, Mac), if it fits before the 18th.
- [ ] **Subscriptions** ($2.99 a month, $24.99 a year, in one subscription group) and sandbox testers: **the next build, not this one.** Keep purchases off, or behind a debug switch, in the first build.

## Needs your decision

- [ ] **Mac app icon.** The asset set has iOS icons only. On macOS 26 an icon that isn't made with **Icon Composer** (a single `.icon` file for every platform) is shown inside a plain rounded plate, which looks unfinished. Options: make an Icon Composer file from the current art (needs Design to supply layers), or ship a plain Mac icon set for now. This blocks nothing for TestFlight; it matters before the Mac App Store.
- [ ] **App Store privacy answers.** My reading: "Data Not Collected" (sync stays in the user's own iCloud, location stays on the device, purchases are handled by Apple). Confirm once sync is real, and that no analytics are added.
- [ ] **Age rating, support URL and privacy-policy URL.** The policy must say what `YourDataScreen` says: what is kept, where, and how to export or delete it.
- [ ] **Beta App Review notes** for the first external build: how the app-managed trial and the read-only state work (no sign-in, no payment up front).

## Not for the first build

Sounds and animation (not decided), the watch app (v1.1), Live Activity and interactive widgets (v1.1), the App Store listing text and screenshots (the next build).
