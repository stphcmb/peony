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

/// The centre card's "lens" — a rounded rect with independent horizontal
/// and vertical corner radii (CSS `border-radius: 122px / 92px`). At width
/// 258 with radius-x 122, the sides are nearly full semicircles; SwiftUI has
/// no built-in for asymmetric corner radii, so this builds the four corners
/// as true elliptical arcs (quarter-ellipse via a 4-point Bezier
/// approximation, the same construction CSS itself uses).
struct LensShape: Shape {
    let radiusX: CGFloat
    let radiusY: CGFloat

    func path(in rect: CGRect) -> Path {
        let rx = min(radiusX, rect.width / 2)
        let ry = min(radiusY, rect.height / 2)
        // Bezier control-point offset for a quarter ellipse, standard constant.
        let kx = rx * 0.5523
        let ky = ry * 0.5523

        let minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY

        var path = Path()
        path.move(to: CGPoint(x: minX + rx, y: minY))
        path.addLine(to: CGPoint(x: maxX - rx, y: minY))
        path.addCurve(to: CGPoint(x: maxX, y: minY + ry),
                      control1: CGPoint(x: maxX - rx + kx, y: minY),
                      control2: CGPoint(x: maxX, y: minY + ry - ky))
        path.addLine(to: CGPoint(x: maxX, y: maxY - ry))
        path.addCurve(to: CGPoint(x: maxX - rx, y: maxY),
                      control1: CGPoint(x: maxX, y: maxY - ry + ky),
                      control2: CGPoint(x: maxX - rx + kx, y: maxY))
        path.addLine(to: CGPoint(x: minX + rx, y: maxY))
        path.addCurve(to: CGPoint(x: minX, y: maxY - ry),
                      control1: CGPoint(x: minX + rx - kx, y: maxY),
                      control2: CGPoint(x: minX, y: maxY - ry + ky))
        path.addLine(to: CGPoint(x: minX, y: minY + ry))
        path.addCurve(to: CGPoint(x: minX + rx, y: minY),
                      control1: CGPoint(x: minX, y: minY + ry - ky),
                      control2: CGPoint(x: minX + rx - kx, y: minY))
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
