//
//  CalendarDate+Picker.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// A `DatePicker` speaks in the person's own calendar: the day they tapped, at whatever time of day it is now.
/// `CalendarDate(storedDate:)` reads an instant as a **UTC** date, so in a time zone ahead of UTC a morning pick
/// would land on the day before. These read and write the picker's day by its local year, month and day.
extension CalendarDate {
    init(pickerDate: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: pickerDate)
        self = CalendarDate(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1) ?? CalendarDate(storedDate: pickerDate)
    }

    /// Noon on this day in `calendar`, which no time-zone offset can move to another day.
    func pickerDate(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? storedDate
    }
}
