//
//  SidebarExtras.swift
//  Jamaal
//

import SwiftUI
import JamaalCore
import ThreadsTokens

/// Which category Today is showing. It is shared so the sidebar's Categories list and Today's own filter menu agree; like the
/// filter it replaces, it lives on this device only and clears at the rollover and on relaunch.
@Observable
final class TodayFilterState {
    var selectedID: UUID?

    /// Picking the category already showing puts the filter away.
    func toggle(_ id: UUID) { selectedID = selectedID == id ? nil : id }
}

/// The sidebar's header: "Jamaal" in the display italic.
struct SidebarWordmark: View {
    @Environment(\.threads) private var threads

    var body: some View {
        Text("Jamaal")
            .threadsType(.display(.compact)).italic()
            .foregroundStyle(threads.ink)
            .padding(.horizontal, ThreadsSpace.row)
            .padding(.vertical, ThreadsSpace.tight)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("sidebarWordmark")
    }
}

/// The sidebar's Categories list: each category's colour and name; picking one filters Today, picking it again clears it.
struct SidebarCategories: View {
    @Environment(\.threads) private var threads
    let categories: [TaskCategory]
    let selectedID: UUID?
    let onPick: (UUID) -> Void

    var body: some View {
        if !categories.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("CATEGORIES").threadsType(.label).foregroundStyle(threads.ink2)
                    .padding(.horizontal, ThreadsSpace.row).padding(.top, ThreadsSpace.row).padding(.bottom, ThreadsSpace.tight)
                    .accessibilityAddTraits(.isHeader)
                ForEach(categories, id: \.id) { category in
                    let isSelected = category.id == selectedID
                    Button { onPick(category.id) } label: {
                        HStack(spacing: ThreadsSpace.row) {
                            Circle().fill(JamaalPalette.categoryColor(forKey: category.colorKey)).frame(width: 9, height: 9)
                            Text(category.name).threadsType(.body).foregroundStyle(threads.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, ThreadsSpace.row)
                        .frame(minHeight: ThreadsHit.minimum)
                        .background { if isSelected { Capsule().fill(threads.card) } }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(category.name)
                    .accessibilityHint(isSelected ? "Shows all tasks again" : "Shows only these tasks on Today")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("sidebarCategory-\(category.name)")
                }
            }
        }
    }
}

/// The sidebar's bottom row: Plan tomorrow, the same way in as Today's moon.
struct SidebarPlanTomorrow: View {
    @Environment(\.threads) private var threads
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(threads.line)
            Button(action: action) {
                Label("Plan tomorrow", systemImage: "moon").threadsType(.body).foregroundStyle(threads.ink)
                    .frame(maxWidth: .infinity, minHeight: ThreadsHit.minimum, alignment: .leading)
                    .padding(.horizontal, ThreadsSpace.row)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sidebarPlanTomorrow")
        }
    }
}
