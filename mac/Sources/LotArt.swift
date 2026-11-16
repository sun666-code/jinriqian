import SwiftUI

// MARK: - 签图：每支签一幅程序生成的水墨小景（原创，不用任何网图）
// 远山三重、日或月（月相随签变化）、云气、江水、孤舟、松、归鸟，按签号决定构图；
// 右上角印一个本签的卦象。只用墨色、旧纸色与一点黄铜色。

struct LotArt: View {
    let no: Int
    var level: String = "中平"
    var showTrigram = true

    var body: some View {
        Canvas { ctx, size in
            LotArt.paint(ctx: &ctx, size: size, no: no, level: level)
        }
        .overlay(alignment: .topTrailing) {
            if showTrigram {
                let tg = Lot.trigramsFor(no)
                VStack(spacing: 3) {
                    TrigramGlyph(lines: Mystic.trigrams[tg.up], width: 10, color: Mystic.paperInk.opacity(0.55))
                    TrigramGlyph(lines: Mystic.trigrams[tg.low], width: 10, color: Mystic.paperInk.opacity(0.55))
                }
                .padding(6)
            }
        }
    }

    static func paint(ctx: inout GraphicsContext, size: CGSize, no: Int, level: String) {
        var seed = UInt64(truncatingIfNeeded: no &* 2654435761) &+ 0x9E37
        func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(Double(seed >> 33) / Double(1 << 31)) }
        let w = size.width, h = size.height
        let ink = Color(hex: 0x1F1B14)
        let brass = Color(hex: 0x9C8550)
        let bright = ["上上", "上吉"].contains(level)
        let night = !bright && no % 3 == 0

