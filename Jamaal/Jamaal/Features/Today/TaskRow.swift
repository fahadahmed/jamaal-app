//
//  TaskRow.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens
import JamaalCore

/// A task on Today: the tick, the title, and a quiet second line (how often it has slipped, the estimate, the
/// category with its dot). Importance is never shown. Done rows are struck through with the time.
struct TaskRow: View {
    @Environment(\.threads) private var threads
    let task: TaskItem
    let doneTime: String?
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: ThreadsSpace.row) {
            Button(action: onToggle) { CheckCircle(isDone: task.isCompleted) }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isCompleted ? "Mark \(task.title) not done" : "Mark \(task.title) done")
            VStack(alignment: .leading, spacing: ThreadsSpace.hair) {
                Text(task.title)
                    .threadsType(.row)
                    .strikethrough(task.isCompleted, color: threads.ink3)
                    .foregroundStyle(task.isCompleted ? threads.ink3 : threads.ink)
                metaLine
            }
            .padding(.top, 9)
            Spacer(minLength: 0)
        }
        .padding(.vertical, ThreadsSpace.hair)
        .accessibilityElement(children: .contain)
    }

    private var metaLine: some View {
        HStack(spacing: ThreadsSpace.tight) {
            let parts = task.isCompleted
                ? [doneTime.map { "Done \($0)" }].compactMap { $0 }
                : TodayCopy.taskMeta(deferrals: task.deferralCount, effortMinutes: task.effortMinutes)
            if !parts.isEmpty { Text(parts.joined(separator: " · ")) }
            if let category = task.category, !category.name.isEmpty {
                HStack(spacing: 6) {
                    Circle().fill(JamaalPalette.categoryColor(forKey: category.colorKey)).frame(width: 8, height: 8)
                    Text(category.name)
                }
            }
        }
        .threadsType(.meta)
        .foregroundStyle(threads.ink2)
    }
}
