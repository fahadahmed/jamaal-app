//
//  TabBarAppearance.swift
//  Jamaal
//

#if canImport(UIKit)
import SwiftUI
import UIKit
import ThreadsTokens

/// The system tab bar in the design's colours (the bar itself stays the system's Liquid Glass, so the Duo can move it to the
/// side): items in `ink3` in Hanken Medium 11, the chosen one in `ink` and semibold, with a white `selected` pill behind it.
/// On iOS 26 the system applies the chosen item's colour and font but ignores the unselected colour and the pill's tint
/// (checked on 26.4); they are set anyway so a later release that honours them picks them up.
enum TabBarAppearance {
    static func apply(_ palette: some ThreadsPalette) {
        let ink = UIColor(palette.ink), ink3 = UIColor(palette.ink3)
        let regular = UIFont(name: "HankenGrotesk-Medium", size: 11) ?? .systemFont(ofSize: 11, weight: .medium)
        let semibold = UIFont(name: "HankenGrotesk-SemiBold", size: 11) ?? .systemFont(ofSize: 11, weight: .semibold)

        let item = UITabBarItemAppearance()
        item.normal.iconColor = ink3
        item.normal.titleTextAttributes = [.foregroundColor: ink3, .font: regular]
        item.selected.iconColor = ink
        item.selected.titleTextAttributes = [.foregroundColor: ink, .font: semibold]

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item
        appearance.selectionIndicatorTintColor = UIColor(palette.selected)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = ink3
        UITabBarItem.appearance().setTitleTextAttributes([.foregroundColor: ink3, .font: regular], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.foregroundColor: ink, .font: semibold], for: .selected)
    }
}
#endif
