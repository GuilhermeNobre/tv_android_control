// Generates the app's 1024x1024 master icon: swift icon/make-icon.swift <output.png>
import AppKit

let size = 1024
guard CommandLine.arguments.count > 1 else { print("usage: make-icon.swift <output.png>"); exit(1) }

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let nsctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = nsctx
let ctx = nsctx.cgContext

// Apple grid: 824 pt tile centered on the 1024 canvas.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 184, cornerHeight: 184, transform: nil)

// Soft shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
ctx.addPath(tilePath); ctx.setFillColor(NSColor(red: 0.2, green: 0.3, blue: 0.8, alpha: 1).cgColor); ctx.fillPath()
ctx.restoreGState()

// Tile gradient
ctx.saveGState()
ctx.addPath(tilePath); ctx.clip()
let space = CGColorSpaceCreateDeviceRGB()
let grad = CGGradient(colorsSpace: space, colors: [
    NSColor(red: 0.36, green: 0.62, blue: 1.00, alpha: 1).cgColor,   // top
    NSColor(red: 0.30, green: 0.22, blue: 0.86, alpha: 1).cgColor,   // bottom
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: tile.maxY), end: CGPoint(x: 512, y: tile.minY), options: [])
// subtle highlight at the top
let shine = CGGradient(colorsSpace: space, colors: [
    NSColor.white.withAlphaComponent(0.28).cgColor, NSColor.white.withAlphaComponent(0).cgColor,
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(shine, start: CGPoint(x: 512, y: tile.maxY), end: CGPoint(x: 512, y: tile.midY), options: [])
ctx.restoreGState()

// Remote control (same drawing as the menu bar icon)
func remote(in r: CGRect, ctx: CGContext, body: NSColor, cutout: NSColor) {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
    let bw = 0.58 * r.width, bh = r.height
    let bodyRect = CGRect(x: r.midX - bw / 2, y: r.minY, width: bw, height: bh)
    ctx.setFillColor(body.cgColor)
    ctx.addPath(CGPath(roundedRect: bodyRect, cornerWidth: bw * 0.42, cornerHeight: bw * 0.42, transform: nil))
    ctx.fillPath()
    ctx.setFillColor(cutout.cgColor)
    ctx.setStrokeColor(cutout.cgColor)
    func dot(_ c: CGPoint, _ rad: CGFloat) { ctx.fillEllipse(in: CGRect(x: c.x - rad, y: c.y - rad, width: 2 * rad, height: 2 * rad)) }
    dot(p(0.5, 0.86), bw * 0.1)                              // power
    let ring = bw * 0.30
    ctx.setLineWidth(bw * 0.075)                              // d-pad ring
    ctx.strokeEllipse(in: CGRect(x: p(0.5, 0.55).x - ring, y: p(0.5, 0.55).y - ring, width: 2 * ring, height: 2 * ring))
    dot(p(0.5, 0.55), bw * 0.11)                              // OK
    dot(p(0.5 - 0.1, 0.17), bw * 0.065)                       // buttons
    dot(p(0.5 + 0.1, 0.17), bw * 0.065)
}

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: NSColor.black.withAlphaComponent(0.25).cgColor)
remote(in: CGRect(x: 512 - 200, y: 512 - 270, width: 400, height: 540), ctx: ctx,
       body: .white, cutout: NSColor(red: 0.33, green: 0.34, blue: 0.93, alpha: 1))
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
