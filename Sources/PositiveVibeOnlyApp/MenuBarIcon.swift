import AppKit

enum MenuBarIcon {
    /// The 4c mark from the approved logo turn: five stroked petal capsules
    /// meeting at a centre dot, nothing filled. Survives 18pt and monochrome
    /// far better than a filled bloom would — exactly what the menu bar
    /// needs. `isTemplate = true` so AppKit recolors it for light/dark menu
    /// bars and dims it correctly when the app is inactive.
    static func make() -> NSImage {
        let petalWidth: CGFloat = 6
        let petalHeight: CGFloat = 11
        let offset: CGFloat = 6.2
        let strokeWidth: CGFloat = 1.3
        let dotDiameter: CGFloat = 3.6

        // The design spec's numbers (offset 6.2 + petal height 11 = 17.2pt
        // reach from centre) were written for a CSS mockup, where unbounded
        // overflow just renders past the nominal 18x18 box. AppKit's image
        // context has no such grace — it clips hard at its own bounds, so a
        // literal 18x18 canvas silently cut off most of every petal, leaving
        // only a rounded sliver near the centre. The canvas has to actually
        // contain the geometry it draws; sized here to the petals' real
        // reach plus a small margin, not the reference frame's box.
        let size = 2 * (offset + petalHeight) + 4

        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let center = NSPoint(x: size / 2, y: size / 2)
            NSColor.black.setStroke()

            for i in 0..<5 {
                let angle = CGFloat(i) * (2 * .pi / 5)
                let transform = NSAffineTransform()
                transform.translateX(by: center.x, yBy: center.y)
                transform.rotate(byRadians: angle)

                let petalRect = NSRect(x: -petalWidth / 2, y: offset, width: petalWidth, height: petalHeight)
                let path = NSBezierPath(roundedRect: petalRect, xRadius: petalWidth / 2, yRadius: petalWidth / 2)
                path.lineWidth = strokeWidth
                path.transform(using: transform as AffineTransform)
                path.stroke()
            }

            NSColor.black.setFill()
            let dotRect = NSRect(x: center.x - dotDiameter / 2, y: center.y - dotDiameter / 2, width: dotDiameter, height: dotDiameter)
            NSBezierPath(ovalIn: dotRect).fill()

            return true
        }
        image.isTemplate = true
        return image
    }
}
