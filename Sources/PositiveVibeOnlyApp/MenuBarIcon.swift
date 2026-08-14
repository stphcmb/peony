import AppKit

enum MenuBarIcon {
    /// A miniature of the 4a full-bloom app icon: three rings of translucent
    /// rose petals over each other, gold centre dot — the same geometry and
    /// palette as scripts/render-app-icon.swift, scaled from its 200-unit
    /// reference frame down to an 18pt icon. Alphas are boosted from the app
    /// icon's because at menu bar size the layers composite against the
    /// bar, not a cream tile. A white die-cut rim sits behind the petals —
    /// the same sticker edge as the big bloom card — which keeps the pinks
    /// true on a dark menu bar and softens the whole mark.
    /// Not a template image — the layered color is the point.
    static func make() -> NSImage {
        struct Ring {
            let count: Int
            let width: CGFloat
            let height: CGFloat
            let offset: CGFloat
            let startDegrees: CGFloat
            let color: NSColor
        }
        let rings: [Ring] = [
            Ring(count: 7, width: 86, height: 128, offset: 30, startDegrees: 0,
                 color: NSColor(red: 240/255.0, green: 150/255.0, blue: 165/255.0, alpha: 0.40)),
            Ring(count: 5, width: 62, height: 84, offset: 22, startDegrees: 25,
                 color: NSColor(red: 233/255.0, green: 120/255.0, blue: 142/255.0, alpha: 0.46)),
            Ring(count: 3, width: 40, height: 50, offset: 14, startDegrees: 0,
                 color: NSColor(red: 224/255.0, green: 95/255.0, blue: 120/255.0, alpha: 0.52)),
        ]
        let dotColor = NSColor(red: 0xF6/255.0, green: 0xC7/255.0, blue: 0x7A/255.0, alpha: 1)

        let iconSize: CGFloat = 18
        // The white rim reaches (30 - 4) + 128 * 1.10 ≈ 167 reference units
        // from centre; scale that to the icon's radius, less a hairline
        // margin so nothing clips.
        let scale = (iconSize / 2 - 0.5) / 167
        let dotDiameter: CGFloat = 36 * scale

        let image = NSImage(size: NSSize(width: iconSize, height: iconSize), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let center = NSPoint(x: iconSize / 2, y: iconSize / 2)

            // White rim first: the outer ring's petals, scaled up a touch.
            NSColor(red: 1, green: 0.99, blue: 0.98, alpha: 0.92).setFill()
            let rim = rings[0]
            for i in 0..<rim.count {
                let angle = (rim.startDegrees + CGFloat(i) * 360 / CGFloat(rim.count)) * .pi / 180
                ctx.saveGState()
                ctx.translateBy(x: center.x, y: center.y)
                ctx.rotate(by: angle)
                let w = rim.width * 1.18 * scale
                let h = rim.height * 1.10 * scale
                let rimRect = NSRect(x: -w / 2, y: (rim.offset - 4) * scale, width: w, height: h)
                NSBezierPath(roundedRect: rimRect, xRadius: w / 2, yRadius: w / 2).fill()
                ctx.restoreGState()
            }

            for ring in rings {
                ring.color.setFill()
                for i in 0..<ring.count {
                    let angle = (ring.startDegrees + CGFloat(i) * 360 / CGFloat(ring.count)) * .pi / 180
                    ctx.saveGState()
                    ctx.translateBy(x: center.x, y: center.y)
                    ctx.rotate(by: angle)
                    let w = ring.width * scale
                    let petalRect = NSRect(x: -w / 2, y: ring.offset * scale, width: w, height: ring.height * scale)
                    NSBezierPath(roundedRect: petalRect, xRadius: w / 2, yRadius: w / 2).fill()
                    ctx.restoreGState()
                }
            }

            dotColor.setFill()
            let dotRect = NSRect(x: center.x - dotDiameter / 2, y: center.y - dotDiameter / 2, width: dotDiameter, height: dotDiameter)
            NSBezierPath(ovalIn: dotRect).fill()

            return true
        }
        image.isTemplate = false
        return image
    }
}
