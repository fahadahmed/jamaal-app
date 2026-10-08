# ADR 0003: Widgets in v1, a watch companion in v1.1, and the store in an App Group

**Status:** accepted by the owner, 8 October 2026.

## Context

[App flow](../../journeys/app-flow) had decided that widgets, App Intents, a share extension and quick capture were **v1.1**, so v1 could stay focused. Since then the launch has become **iPhone, iPad and Mac together**, and the owner wants widgets in v1: a "Today" app belongs on the Home Screen, the Lock Screen and the desktop, and the January resolution surge is when it would earn its keep. The owner also owns an Apple Watch and wants a watch app.

A widget is a separate program with its own private storage. It cannot open the app's database file. To show real data it must read the **same store**, which means the store has to live in an **App Group container** (a folder both the app and its extensions may open).

## Decision

1. **Widgets are in v1:** *Next Anchor* and *Today*, on iPhone, iPad and Mac, with Lock Screen accessory widgets. Tapping one opens the app. Full scope in [Widgets and the watch](../widgets-and-watch).
2. **Still v1.1:** interactive widgets and App Intents (Siri, Shortcuts), Control Center controls, the share extension, quick capture, and Live Activity / Dynamic Island.
3. **The watch:** a **companion watchOS app in v1.1** (Today with mark done, Anchors, the habit counter, the focus timer, and complications). It is fed by a small, Codable `WidgetSnapshot` over WatchConnectivity; the iPhone keeps owning the store and the watch queues its actions back to it. In v1 the watch gets only what comes free: mirrored notifications and, likely, the Lock Screen widgets in the Smart Stack. An independent watch app with its own CloudKit store is a later option.
4. **The SwiftData store lives in an App Group container from the first CloudKit-enabled build.** It is done in the same change as the CloudKit container set-up, once the paid programme is active (about 14 October 2026).
5. **`WidgetSnapshot`** is a pure, `Codable`, device-independent read model in JamaalCore, built from the engine's existing reads. The iPhone and iPad widgets, the Mac widgets and the watch all use it.

## Why

- Moving the store *after* launch is a data migration on real people's devices (copy the database and its journal files, verify, delete the old one, survive an interruption, on three platforms, across versions). A bug there loses someone's planner. Moving it *before* any user has data costs almost nothing.
- Doing it together with CloudKit avoids migrating each synced device separately later.
- Making the snapshot Codable now means the watch needs no second data model later.
- It is harmless if a widget slips: the store is simply in the shared folder from the start.

## Consequences

- The paid programme is needed first (App Groups, the extension's App ID, the watch's device slot). Until then the work is docs, the Design brief, and the JamaalCore snapshot and timeline logic, which need no entitlements.
- The widget extension is one multiplatform target (iOS and macOS). On the Mac the App Group identifier has a different form (team-prefixed) from iOS.
- Design has drawn no widget or watch frames: see the [brief](../../design/widgets-and-watch-brief).
- Widgets have a small memory budget and a limited number of refreshes a day, so they read little and update at the moments that matter, not every minute.
- v1's schedule gains roughly a week to ten days of widget work after the paid programme lands, ahead of TestFlight.

## Alternatives considered

- **Widgets in v1.1, store untouched:** simplest now, but forces the migration on real users later. Rejected.
- **Widgets that read through their own CloudKit sync:** a second sync client in the extension for no benefit. Rejected.
- **An independent watch app in v1:** brings the whole engine, conflict handling and migrations onto a fourth syncing device. Later, if people want it.
