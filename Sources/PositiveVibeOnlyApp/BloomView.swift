import SwiftUI
import PositiveVibeOnlyCore

/// One ring of petals arranged evenly around a centre point, each pushed
/// outward by `ring.offset` then rotated into place — the SwiftUI
/// equivalent of the CSS `rotate(Xdeg) translateY(-Npx)` the design spec
/// describes: offset happens in local (unrotated) space first, then the
/// whole petal rotates around the shared centre.
private struct RingView: View {
    let ring: PetalRing
    let color: Color

    var body: some View {
        ForEach(0..<ring.count, id: \.self) { i in
            let angle = ring.startAngle + Double(i) * (360.0 / Double(ring.count))
            PetalShape(tip: ring.tip)
                .fill(color)
                .frame(width: ring.width, height: ring.length)
                .offset(y: -ring.offset)
                .rotationEffect(.degrees(angle))
        }
    }
}

/// Draws one flower's die-cut bloom: rim (off-white, +12pt/+6pt over the
/// outer ring — the "sticker trimmed a hair outside the artwork" edge),
/// then the outer ring, then the inner ring on top. Fixed 640x640pt, petal
/// tips reaching to 300pt from centre, per the approved handoff spec.
struct BloomView: View {
    let spec: BloomSpec

    var body: some View {
        ZStack {
            RingView(ring: spec.outer.rim, color: Color(hex: BloomCatalog.rimColorHex))
            RingView(ring: spec.outer, color: Color(hex: spec.outerColorHex))
            RingView(ring: spec.inner, color: Color(hex: spec.innerColorHex))
        }
        .frame(width: 640, height: 640)
    }
}
