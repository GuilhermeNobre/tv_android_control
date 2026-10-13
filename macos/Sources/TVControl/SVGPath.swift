import SwiftUI

/// Converte o atributo `d` de um <path> SVG em SwiftUI.Path (M L H V C S Q T A Z, abs/rel).
enum SVGPath {
    static func parse(_ d: String) -> Path {
        var path = Path()
        var t = Tokenizer(d)
        var cur = CGPoint.zero, start = CGPoint.zero
        var lastC: CGPoint?, lastQ: CGPoint?   // pontos de controle p/ S e T
        var cmd: Character = "M"

        while let c = t.nextCommand(default: cmd) {
            cmd = c
            let rel = c.isLowercase
            func pt(_ x: Double, _ y: Double) -> CGPoint {
                rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
            }
            var newC: CGPoint?, newQ: CGPoint?
            switch Character(c.lowercased()) {
            case "m":
                guard let x = t.num(), let y = t.num() else { return path }
                cur = pt(x, y); start = cur; path.move(to: cur)
                cmd = rel ? "l" : "L"   // pares seguintes viram lineto
            case "l":
                guard let x = t.num(), let y = t.num() else { return path }
                cur = pt(x, y); path.addLine(to: cur)
            case "h":
                guard let x = t.num() else { return path }
                cur = CGPoint(x: rel ? cur.x + x : x, y: cur.y); path.addLine(to: cur)
            case "v":
                guard let y = t.num() else { return path }
                cur = CGPoint(x: cur.x, y: rel ? cur.y + y : y); path.addLine(to: cur)
            case "c":
                guard let a = t.num(), let b = t.num(), let c2 = t.num(), let d2 = t.num(),
                      let x = t.num(), let y = t.num() else { return path }
                let p1 = pt(a, b), p2 = pt(c2, d2), p = pt(x, y)
                path.addCurve(to: p, control1: p1, control2: p2); newC = p2; cur = p
            case "s":
                guard let c2 = t.num(), let d2 = t.num(), let x = t.num(), let y = t.num() else { return path }
                let p1 = lastC.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let p2 = pt(c2, d2), p = pt(x, y)
                path.addCurve(to: p, control1: p1, control2: p2); newC = p2; cur = p
            case "q":
                guard let a = t.num(), let b = t.num(), let x = t.num(), let y = t.num() else { return path }
                let p1 = pt(a, b), p = pt(x, y)
                path.addQuadCurve(to: p, control: p1); newQ = p1; cur = p
            case "t":
                guard let x = t.num(), let y = t.num() else { return path }
                let p1 = lastQ.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let p = pt(x, y)
                path.addQuadCurve(to: p, control: p1); newQ = p1; cur = p
            case "a":
                guard let rx = t.num(), let ry = t.num(), let rot = t.num(),
                      let fa = t.flag(), let fs = t.flag(), let x = t.num(), let y = t.num() else { return path }
                let p = pt(x, y)
                addArc(&path, from: cur, to: p, rx: rx, ry: ry, rotation: rot, large: fa, sweep: fs)
                cur = p
            case "z":
                path.closeSubpath(); cur = start
                cmd = "M"
            default:
                return path
            }
            lastC = newC; lastQ = newQ
        }
        return path
    }

