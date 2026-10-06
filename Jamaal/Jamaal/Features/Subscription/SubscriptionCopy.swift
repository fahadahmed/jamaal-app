//
//  SubscriptionCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The words around the trial and the subscription: calm, no countdown pressure, nothing that sounds like a threat.
enum SubscriptionCopy {
    private static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private static let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private static let numbers = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen"]

    /// "Saturday 24 May".
    static func longDate(_ date: CalendarDate) -> String { "\(weekdays[date.isoWeekday - 1]) \(date.day) \(months[date.month - 1])" }

    /// The last day of the trial: it ends at the rollover after day 14.
    static func lastTrialDay(start: CalendarDate) -> CalendarDate { start.addingDays(Trial.lengthDays - 1) }

    // MARK: Settings

    /// The Settings home row's value.
    static func homeValue(_ access: AccessState) -> String {
        switch access {
        case .trial(let daysLeft): "Trial · \(daysLeft) \(daysLeft == 1 ? "day" : "days") left"
        case .subscribed: "Subscribed"
        case .readOnly: "Trial ended"
        }
    }

    /// The Subscription screen: a small label and the plain sentence under it.
    static func status(_ access: AccessState, trialStart: CalendarDate?, renewsOn: String?) -> (label: String, line: String) {
        switch access {
        case .trial(let daysLeft):
            let left = daysLeft == 1 ? "Last day." : "\(daysLeft) days left."
            let ends = trialStart.map { " It ends on \(longDate(lastTrialDay(start: $0))); nothing is charged unless you subscribe." } ?? " Nothing is charged unless you subscribe."
            return ("FREE TRIAL", left + ends)
        case .subscribed:
            return ("SUBSCRIBED", renewsOn.map { "Renews on \($0). Thank you." } ?? "Thank you.")
        case .readOnly:
            return ("TRIAL ENDED", "Ticking off, logging habits, marking Anchors and the timer keep working. Subscribe to add and plan.")
        }
    }

    // MARK: Today banners

    static let readOnlyBanner = "The trial has ended. You can still tick things off, log habits, mark Anchors and run a timer. Adding and planning need a subscription."

    static func trialBanner(daysLeft: Int, trialStart: CalendarDate?) -> String {
        let tail = "Jamaal keeps working for the day, but adding and planning need a subscription."
        if daysLeft <= 1 { return "The trial ends today. After today, \(tail)" }
        let words = daysLeft < numbers.count ? numbers[daysLeft] : "\(daysLeft)"
        let after = trialStart.map { weekdays[lastTrialDay(start: $0).isoWeekday - 1] } ?? "then"
        return "\(words.prefix(1).uppercased() + words.dropFirst()) days left in the trial. After \(after), \(tail)"
    }

    // MARK: The paywall and the locked sheet

    static func paywallEyebrow(_ access: AccessState) -> String { access == .readOnly ? "THE TRIAL HAS ENDED" : "SUBSCRIBE" }
    static let paywallTitle = "Keep shaping your days."
    static let paywallBody = "Ticking off, logging habits, marking Anchors and the timer keep working. Adding, editing and Night Planning need a subscription."
    static func subscribeButton(_ plan: SubscriptionPlan) -> String { "Subscribe \(plan.title.lowercased())" }
    static let noPlans = "Plans aren't available right now. Check your connection and try again."
    static let lockedTitle = "Adding and planning need a subscription"
    static let lockedBody = "Everything already here keeps working for the day."
}
