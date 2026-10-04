//
//  OneOffAnchor.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// A one-off Anchor on the Add sheet (AN-08): a title, a day, a window, how long it takes, reminders. Writing it is
/// JamaalCore's `AnchorEditing.createOneOff`.
struct OneOffAnchorDraft {
    var title = ""
    var day: CalendarDate
    var startMinute: Int
    var endMinute: Int
    var takes: Int?
    var remindAtStart = false
    var remindBeforeEnd: Int?
    let today: CalendarDate

    /// The next whole hour for an hour, kept within the day.
    init(today: CalendarDate, nowMinute: Int) {
        self.today = today
        day = today
        let start = min(22 * 60, (nowMinute / 60 + 1) * 60)
        startMinute = start
        endMinute = start + 60
    }

    var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Moving the start past the end pushes the end an hour on; an earlier start leaves it.
    mutating func setStart(_ minute: Int) {
        startMinute = minute
        if endMinute <= startMinute { endMinute = min(1439, startMinute + 60) }
    }

    /// An end can't come before the start: it keeps at least fifteen minutes.
    mutating func setEnd(_ minute: Int) {
        endMinute = max(minute, min(1439, startMinute + 15))
    }

    var buttonTitle: String {
        var form = AddTaskForm(today: today, firstWeekdayISO: 1)
        form.choose(day)
        return form.buttonTitle.replacingOccurrences(of: "Add to someday", with: "Add for today")
    }
}
