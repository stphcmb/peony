import SwiftUI

/// The fonts the cards draw in, as NSFont — only so widow-guarding can
/// measure text before deciding to glue two words together.
enum CardFont {
    static func fraunces(_ size: CGFloat) -> NSFont { named("Fraunces", size) }
    static func karla(_ size: CGFloat) -> NSFont { named("Karla", size) }
    private static func named(_ name: String, _ size: CGFloat) -> NSFont {
        NSFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }
}

extension String {
    /// Glues the last two words with a non-breaking space so a wrap can
    /// never strand a single word alone on the final line. Centred body
    /// copy reads as a shape, and a one-word last line breaks that shape —
    /// this is the cheap typographic fix, applied to the copy rather than
    /// hand-tuning line breaks per string.
    ///
    /// Skipped when the glued pair wouldn't fit a line: an unbreakable
    /// token wider than the card doesn't wrap, it overhangs the arch. Two
    /// quotes in content.json ("…progress simultaneously.") are exactly
    /// that case. The 0.9 margin covers the italic and semibold faces the
    /// cards actually draw in, which run wider than the measured regular.
    func noWidow(font: NSFont, width: CGFloat) -> String {
        let text = trimmingCharacters(in: .whitespacesAndNewlines)
        guard let lastSpace = text.range(of: " ", options: .backwards) else { return text }
        let secondLast = text[..<lastSpace.lowerBound].range(of: " ", options: .backwards)?.upperBound
            ?? text.startIndex
        let pair = String(text[secondLast...])
        let pairWidth = NSAttributedString(string: pair, attributes: [.font: font]).size().width
        guard pairWidth <= width * 0.9 else { return text }
        return text.replacingCharacters(in: lastSpace, with: "\u{00A0}")
    }
}

/// Text widths inside the arch, derived from the card width and the same
/// horizontal padding the layouts apply — widow-guarding has to measure
/// against the width the text will actually wrap at.
enum CardMetrics {
    static let width: CGFloat = 258
    static func textWidth(padding: CGFloat) -> CGFloat { width - padding * 2 }
}
