//
//  BuildChannelTests.swift
//  JamaalTests
//

import Testing
import JamaalCore
@testable import Jamaal

/// How a running build knows if it is a TestFlight beta (#310). On iOS a TestFlight receipt is named `sandboxReceipt`; **on macOS it is
/// just `receipt`, the same as an App Store build**, so the receipt can't tell them apart there and the Mac TestFlight build used to
/// think it was the App Store build (no beta full access, and it started the trial). StoreKit's environment is the answer, kept on the
/// device once known; until then the safe guess.
struct BuildChannelTests {

    private func channel(debug: Bool = false, cached: String? = nil, receipt: String? = nil, mac: Bool = false, distribution: String? = nil) -> BuildChannel {
        BuildChannel.resolve(isDebug: debug, cachedEnvironment: cached, receiptName: receipt, isMac: mac, distribution: distribution)
    }

    @Test func aDebugBuildIsDebugWhateverElseSaysSo() {
        #expect(channel(debug: true, cached: "production", receipt: "receipt") == .debug)
    }

    @Test func whatStoreKitSaidWinsOverTheReceipt() {
        #expect(channel(cached: "sandbox", receipt: "receipt", mac: true) == .testFlight)
        #expect(channel(cached: "production", receipt: "sandboxReceipt") == .appStore)
    }

    @Test func anXcodeEnvironmentIsADebugBuild() {
        #expect(channel(cached: "xcode") == .debug)
    }

    @Test func onIOSTheSandboxReceiptMeansTestFlightBeforeStoreKitHasAnswered() {
        #expect(channel(receipt: "sandboxReceipt") == .testFlight)
        #expect(channel(receipt: "receipt") == .appStore)
        #expect(channel(receipt: nil) == .appStore)
    }

    @Test func onTheMacUntilStoreKitHasAnsweredItAssumesABetaTheSafeSide() {
        // A TestFlight and an App Store receipt look the same on macOS. Assuming a beta means full access and the trial isn't started;
        // assuming the App Store would start a tester's trial before the release.
        #expect(channel(receipt: "receipt", mac: true) == .testFlight)
        #expect(channel(receipt: nil, mac: true) == .testFlight)
    }

    /// App Review runs apps in the sandbox, as TestFlight does, so StoreKit's environment can't tell a build sent for review from a beta (#346).
    /// A build made from a `v<version>` tag says so itself, in its Info.plist, and that wins.
    @Test func aBuildMarkedAsAnAppStoreBuildIsOneEvenInTheSandbox() {
        #expect(channel(cached: "sandbox", receipt: "sandboxReceipt", distribution: "appStore") == .appStore)
        #expect(channel(cached: nil, receipt: "sandboxReceipt", distribution: "appStore") == .appStore)
        #expect(channel(cached: "sandbox", receipt: "receipt", mac: true, distribution: "appStore") == .appStore, "and on the Mac, where it would have assumed a beta")
    }

    @Test func theMarkerNeverMakesADebugBuildAnAppStoreBuild() {
        #expect(channel(debug: true, distribution: "appStore") == .debug)
    }

    @Test func noMarkerOrAnotherValueLeavesTheRuntimeRulesAlone() {
        #expect(channel(cached: "sandbox", distribution: nil) == .testFlight)
        #expect(channel(cached: "sandbox", distribution: "beta") == .testFlight)
        #expect(channel(cached: "sandbox", distribution: "") == .testFlight)
        #expect(channel(cached: "production", distribution: "beta") == .appStore)
    }

    @Test func theEnvironmentsMapToTheChannels() {
        #expect(StoreEnvironment.sandbox.channel == .testFlight)
        #expect(StoreEnvironment.production.channel == .appStore)
        #expect(StoreEnvironment.xcode.channel == .debug)
    }
}
