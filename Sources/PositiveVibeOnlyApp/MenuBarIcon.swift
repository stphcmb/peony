import AppKit

enum MenuBarIcon {
    /// A small colored version of the filled-peony app icon: five petal
    /// capsules in the brand rose, meeting at a gold centre dot. Not a
    /// template image — that would flatten it to monochrome; the color is
    /// the point here, and the rose reads on both light and dark menu
    /// bars. (The cost: AppKit won't dim it when inactive.)
    static func make() -> NSImage {
        let petalWidth: CGFloat = 7
        let petalHeight: CGFloat = 11
        let offset: CGFloat = 2.6
        let dotDiameter: CGFloat = 5

        // Same rose/gold as scripts/render-app-icon.swift's middle ring
        // and centre, so the two marks read as one identity. Near-solid
        // alpha — translucent rose muddies to maroon on a dark menu bar.
        let petalColor = NSColor(red: 226/255.0, green: 92/255.0, blue: 116/255.0, alpha: 0.94)
        let dotColor = NSColor(red: 0xF6/255.0, green: 0xC7/255.0, blue: 0x7A/255.0, alpha: 1)

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
            petalColor.setFill()

            for i in 0..<5 {
                let angle = CGFloat(i) * (2 * .pi / 5)
                let transform = NSAffineTransform()
                transform.translateX(by: center.x, yBy: center.y)
                transform.rotate(byRadians: angle)

                let petalRect = NSRect(x: -petalWidth / 2, y: offset, width: petalWidth, height: petalHeight)
                let path = NSBezierPath(roundedRect: petalRect, xRadius: petalWidth / 2, yRadius: petalWidth / 2)
                path.transform(using: transform as AffineTransform)
                path.fill()
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
