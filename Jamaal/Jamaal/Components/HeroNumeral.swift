//
//  HeroNumeral.swift
//  Jamaal
//

import CoreText
import SwiftUI
import ThreadsTokens

/// The Fraunces cut the tabletop timer uses: weight 300, optical size 104, cut from the upstream variable font (SIL Open Font
/// License, `Resources/Fonts/OFL-Fraunces.txt`). ThreadsKit ships only the weight-500 display cut, and the design draws this numeral in
/// weight 300 (`Duo-tabletop-FS-02`: Fraunces 300, 104 px, tabular figures). The proper home is ThreadsKit.
enum HeroFont {
    static let name = "FrauncesHero-Light"
    /// Registered once, on first use. False when the file is missing, and the numeral then falls back to the kit's own cut.
    static let isAvailable: Bool = {
        guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
        else { return false }
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) { return true }
        let code = error.map { CFErrorGetCode($0.takeRetainedValue()) }
        return code == CTFontManagerError.alreadyRegistered.rawValue
    }()
}

/// A numeral far larger than ThreadsKit's biggest display size (38 pt): the timer on the teal half of the focus screen held in tabletop,
/// 104 pt in weight 300. Each digit sits in a cell as wide as the widest digit, as `ThreadsNumeral` does, so the time does not shift
/// sideways as it ticks.
struct HeroNumeral: View {
    let text: String
    @ScaledMetric(relativeTo: .largeTitle) private var scaledSize: CGFloat = 104
    /// 104 pt at the default text size, growing with Dynamic Type up to a cap that still fits the teal half of the narrowest Duo display.
    private var size: CGFloat { min(scaledSize, 150) }

    private var fontName: String { HeroFont.isAvailable ? HeroFont.name : "FrauncesDisplay-Regular" }

    init(_ text: String) { self.text = text }

    var body: some View {
        let cell = CGFloat(ThreadsNumeral.digitCellWidth(fontName: fontName, pointSize: Double(size)))
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .font(.custom(fontName, size: size))
                    .fixedSize()                                             // never shrunk: a digit whose width came out a hair over its cell
                    .frame(width: character.isWholeNumber ? cell : nil)       // was scaled to about 58% by minimumScaleFactor (#329)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
