import SwiftUI

/// How big the bloom + card draw. The composition is authored once at
/// `baseSize` and scaled as a whole — the card alone can't grow inside a
/// fixed bloom without breaking the arrangement, so one factor moves both.
/// Shared because two sides need it: the card views scale their content,
/// and AppDelegate resizes the NSPanel to match (SwiftUI can't resize its
/// own host window). Persisted, so the chosen size survives a relaunch.
@MainActor
final class CardScaleState: ObservableObject {
    static let baseSize: CGFloat = 640
    static let range: ClosedRange<CGFloat> = 0.7...1.6
    private static let key = "CardScale"

    /// Set by AppDelegate to follow the content with the panel frame.
    var onChange: ((CGFloat) -> Void)?

    @Published var scale: CGFloat {
        didSet {
            guard scale != oldValue else { return }
            UserDefaults.standard.set(Double(scale), forKey: Self.key)
            onChange?(scale)
        }
    }

    init() {
        // 0 is also what an unset key returns, which is the same answer as
        // "no stored size": start at 1.
        let stored = UserDefaults.standard.double(forKey: Self.key)
        scale = stored > 0 ? Self.clamped(CGFloat(stored)) : 1
    }

    static func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

extension View {
    /// Scales the card composition about its centre and reports the scaled
    /// size to the layout, so the hosting view — and through it the panel —
    /// sizes to exactly what's drawn.
    func cardScaled(_ scale: CGFloat) -> some View {
        scaleEffect(scale)
            .frame(width: CardScaleState.baseSize * scale,
                   height: CardScaleState.baseSize * scale)
    }
}