    /// Arco SVG (parametrização por endpoints) → curvas de Bézier cúbicas.
    private static func addArc(_ path: inout Path, from p0: CGPoint, to p1: CGPoint,
                               rx rx0: Double, ry ry0: Double, rotation: Double, large: Bool, sweep: Bool) {
        var rx = abs(rx0), ry = abs(ry0)
        if rx == 0 || ry == 0 || p0 == p1 { path.addLine(to: p1); return }
        let phi = rotation * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cosP * dx + sinP * dy, y1 = -sinP * dx + cosP * dy
        let lam = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lam > 1 { let s = lam.squareRoot(); rx *= s; ry *= s }
        let num = rx*rx*ry*ry - rx*rx*y1*y1 - ry*ry*x1*x1
        let den = rx*rx*y1*y1 + ry*ry*x1*x1
        var coef = den == 0 ? 0 : (max(0, num / den)).squareRoot()
        if large == sweep { coef = -coef }
        let cxp = coef * rx * y1 / ry, cyp = -coef * ry * x1 / rx
        let cx = cosP * cxp - sinP * cyp + (p0.x + p1.x) / 2
        let cy = sinP * cxp + cosP * cyp + (p0.y + p1.y) / 2
        func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        }
        let th1 = angle(1, 0, (x1 - cxp) / rx, (y1 - cyp) / ry)
        var dth = angle((x1 - cxp) / rx, (y1 - cyp) / ry, (-x1 - cxp) / rx, (-y1 - cyp) / ry)
        if !sweep && dth > 0 { dth -= 2 * .pi }
        if sweep && dth < 0 { dth += 2 * .pi }
        let segs = Int(ceil(abs(dth) / (.pi / 2)))
        let delta = dth / Double(segs)
        let t = 4.0 / 3.0 * tan(delta / 4)
        var a = th1
        for _ in 0..<segs {
            let b = a + delta
            func p(_ ang: Double) -> CGPoint {
                let x = rx * cos(ang), y = ry * sin(ang)
                return CGPoint(x: cosP * x - sinP * y + cx, y: sinP * x + cosP * y + cy)
            }
            func dv(_ ang: Double) -> CGPoint {
                let x = -rx * sin(ang), y = ry * cos(ang)
                return CGPoint(x: cosP * x - sinP * y, y: sinP * x + cosP * y)
            }
            let s = p(a), e = p(b), ds = dv(a), de = dv(b)
            path.addCurve(to: e,
                          control1: CGPoint(x: s.x + t * ds.x, y: s.y + t * ds.y),
                          control2: CGPoint(x: e.x - t * de.x, y: e.y - t * de.y))
            a = b
        }
    }

    private struct Tokenizer {
        let s: [Character]
        var i = 0
        init(_ str: String) { s = Array(str) }

        mutating func skipSep() { while i < s.count, s[i] == " " || s[i] == "," || s[i] == "\n" || s[i] == "\t" { i += 1 } }

        /// Próximo comando; se houver número pendente, repete `default` (comando implícito).
        mutating func nextCommand(default d: Character) -> Character? {
            skipSep()
            guard i < s.count else { return nil }
            if s[i].isLetter { defer { i += 1 }; return s[i] }
            return d
        }

        mutating func num() -> Double? {
            skipSep()
            let st = i
            if i < s.count, s[i] == "-" || s[i] == "+" { i += 1 }
            var dot = false
            while i < s.count {
                let c = s[i]
                if c.isNumber { i += 1 }
                else if c == "." && !dot { dot = true; i += 1 }
                else if (c == "e" || c == "E"), i + 1 < s.count { i += 1; if s[i] == "-" || s[i] == "+" { i += 1 } }
                else { break }
            }
            return i > st ? Double(String(s[st..<i])) : nil
        }

        /// Flags de arco podem vir coladas ("a1 1 0 011 1").
        mutating func flag() -> Bool? {
            skipSep()
            guard i < s.count, s[i] == "0" || s[i] == "1" else { return nil }
            defer { i += 1 }
            return s[i] == "1"
        }
    }
}

/// Forma SVG escalada para caber no retângulo (viewBox quadrado de 24 unidades por padrão).
struct SVGShape: Shape {
    let d: String
    var viewBox: CGFloat = 24

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / viewBox
        let p = SVGPath.parse(d)
        return p.applying(CGAffineTransform(scaleX: s, y: s))
            .offsetBy(dx: rect.minX + (rect.width - viewBox * s) / 2,
                      dy: rect.minY + (rect.height - viewBox * s) / 2)
    }
}