        // 天
        let sky = night ? [Color(hex: 0xC9C2AE), Color(hex: 0xE6DDC6)] : [Color(hex: 0xF3EAD3), Color(hex: 0xE4D7B6)]
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: sky), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

        // 日 / 月
        let cx = w * (0.18 + rnd() * 0.64), cy = h * (0.16 + rnd() * 0.16), r = min(w, h) * (0.08 + rnd() * 0.05)
        if night || no % 2 == 0 {
            ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xF7F1E1)))
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(ink.opacity(0.25)), lineWidth: 0.6)
            let phase = rnd()
            if phase < 0.7 {   // 月相：用天色盖出弯月
                let off = r * (0.5 + phase)
                ctx.fill(Path(ellipseIn: CGRect(x: cx - r + off, y: cy - r - r * 0.1, width: r * 2, height: r * 2)), with: .color(sky[0]))
            }
        } else {
            ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(brass.opacity(0.55)))
        }

        // 云气
        for _ in 0..<Int(2 + rnd() * 3) {
            let y = h * (0.12 + rnd() * 0.3), x0 = rnd() * w * 0.6, len = w * (0.2 + rnd() * 0.35)
            var p = Path()
            p.move(to: CGPoint(x: x0, y: y))
            p.addCurve(to: CGPoint(x: x0 + len, y: y), control1: CGPoint(x: x0 + len * 0.3, y: y - 6), control2: CGPoint(x: x0 + len * 0.7, y: y + 4))
            ctx.stroke(p, with: .color(ink.opacity(0.18)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        }

        // 远山三重（后淡前浓）
        let layers: [(CGFloat, CGFloat, Double)] = [(0.50, 0.16, 0.16), (0.62, 0.14, 0.30), (0.74, 0.12, 0.62)]
        var frontTop: [CGPoint] = []
        for (i, l) in layers.enumerated() {
            let ph = Double(rnd()) * 6, f1 = 1.5 + Double(rnd()) * 2.5, f2 = 4 + Double(rnd()) * 5
            var p = Path()
            p.move(to: CGPoint(x: 0, y: h))
            var tops: [CGPoint] = []
            for k in 0...48 {
                let x = CGFloat(k) / 48
                let yv = l.0 - l.1 * CGFloat(0.6 * sin(Double(x) * f1 * .pi + ph) * 0.5 + 0.5 + 0.25 * sin(Double(x) * f2 * .pi + ph * 2))
                let pt = CGPoint(x: x * w, y: yv * h)
                tops.append(pt); p.addLine(to: pt)
            }
            p.addLine(to: CGPoint(x: w, y: h)); p.closeSubpath()
            ctx.fill(p, with: .linearGradient(Gradient(colors: [ink.opacity(l.2), ink.opacity(l.2 * 0.25)]),
                                              startPoint: CGPoint(x: 0, y: (l.0 - l.1) * h), endPoint: CGPoint(x: 0, y: h)))
            if i == 2 { frontTop = tops }
        }

        // 江水与孤舟
        if no % 4 != 1 {
            let wy = h * 0.86
            ctx.fill(Path(CGRect(x: 0, y: wy, width: w, height: h - wy)), with: .color(Color(hex: 0xEDE3CB)))
            for _ in 0..<7 {
                let x = rnd() * w, y = wy + rnd() * (h - wy - 2), len = 6 + rnd() * 14
                var p = Path(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + len, y: y))
                ctx.stroke(p, with: .color(ink.opacity(0.25)), lineWidth: 0.6)
            }
            if no % 3 != 2 {
                let bx = w * (0.25 + rnd() * 0.5), by = wy + (h - wy) * 0.45
                var hull = Path()
                hull.move(to: CGPoint(x: bx - 9, y: by)); hull.addQuadCurve(to: CGPoint(x: bx + 9, y: by), control: CGPoint(x: bx, y: by + 5))
                ctx.stroke(hull, with: .color(ink.opacity(0.8)), lineWidth: 1.2)
                var mast = Path(); mast.move(to: CGPoint(x: bx - 1, y: by)); mast.addLine(to: CGPoint(x: bx - 1, y: by - 7))
                ctx.stroke(mast, with: .color(ink.opacity(0.7)), lineWidth: 0.7)
            }
        }

        // 松：长在前山上
        if no % 2 == 1, frontTop.count > 10 {
            let pt = frontTop[Int(rnd() * 30) + 8]
            var trunk = Path(); trunk.move(to: pt); trunk.addLine(to: CGPoint(x: pt.x + 2, y: pt.y - 18))
            ctx.stroke(trunk, with: .color(ink.opacity(0.85)), lineWidth: 1.1)
            for k in 0..<4 {
                let y = pt.y - 6 - CGFloat(k) * 4, half = 9 - CGFloat(k) * 1.8
                var b = Path(); b.move(to: CGPoint(x: pt.x - half, y: y + 1)); b.addQuadCurve(to: CGPoint(x: pt.x + half + 2, y: y), control: CGPoint(x: pt.x + 1, y: y - 3))
                ctx.stroke(b, with: .color(ink.opacity(0.8)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        }

        // 归鸟
        for _ in 0..<Int(rnd() * 4) {
            let x = w * (0.2 + rnd() * 0.6), y = h * (0.25 + rnd() * 0.2), s: CGFloat = 3 + rnd() * 2
            var p = Path()
            p.move(to: CGPoint(x: x - s, y: y - s * 0.5)); p.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - s * 0.4, y: y - s * 0.6))
            p.addQuadCurve(to: CGPoint(x: x + s, y: y - s * 0.5), control: CGPoint(x: x + s * 0.4, y: y - s * 0.6))
            ctx.stroke(p, with: .color(ink.opacity(0.7)), lineWidth: 0.7)
        }

        // 纸纹
        for _ in 0..<40 {
            let x = rnd() * w, y = rnd() * h
            var p = Path(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + 3 + rnd() * 5, y: y + rnd() * 2))
            ctx.stroke(p, with: .color(ink.opacity(0.05)), lineWidth: 0.5)
        }
    }
}

extension Lot {
    static func trigramsFor(_ no: Int) -> (up: Int, low: Int) {
        if no >= 25 && no <= 88 { return ((no - 25) / 8, (no - 25) % 8) }
        let k = (no * 7) % 64
        return (k / 8, k % 8)
    }
}
