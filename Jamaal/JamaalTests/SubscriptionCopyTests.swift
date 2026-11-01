//
//  SubscriptionCopyTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

struct SubscriptionCopyTests {
    private let start = CalendarDate(year: 2026, month: 5, day: 11)!        // a Monday: the trial's last day is Sunday 24 May

    @Test func theTrialsLastDayIsTheFourteenthAndIsNamedInFull() {
        #expect(SubscriptionCopy.lastTrialDay(start: start) == CalendarDate(year: 2026, month: 5, day: 24))
        #expect(SubscriptionCopy.longDate(CalendarDate(year: 2026, month: 5, day: 24)!) == "Sunday 24 May")
    }

    @Test func theSettingsRowSaysWhereThingsStand() {
        #expect(SubscriptionCopy.homeValue(.trial(daysLeft: 9)) == "Trial · 9 days left")
        #expect(SubscriptionCopy.homeValue(.trial(daysLeft: 1)) == "Trial · 1 day left")
        #expect(SubscriptionCopy.homeValue(.subscribed) == "Subscribed")
        #expect(SubscriptionCopy.homeValue(.readOnly) == "Trial ended")
    }

    @Test func theSubscriptionScreenIsPlainInEachState() {
        let trial = SubscriptionCopy.status(.trial(daysLeft: 9), trialStart: start, renewsOn: nil)
        #expect(trial.label == "FREE TRIAL")
        #expect(trial.line == "9 days left. It ends on Sunday 24 May; nothing is charged unless you subscribe.")
        #expect(SubscriptionCopy.status(.trial(daysLeft: 1), trialStart: start, renewsOn: nil).line.hasPrefix("Last day."))
        #expect(SubscriptionCopy.status(.trial(daysLeft: 5), trialStart: nil, renewsOn: nil).line == "5 days left. Nothing is charged unless you subscribe.")
        #expect(SubscriptionCopy.status(.subscribed, trialStart: start, renewsOn: "14 October") == ("SUBSCRIBED", "Renews on 14 October. Thank you."))
        #expect(SubscriptionCopy.status(.subscribed, trialStart: start, renewsOn: nil).line == "Thank you.")
        let ended = SubscriptionCopy.status(.readOnly, trialStart: start, renewsOn: nil)
        #expect(ended.label == "TRIAL ENDED" && ended.line.contains("keep working"))
    }

    @Test func theTrialBannerNamesTheDayAndNeverShouts() {
        #expect(SubscriptionCopy.trialBanner(daysLeft: 2, trialStart: start)
                == "Two days left in the trial. After Sunday, Jamaal keeps working for the day, but adding and planning need a subscription.")
        #expect(SubscriptionCopy.trialBanner(daysLeft: 3, trialStart: start).hasPrefix("Three days left"))
        #expect(SubscriptionCopy.trialBanner(daysLeft: 1, trialStart: start).hasPrefix("The trial ends today."))
        #expect(SubscriptionCopy.trialBanner(daysLeft: 2, trialStart: nil).contains("After then,") == true)
        #expect(!SubscriptionCopy.readOnlyBanner.contains("!"))
        #expect(SubscriptionCopy.readOnlyBanner.hasPrefix("The trial has ended. You can still tick things off"))
    }

    @Test func thePaywallSaysWhatKeepsWorkingBeforeWhatDoesNot() {
        #expect(SubscriptionCopy.paywallEyebrow(.readOnly) == "THE TRIAL HAS ENDED")
        #expect(SubscriptionCopy.paywallEyebrow(.trial(daysLeft: 5)) == "SUBSCRIBE")
        #expect(SubscriptionCopy.paywallBody.hasPrefix("Ticking off, logging habits, marking Anchors and the timer keep working."))
        #expect(SubscriptionCopy.subscribeButton(.yearly) == "Subscribe yearly" && SubscriptionCopy.subscribeButton(.monthly) == "Subscribe monthly")
        #expect(SubscriptionPlan.allCases.map(\.title) == ["Yearly", "Monthly"])
    }

    @Test func aBetaBuildSaysItIsFullAccessForTesters() {
        #expect(SubscriptionCopy.homeValue(.subscribed, isBeta: true) == "Beta · full access")
        #expect(SubscriptionCopy.homeValue(.subscribed, isBeta: false) == "Subscribed")
        let status = SubscriptionCopy.status(.subscribed, trialStart: nil, renewsOn: nil, isBeta: true)
        #expect(status.label == "BETA")
        #expect(status.line.contains("Full access"))
        #expect(!status.line.contains("Renews"), "there is nothing to renew")
    }

    @Test func noPlansSaysToCheckTheConnectionInAnAppStoreBuild() {
        #expect(SubscriptionCopy.noPlans(isBeta: false) == "Plans aren't available right now. Check your connection and try again.")
    }

    @Test func noPlansInABetaSaysPlainlyThereAreNoSubscriptionsYet() {
        let text = SubscriptionCopy.noPlans(isBeta: true)
        #expect(text.contains("beta"))
        #expect(text.contains("Export my data"), "the way out is named")
        #expect(!text.contains("connection"), "it is not a connection problem, so it doesn't say it is")
    }

    // MARK: What App Review requires on a subscription screen (guideline 3.1.2)

    @Test func theRenewalTermsNameThePriceThePeriodAutoRenewalAndCancelling() {
        let yearly = SubscriptionCopy.renewalTerms(StoreOffer(plan: .yearly, displayPrice: "$24.99", perMonth: "$2.08 a month"))
        #expect(yearly.contains("$24.99 a year"))
        #expect(yearly.contains("renews automatically each year"))
        #expect(yearly.contains("at least 24 hours before"))
        #expect(yearly.contains("Apple Account"))
        let monthly = SubscriptionCopy.renewalTerms(StoreOffer(plan: .monthly, displayPrice: "$2.99", perMonth: nil))
        #expect(monthly.contains("$2.99 a month"))
        #expect(monthly.contains("renews automatically each month"))
    }

    @Test func theTermsAreApplesStandardAgreementAndThePrivacyPolicyIsOurs() {
        #expect(SubscriptionLinks.termsOfUse.absoluteString == "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
        #expect(SubscriptionLinks.privacyPolicy.absoluteString == "https://jamaal.app/privacy")
    }
}
