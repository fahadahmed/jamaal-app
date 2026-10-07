//
//  RecoveryScreen.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// The store wouldn't open (SY-05): instead of crashing, say so plainly. Try again, or reset this device's copy behind two
/// confirmations. It never resets silently and never touches the iCloud copy.
struct RecoveryScreen: View {
    @Environment(\.threads) private var threads
    let stillFailing: Bool
    let onTryAgain: () -> Void
    let onReset: () -> Void
    @State private var firstConfirmation = false
    @State private var secondConfirmation = false
    private var device: String { ReminderCenter.deviceName }

    var body: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            Spacer()
            Text(PrivacyCopy.recoveryTitle(device: device)).threadsType(.display(.compact)).foregroundStyle(threads.ink).accessibilityAddTraits(.isHeader)
            Text(PrivacyCopy.recoveryBody(device: device)).threadsType(.lede).foregroundStyle(threads.ink2)
            if stillFailing {
                Text(PrivacyCopy.recoveryStillFailing(device: device)).threadsType(.body).foregroundStyle(threads.terra).accessibilityIdentifier("recoveryStillFailing")
            }
            Spacer()
            Button(action: onTryAgain) {
                Text("Try again").threadsType(.row).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra)).contentShape(Capsule())
            }
            .buttonStyle(.plain).accessibilityIdentifier("tryAgain")
            Button { firstConfirmation = true } label: {
                Text(PrivacyCopy.resetButton(device: device)).threadsType(.row).foregroundStyle(threads.alert)
                    .frame(maxWidth: .infinity, minHeight: 52).background(Capsule().fill(threads.alertSoft)).contentShape(Capsule())
            }
            .buttonStyle(.plain).accessibilityIdentifier("resetData")
        }
        .padding(.horizontal, ThreadsSpace.gutter).padding(.vertical, ThreadsSpace.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(threads.app.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recoveryScreen")
        .alert(PrivacyCopy.resetFirstTitle(device: device), isPresented: $firstConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { secondConfirmation = true } }
        } message: { Text(PrivacyCopy.resetFirstMessage(device: device)) }
        .alert(PrivacyCopy.resetSecondTitle, isPresented: $secondConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive, action: onReset)
        } message: { Text(PrivacyCopy.resetSecondMessage(device: device)) }
    }
}
