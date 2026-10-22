//
//  BuildChannel.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// Which build this is: Xcode (debug), a TestFlight beta, or the App Store. It decides whether a tester keeps full access and never
/// starts the trial (a beta), or the real 14-day trial applies (#291, #310).
///
/// The receipt can't always say. On iOS a TestFlight receipt is named `sandboxReceipt`, but **on macOS it is just `receipt`, like an
/// App Store build**, so StoreKit's environment is what decides (`Storefront` asks for it and `record`s the answer on the device).
/// Until it has answered, iOS goes by the receipt and the Mac assumes a beta: the safe side, because it gives full access and
/// doesn't start the trial, where assuming the App Store would start a tester's trial before the release.
nonisolated enum BuildChannel: Equatable {
    case debug, testFlight, appStore

    private static let cacheKey = "storeEnvironment"

    nonisolated static func resolve(isDebug: Bool, cachedEnvironment: String?, receiptName: String?, isMac: Bool) -> BuildChannel {
        if isDebug { return .debug }
        if let cachedEnvironment, let environment = StoreEnvironment(rawValue: cachedEnvironment) { return environment.channel }
        if receiptName == "sandboxReceipt" { return .testFlight }
        return isMac ? .testFlight : .appStore
    }

    /// This build, from what StoreKit last said and the receipt.
    nonisolated static var current: BuildChannel {
        #if DEBUG
        let isDebug = true
        #else
        let isDebug = false
        #endif
        #if os(macOS)
        let isMac = true
        #else
        let isMac = false
        #endif
        return resolve(
            isDebug: isDebug, cachedEnvironment: UserDefaults.standard.string(forKey: cacheKey),
            receiptName: Bundle.main.appStoreReceiptURL?.lastPathComponent, isMac: isMac)
    }

    /// Keeps StoreKit's answer on this device, so the next launch, and an offline one, already knows.
    nonisolated static func record(_ environment: StoreEnvironment) {
        UserDefaults.standard.set(environment.rawValue, forKey: cacheKey)
    }

    nonisolated var diagnosticChannel: DiagnosticEnvironment.Channel {
        switch self {
        case .debug: .debug
        case .testFlight: .testFlight
        case .appStore: .appStore
        }
    }
}

/// Where StoreKit says the app is running: a TestFlight build is `sandbox`.
nonisolated enum StoreEnvironment: String {
    case production, sandbox, xcode

    nonisolated var channel: BuildChannel {
        switch self {
        case .production: .appStore
        case .sandbox: .testFlight
        case .xcode: .debug
        }
    }
}
