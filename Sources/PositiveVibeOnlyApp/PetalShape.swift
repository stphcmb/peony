import SwiftUI
import PositiveVibeOnlyCore

/// A capsule-like petal: the outer tip (top, far from the bloom's centre)
/// is always fully rounded; the base (bottom, near the centre) is either
/// fully rounded too (`.round`) or flattened to a smaller radius
/// (`.squared`) — matches ray-petalled flowers meeting the centre with a
/// blunter edge than cupped ones.
///
/// Written from scratch rather than `RoundedRectangle` because per-corner
/// radii need macOS 14's `UnevenRoundedRectangle` — this target is macOS 13.
struct PetalShape: Shape {
    let tip: PetalTip

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let topRadius = min(w, h) / 2
        let bottomRadius: CGFloat
        switch tip {
        case .round:
            bottomRadius = topRadius
        case .squared(let baseRadius):
            bottomRadius = min(CGFloat(baseRadius), w / 2)
        }

        var path = Path()
        let minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY

        path.move(to: CGPoint(x: minX, y: minY + topRadius))
        path.addArc(center: CGPoint(x: minX + topRadius, y: minY + topRadius), radius: topRadius,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: maxX - topRadius, y: minY))
        path.addArc(center: CGPoint(x: maxX - topRadius, y: minY + topRadius), radius: topRadius,
                    startAngle: .degrees(270), endAngle: .degrees(360), clockwise: false)
        path.addLine(to: CGPoint(x: maxX, y: maxY - bottomRadius))
        path.addArc(center: CGPoint(x: maxX - bottomRadius, y: maxY - bottomRadius), radius: bottomRadius,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: minX + bottomRadius, y: maxY))
        path.addArc(center: CGPoint(x: minX + bottomRadius, y: maxY - bottomRadius), radius: bottomRadius,
                    startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.closeSubpath()
        return path
    }
}

extension Color {
    /// Parses "#RRGGBB" hex strings from the design catalog.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
