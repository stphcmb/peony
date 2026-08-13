// Renders the 4a filled-peony app icon (approved logo turn) to a 1024x1024
// PNG using plain AppKit drawing — no Xcode asset catalog involved. Run
// standalone: swift scripts/render-app-icon.swift <output.png>
import AppKit

let canvas: CGFloat = 1024
let tileRadius: CGFloat = canvas * (28.0 / 128.0)
let tileFill = NSColor(red: 0xFD/255.0, green: 0xF0/255.0, blue: 0xE8/255.0, alpha: 1)

// Ring geometry from "Flowers - logo.dc.html", scaled from its 200x200
// reference frame up to this canvas (scale = canvas / 200).
let scale = canvas / 200

struct Ring { let count: Int; let w: CGFloat; let h: CGFloat; let offset: CGFloat; let start: CGFloat; let color: NSColor }
let rings: [Ring] = [
    Ring(count: 7, w: 86 * scale, h: 128 * scale, offset: 30 * scale, start: 0, color: NSColor(red: 232/255.0, green: 120/255.0, blue: 140/255.0, alpha: 0.30)),
    Ring(count: 5, w: 62 * scale, h: 84 * scale, offset: 22 * scale, start: 25, color: NSColor(red: 226/255.0, green: 92/255.0, blue: 116/255.0, alpha: 0.34)),
    Ring(count: 3, w: 40 * scale, h: 50 * scale, offset: 14 * scale, start: 0, color: NSColor(red: 214/255.0, green: 66/255.0, blue: 96/255.0, alpha: 0.40)),
]
let centerDot: CGFloat = 26 * scale
let centerColor = NSColor(red: 0xF6/255.0, green: 0xC7/255.0, blue: 0x7A/255.0, alpha: 1)

let image = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in
    let tileRect = NSRect(x: 0, y: 0, width: canvas, height: canvas)
    NSBezierPath(roundedRect: tileRect, xRadius: tileRadius, yRadius: tileRadius).setClip()
    tileFill.setFill()
    NSBezierPath(rect: tileRect).fill()

    let center = NSPoint(x: canvas / 2, y: canvas / 2)
    for ring in rings {
        ring.color.setFill()
        for i in 0..<ring.count {
            let angleDeg = ring.start + Double(i) * (360.0 / Double(ring.count))
            let angle = angleDeg * .pi / 180
            let ctx = NSGraphicsContext.current!.cgContext
            ctx.saveGState()
            ctx.translateBy(x: center.x, y: center.y)
            ctx.rotate(by: CGFloat(angle))
            let petalRect = NSRect(x: -ring.w / 2, y: ring.offset, width: ring.w, height: ring.h)
            NSBezierPath(roundedRect: petalRect, xRadius: ring.w / 2, yRadius: ring.w / 2).fill()
            ctx.restoreGState()
        }
    }

    centerColor.setFill()
    let dotRect = NSRect(x: center.x - centerDot / 2, y: center.y - centerDot / 2, width: centerDot, height: centerDot)
    NSBezierPath(ovalIn: dotRect).fill()

    return true
}

guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to render PNG\n".data(using: .utf8)!)
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
try! png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
