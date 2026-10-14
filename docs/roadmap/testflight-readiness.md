# TestFlight readiness

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

The code is ready (#229); these are the steps that need the account, in order:
1. In Xcode, set the **paid team** on the app target. The Team ID may differ from the Personal Team's: the Mac group identifier follows `$(TeamIdentifierPrefix)` by itself.
2. **Add the App Groups capability** to the app (Xcode registers `group.dev.fhdamd.Jamaal`, and the team-prefixed id on the Mac). Add `com.apple.security.application-groups` with `$(APP_GROUP_ID)` to `Jamaal-Mac.entitlements`: it is left out until now because the free team can't sign it. `Jamaal.entitlements` (iOS Release) already lists it.
3. **Create the iCloud container** `iCloud.dev.fhdamd.Jamaal`, list it in `Jamaal.entitlements`, and **point Debug back at the full entitlements** (iOS and Mac).
4. **Turn CloudKit on:** `cloudKitDatabase: .private("iCloud.dev.fhdamd.Jamaal")` in `AppEngine.groupConfiguration` (a group store) and the fallback container.
5. **Check:** a launch creates the store at `<group>/Library/Application Support/Jamaal.store` (on the simulator, under the app group's folder; on the Mac, `~/Library/Group Containers/<id>/Library/Application Support/`) and the old `default.store` is no longer written.

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
