//
//  RepeatScopeSheet.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens
import JamaalCore

/// TK-07: a repeating task is asked once per visit whether a change is for this one or for every one after. The change is only made once
/// it has been answered, so Cancel (or swiping the sheet away) leaves the task exactly as it was.
struct RepeatScopeSheet: View {
    @Environment(\.threads) private var threads
    let eyebrow: String
    let sentence: String
    let laterTitle: String
    let onlyTitle: String
    let onLater: () -> Void
    let onOnly: () -> Void
    let onCancel: () -> Void

    #if os(macOS)
    private static let width: CGFloat = 480
    #else
    private static let width: CGFloat = 540
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            Text(eyebrow).threadsType(.label).foregroundStyle(threads.ink2)
            // Smaller than a page's headline, so the two lines of the question stay two lines in a half-height sheet.
            VStack(alignment: .leading, spacing: 0) {
                Text(TaskEditCopy.scopeHero.0).threadsType(.display(.compact)).foregroundStyle(threads.ink)
                Text(TaskEditCopy.scopeHero.1)
                    .font(.custom(ThreadsType.displayItalicFontName, size: 28, relativeTo: .title2)).foregroundStyle(threads.accent)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Text(sentence).threadsType(.lede).foregroundStyle(threads.ink2)
            VStack(spacing: ThreadsSpace.tight) {
                Button(action: onLater) {
                    Text(laterTitle).threadsType(.row).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra))
                }
                .accessibilityIdentifier("scopeLater")
                Button(action: onOnly) {
                    Text(onlyTitle).threadsType(.row).foregroundStyle(threads.ink)
                        .frame(maxWidth: .infinity, minHeight: 56).overlay(Capsule().strokeBorder(threads.line2, lineWidth: 1))
                }
                .accessibilityIdentifier("scopeOnly")
                Button(action: onCancel) {
                    Text(TaskEditCopy.scopeCancel).threadsType(.row).foregroundStyle(threads.ink)
                        .frame(maxWidth: .infinity, minHeight: ThreadsHit.minimum)
                }
                .accessibilityIdentifier("scopeCancel")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.top, ThreadsSpace.section)
        .padding(.bottom, ThreadsSpace.row)
        // A centred sheet 540 pt wide on an iPad and 480 on a Mac; a bottom sheet on a phone.
        .frame(maxWidth: Self.width)
        .frame(maxWidth: .infinity)
        .background(threads.app)
        .presentationDetents([.height(440), .large])
        .presentationSizing(.fitted)
        .presentationDragIndicator(.visible)
    }
}
