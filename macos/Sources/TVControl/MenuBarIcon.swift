import AppKit

/// Monochrome (template) remote control for the menu bar — same drawing as the app icon.
enum MenuBarIcon {
    static let image: NSImage = {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let r = rect.insetBy(dx: 1.5, dy: 0.5)
            let bw = 0.46 * r.width * 1.5, bh = r.height
            let body = CGRect(x: r.midX - bw / 2, y: r.minY, width: bw, height: bh)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.addPath(CGPath(roundedRect: body, cornerWidth: bw * 0.42, cornerHeight: bw * 0.42, transform: nil))
            ctx.fillPath()
            // transparent cut-outs
            ctx.setBlendMode(.clear)
            func dot(_ x: CGFloat, _ y: CGFloat, _ rad: CGFloat) {
                ctx.fillEllipse(in: CGRect(x: r.minX + x * r.width - rad, y: r.minY + y * r.height - rad,
                                           width: 2 * rad, height: 2 * rad))
            }
            dot(0.5, 0.82, 1.1)
            ctx.fillEllipse(in: CGRect(x: r.midX - 2.6, y: r.minY + 0.5 * r.height - 2.6, width: 5.2, height: 5.2))
            dot(0.5, 0.15, 0.9)
            return true
        }
        img.isTemplate = true
        return img
    }()
}
