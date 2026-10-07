//
//  YourDataScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore
#if canImport(UIKit)
import UIKit
#endif

/// Privacy and your data (ST-08): what is kept and where, Export my data (always available, subscribed or not), and
/// Delete my data behind two confirmations.
struct YourDataScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(ReminderCenter.self) private var reminders
    @State private var exported: ExportedFile?
    @State private var message: String?
    @State private var firstConfirmation = false
    @State private var secondConfirmation = false

    struct ExportedFile: Identifiable { let url: URL; var id: URL { url } }

    var body: some View {
        SettingsPage(title: "Your data") {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                Text(PrivacyCopy.statement).threadsType(.lede).foregroundStyle(threads.ink).accessibilityIdentifier("privacyStatement")
                VStack(spacing: ThreadsSpace.tight) {
                    Button(action: export) {
                        Text("Export my data").threadsType(.row).foregroundStyle(threads.ink)
                            .frame(maxWidth: .infinity, minHeight: 56).overlay(Capsule().strokeBorder(threads.ink, lineWidth: 1)).contentShape(Capsule())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("exportData")
                    Text(message ?? PrivacyCopy.exportNote).threadsType(.meta).foregroundStyle(threads.ink2).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).accessibilityIdentifier("exportMessage")
                }
                Divider().overlay(threads.line)
                VStack(spacing: ThreadsSpace.tight) {
                    Button { firstConfirmation = true } label: {
                        Text("Delete my data").threadsType(.row).foregroundStyle(threads.alert)
                            .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.alertSoft)).contentShape(Capsule())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("deleteData")
                    Text(PrivacyCopy.deleteNote).threadsType(.meta).foregroundStyle(threads.ink2).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                }
            }
        }
        #if canImport(UIKit)
        .sheet(item: $exported) { file in ActivityView(url: file.url).presentationDetents([.medium, .large]) }
        #endif
        .alert(PrivacyCopy.firstTitle, isPresented: $firstConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { secondConfirmation = true } }
        } message: { Text(PrivacyCopy.firstMessage) }
        .alert(PrivacyCopy.secondTitle, isPresented: $secondConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete everything", role: .destructive) { deleteEverything() }
        } message: { Text(PrivacyCopy.secondMessage) }
    }

    private func export() {
        do {
            let now = Date.now
            let data = try DataExport.json(in: context, now: now)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(PrivacyCopy.fileName(now))
            try data.write(to: url, options: .atomic)
            let records = try DataExport.records(in: context).values.reduce(0) { $0 + $1.count }
            message = PrivacyCopy.exported(records: records)
            exported = ExportedFile(url: url)
        } catch {
            message = "That couldn't be exported. Try again."
        }
    }

    /// Every record goes, the app starts again from first launch (onboarding is next), and no reminder stays scheduled.
    private func deleteEverything() {
        do {
            try DataReset.deleteEverything(in: context)
            try Seeding.ensureSeeded(in: context, now: .now)
            LastProcessedStore().day = nil
            reminders.scheduleReplan(in: context)
            message = PrivacyCopy.deleted
        } catch {
            message = "That couldn't be deleted. Nothing was lost; try again."
        }
    }
}

#if canImport(UIKit)
/// The system share sheet for the export file.
private struct ActivityView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
