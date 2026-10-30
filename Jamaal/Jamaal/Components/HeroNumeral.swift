//
//  HeroNumeral.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// A numeral far larger than ThreadsKit's biggest display size (38 pt): the timer on the teal half of the focus screen held in tabletop
/// (`Duo-tabletop-FS-02.png`, about 100 pt). It sets each digit in a cell as wide as the widest digit, as `ThreadsNumeral` does, so the
/// time does not shift sideways as it ticks. There is no token for it yet: the proper home is a size in ThreadsKit (docs/design/threadskit-usage.md).
struct HeroNumeral: View {
    let text: String
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 96

    private static let fontName = "FrauncesDisplay-Regular"

    init(_ text: String) { self.text = text }

    var body: some View {
        let cell = CGFloat(ThreadsNumeral.digitCellWidth(fontName: Self.fontName, pointSize: Double(size)))
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .font(.custom(Self.fontName, size: size))
                    .frame(width: character.isWholeNumber ? cell : nil)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
