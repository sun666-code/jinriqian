import SwiftUI

// MARK: - 签图（民间塔罗风，原创矢量生成）
// 每支签按签号组合出一幅小画：天色（8 套低饱和配色，无红色）+ 云或星 + 大日/弯月 + 远山 + 松林剪影
// + 河/湖（部分）+ 主角剪影（鹿、披斗篷的行者、鹤、狐、猫头鹰、孤树、山居、兔、无）+ 前景花草。

struct FolkArt: View {
    let no: Int
    var compact = false
    var body: some View {
        Canvas { ctx, size in FolkArt.paint(&ctx, size, no: no, compact: compact) }
    }

    struct Pal { let skyTop, skyBottom, far, mid, near, accent, cream: UInt32; let night: Bool }
    static let pals: [Pal] = [
        Pal(skyTop: 0x203A3E, skyBottom: 0x8E8366, far: 0x2B3F42, mid: 0x152628, near: 0x0A1314, accent: 0xD2B06A, cream: 0xE9DFC4, night: false),
        Pal(skyTop: 0x0B1322, skyBottom: 0x29384D, far: 0x1E2B3A, mid: 0x111B25, near: 0x080D13, accent: 0xD9BC74, cream: 0xE6DCC2, night: true),
        Pal(skyTop: 0x2E2F1E, skyBottom: 0x8F7F56, far: 0x353A28, mid: 0x1E2215, near: 0x0F110A, accent: 0xCDA660, cream: 0xEADFC2, night: false),
        Pal(skyTop: 0x2B3138, skyBottom: 0x8A8F8E, far: 0x323A42, mid: 0x1B2127, near: 0x0D1013, accent: 0xC9AA6A, cream: 0xE8E2D2, night: false),
        Pal(skyTop: 0x0C150F, skyBottom: 0x2C3A28, far: 0x1C271A, mid: 0x111A10, near: 0x080D07, accent: 0xD8B964, cream: 0xE6DAB8, night: true),
        Pal(skyTop: 0x141631, skyBottom: 0x7E6D52, far: 0x2C2E4A, mid: 0x181A2E, near: 0x0C0D19, accent: 0xDDB46A, cream: 0xEFE2C4, night: true),
        Pal(skyTop: 0x283326, skyBottom: 0x978A66, far: 0x30392C, mid: 0x1A2118, near: 0x0D110C, accent: 0xC4A05E, cream: 0xEDE2C6, night: false),
        Pal(skyTop: 0x1F1828, skyBottom: 0x7E6A5C, far: 0x2C2434, mid: 0x18131E, near: 0x0C0910, accent: 0xD9B062, cream: 0xEDE0C6, night: true),
    ]

    static func paint(_ ctx: inout GraphicsContext, _ size: CGSize, no: Int, compact: Bool) {
        var seed = UInt64(truncatingIfNeeded: no &* 2246822519 &+ 3266489917)
        func r() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(Double(seed >> 33) / Double(1 << 31)) }
        let w = size.width, h = size.height
        let P = pals[(no * 5 + no / 8) % pals.count]
        func col(_ x: UInt32, _ a: Double = 1) -> GraphicsContext.Shading { .color(Color(hex: x).opacity(a)) }
        let horizon = h * (0.56 + r() * 0.06)

        // 天
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [Color(hex: P.skyTop), Color(hex: P.skyBottom)]),
                                                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))
        for _ in 0..<(compact ? 10 : (P.night ? 50 : 18)) {
            let x = r() * w, y = r() * horizon * 0.8, s = 0.5 + r() * (compact ? 0.8 : 1.3)
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: col(P.cream, (P.night ? 0.4 : 0.2) + Double(r()) * 0.4))
        }
        if !compact {
            var con = Path(); var first = true
            let sx = w * (0.1 + r() * 0.3), sy = horizon * (0.1 + r() * 0.2)
            for k in 0..<5 {
                let p0 = CGPoint(x: sx + CGFloat(k) * w * 0.09 + r() * w * 0.04, y: sy + (r() - 0.5) * horizon * 0.18)
                if first { con.move(to: p0); first = false } else { con.addLine(to: p0) }
                ctx.fill(Path(ellipseIn: CGRect(x: p0.x - 1.2, y: p0.y - 1.2, width: 2.4, height: 2.4)), with: col(P.cream, 0.85))
            }
            ctx.stroke(con, with: col(P.cream, 0.28), lineWidth: 0.5)
        }
        // 日 / 月
        let cx = w * (0.3 + r() * 0.4), cy = horizon * (0.32 + r() * 0.2), cr = w * (0.13 + r() * 0.07)
        if P.night && no % 2 == 0 {
            ctx.fill(Path(ellipseIn: CGRect(x: cx - cr, y: cy - cr, width: cr * 2, height: cr * 2)), with: col(P.cream))
            ctx.fill(Path(ellipseIn: CGRect(x: cx - cr * 0.55, y: cy - cr * 1.1, width: cr * 2, height: cr * 2)), with: col(P.skyTop))
        } else {
            ctx.fill(Path(ellipseIn: CGRect(x: cx - cr * 2.6, y: cy - cr * 2.6, width: cr * 5.2, height: cr * 5.2)),
                     with: .radialGradient(Gradient(colors: [Color(hex: P.accent).opacity(0.35), .clear]), center: CGPoint(x: cx, y: cy), startRadius: cr * 0.8, endRadius: cr * 2.6))
            ctx.fill(Path(ellipseIn: CGRect(x: cx - cr, y: cy - cr, width: cr * 2, height: cr * 2)),
                     with: .radialGradient(Gradient(colors: [Color(hex: P.cream), Color(hex: P.accent)]), center: CGPoint(x: cx - cr * 0.3, y: cy - cr * 0.3), startRadius: 0, endRadius: cr * 1.2))
        }
        // 刻纹：同心细环 + 十二道细光芒（像铜版画）
        for k in 1...2 {
            let rr = cr * (1.25 + CGFloat(k) * 0.3)
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - rr, y: cy - rr, width: rr * 2, height: rr * 2)), with: col(P.accent, 0.5 / Double(k)), lineWidth: 0.6)
        }
        if !compact {
            for k in 0..<24 {
                let a = Double(k) / 24 * 2 * .pi, r1 = cr * 1.15, r2 = cr * (k % 2 == 0 ? 2.3 : 1.7)
                var ray = Path(); ray.move(to: CGPoint(x: cx + CGFloat(cos(a)) * r1, y: cy + CGFloat(sin(a)) * r1)); ray.addLine(to: CGPoint(x: cx + CGFloat(cos(a)) * r2, y: cy + CGFloat(sin(a)) * r2))
                ctx.stroke(ray, with: col(P.accent, 0.22), lineWidth: 0.5)
            }
        }
        // 云带
        if !compact || no % 2 == 1 {
            for _ in 0..<Int(1 + r() * 3) {
                let y = horizon * (0.15 + r() * 0.5), x0 = r() * w * 0.5, len = w * (0.3 + r() * 0.4), th = h * 0.025
                ctx.fill(Path(roundedRect: CGRect(x: x0, y: y, width: len, height: th), cornerRadius: th / 2), with: col(P.cream, 0.45))
                ctx.fill(Path(roundedRect: CGRect(x: x0 + len * 0.2, y: y - th * 0.8, width: len * 0.45, height: th), cornerRadius: th / 2), with: col(P.cream, 0.35))
            }
        }
        // 远山
        var mtn = Path(); mtn.move(to: CGPoint(x: 0, y: horizon))
        var x: CGFloat = 0
        while x < w {
            let peak = horizon - h * (0.06 + r() * 0.14)
            mtn.addLine(to: CGPoint(x: x + w * 0.09, y: peak)); x += w * (0.16 + r() * 0.12)
            mtn.addLine(to: CGPoint(x: min(x, w), y: horizon - h * 0.03 * r()))
        }
        mtn.addLine(to: CGPoint(x: w, y: horizon)); mtn.closeSubpath()
        ctx.fill(mtn, with: col(P.far))
        if !compact {
            ctx.drawLayer { l in
                l.clip(to: mtn)
                var hx: CGFloat = -h
                while hx < w {
                    var hl = Path(); hl.move(to: CGPoint(x: hx, y: horizon)); hl.addLine(to: CGPoint(x: hx + h * 0.35, y: horizon - h * 0.35))
                    l.stroke(hl, with: .color(Color(hex: P.cream).opacity(0.07)), lineWidth: 0.5)
                    hx += 3
                }
            }
        }
        // 松林
        func pine(_ bx: CGFloat, _ by: CGFloat, _ ph: CGFloat, _ c: UInt32) {
            var p = Path()
            for t in 0..<3 {
                let top = by - ph * (1 - CGFloat(t) * 0.28), bw = ph * (0.18 + CGFloat(t) * 0.07)
                let base = by - ph * (0.55 - CGFloat(t) * 0.25)
                p.move(to: CGPoint(x: bx, y: top)); p.addLine(to: CGPoint(x: bx - bw, y: base)); p.addLine(to: CGPoint(x: bx + bw, y: base)); p.closeSubpath()
            }
            p.addRect(CGRect(x: bx - ph * 0.025, y: by - ph * 0.3, width: ph * 0.05, height: ph * 0.3))
            ctx.fill(p, with: col(c))
        }
        var px: CGFloat = -w * 0.03
        while px < w * 1.03 {
            pine(px, horizon + h * 0.04, h * (0.16 + r() * 0.16), P.mid); px += w * (0.05 + r() * 0.06)
        }
        ctx.fill(Path(CGRect(x: 0, y: horizon + h * 0.03, width: w, height: h)), with: col(P.mid))
        // 薄雾
        for k in 0..<2 {
            let y = horizon - h * 0.05 + CGFloat(k) * h * 0.07
            ctx.fill(Path(CGRect(x: 0, y: y, width: w, height: h * 0.06)),
                     with: .linearGradient(Gradient(colors: [.clear, Color(hex: P.cream).opacity(0.16), .clear]), startPoint: CGPoint(x: 0, y: y), endPoint: CGPoint(x: 0, y: y + h * 0.06)))
        }
        // 河 / 湖
        let feature = (no * 7) % 3
        if feature == 0 {
            var river = Path()
            river.move(to: CGPoint(x: w * 0.48, y: horizon + h * 0.03)); river.addLine(to: CGPoint(x: w * 0.52, y: horizon + h * 0.03))
            river.addCurve(to: CGPoint(x: w * 0.75, y: h), control1: CGPoint(x: w * 0.7, y: horizon + h * 0.15), control2: CGPoint(x: w * 0.3, y: h * 0.8))
            river.addLine(to: CGPoint(x: w * 0.35, y: h))
            river.addCurve(to: CGPoint(x: w * 0.48, y: horizon + h * 0.03), control1: CGPoint(x: w * 0.2, y: h * 0.8), control2: CGPoint(x: w * 0.6, y: horizon + h * 0.15))
            ctx.fill(river, with: col(P.skyBottom, 0.85))
        } else if feature == 1 {
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.12, y: horizon + h * 0.05, width: w * 0.76, height: h * 0.08)), with: col(P.skyBottom, 0.8))
            ctx.fill(Path(ellipseIn: CGRect(x: cx - cr * 0.6, y: horizon + h * 0.07, width: cr * 1.2, height: h * 0.025)), with: col(P.accent, 0.5))
        }
        // 近地
        var ground = Path(); ground.move(to: CGPoint(x: 0, y: h * 0.8))
        ground.addQuadCurve(to: CGPoint(x: w, y: h * (0.76 + r() * 0.06)), control: CGPoint(x: w * 0.5, y: h * (0.7 + r() * 0.06)))
        ground.addLine(to: CGPoint(x: w, y: h)); ground.addLine(to: CGPoint(x: 0, y: h)); ground.closeSubpath()
        ctx.fill(ground, with: col(P.near))

        // 主角剪影
        let bx = w * (0.38 + r() * 0.24), by = h * 0.8, s = h * (compact ? 0.42 : 0.36)
        let fill = col(P.near)
        let rim = GraphicsContext.Shading.color(Color(hex: P.cream).opacity(0.55))
        func ell(_ x: CGFloat, _ y: CGFloat, _ ww: CGFloat, _ hh: CGFloat) -> Path { Path(ellipseIn: CGRect(x: bx + x * s - ww * s / 2, y: by + y * s - hh * s / 2, width: ww * s, height: hh * s)) }
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: bx + x * s, y: by + y * s) }
        var fig = Path()
        switch (no * 3 + no / 9) % 9 {
        case 0: // 鹿
            fig.addPath(ell(0, -0.5, 0.55, 0.22))
            for lx in [-0.2, -0.12, 0.14, 0.22] { fig.addRect(CGRect(x: bx + CGFloat(lx) * s, y: by - 0.45 * s, width: 0.035 * s, height: 0.45 * s)) }
            var neck = Path(); neck.move(to: pt(0.15, -0.58)); neck.addLine(to: pt(0.3, -0.88)); neck.addLine(to: pt(0.38, -0.86)); neck.addLine(to: pt(0.27, -0.5)); neck.closeSubpath(); fig.addPath(neck)
            fig.addPath(ell(0.38, -0.88, 0.17, 0.09))
            var ant = Path()
            for side in [-1.0, 1.0] {
                let o = pt(0.33 + CGFloat(side) * 0.02, -0.92)
                ant.move(to: o); ant.addLine(to: pt(0.33 + CGFloat(side) * 0.12, -1.15))
                ant.move(to: pt(0.33 + CGFloat(side) * 0.06, -1.03)); ant.addLine(to: pt(0.33 + CGFloat(side) * 0.16, -1.05))
                ant.move(to: pt(0.33 + CGFloat(side) * 0.1, -1.1)); ant.addLine(to: pt(0.33 + CGFloat(side) * 0.06, -1.2))
            }
            ctx.fill(fig, with: fill); ctx.stroke(ant, with: fill, lineWidth: max(1.2, s * 0.025))
            ctx.stroke(fig, with: rim, lineWidth: 0.6)
            fig = Path()
        case 1: // 披斗篷的行者
            fig.move(to: pt(-0.26, 0)); fig.addQuadCurve(to: pt(-0.12, -0.7), control: pt(-0.24, -0.4))
            fig.addQuadCurve(to: pt(0, -1.0), control: pt(-0.13, -0.98)); fig.addQuadCurve(to: pt(0.12, -0.7), control: pt(0.13, -0.98))
            fig.addQuadCurve(to: pt(0.26, 0), control: pt(0.24, -0.4)); fig.closeSubpath()
            ctx.stroke(Path(ellipseIn: CGRect(x: bx - 0.17 * s, y: by - 1.1 * s, width: 0.34 * s, height: 0.34 * s)), with: col(P.accent, 0.8), lineWidth: 1)
            var staff = Path(); staff.move(to: pt(0.3, 0)); staff.addLine(to: pt(0.33, -1.05)); ctx.stroke(staff, with: fill, lineWidth: max(1, s * 0.02))
            ctx.fill(Path(ellipseIn: CGRect(x: bx + 0.29 * s, y: by - 1.12 * s, width: 0.08 * s, height: 0.08 * s)), with: col(P.accent))
        case 2: // 鹤
            fig.addPath(ell(0, -0.55, 0.4, 0.18))
            var neck = Path(); neck.move(to: pt(0.15, -0.6)); neck.addQuadCurve(to: pt(0.22, -1.0), control: pt(0.35, -0.8))
            ctx.stroke(neck, with: fill, lineWidth: max(1.5, s * 0.04))
            fig.addPath(ell(0.24, -1.0, 0.1, 0.06))
            var beak = Path(); beak.move(to: pt(0.28, -1.0)); beak.addLine(to: pt(0.42, -0.97)); ctx.stroke(beak, with: fill, lineWidth: 1.2)
            var legs = Path(); legs.move(to: pt(-0.02, -0.47)); legs.addLine(to: pt(-0.04, 0)); legs.move(to: pt(0.05, -0.47)); legs.addLine(to: pt(0.08, 0)); ctx.stroke(legs, with: fill, lineWidth: 1.2)
            var tail = Path(); tail.move(to: pt(-0.2, -0.55)); tail.addLine(to: pt(-0.36, -0.45)); tail.addLine(to: pt(-0.18, -0.48)); fig.addPath(tail)
        case 3: // 狐（坐）
            fig.addPath(ell(0, -0.28, 0.3, 0.45))
            var head = Path(); head.move(to: pt(-0.14, -0.55)); head.addLine(to: pt(0.14, -0.55)); head.addLine(to: pt(0, -0.38)); head.closeSubpath(); fig.addPath(head)
            var ears = Path(); ears.move(to: pt(-0.14, -0.55)); ears.addLine(to: pt(-0.1, -0.72)); ears.addLine(to: pt(-0.03, -0.56)); ears.move(to: pt(0.14, -0.55)); ears.addLine(to: pt(0.1, -0.72)); ears.addLine(to: pt(0.03, -0.56)); fig.addPath(ears)
            var tail = Path(); tail.move(to: pt(0.1, -0.05)); tail.addQuadCurve(to: pt(0.45, -0.35), control: pt(0.5, 0.05)); tail.addQuadCurve(to: pt(0.12, -0.15), control: pt(0.3, -0.15)); fig.addPath(tail)
        case 4: // 猫头鹰（立在枝上）
            var br = Path(); br.move(to: pt(-0.6, -0.4)); br.addQuadCurve(to: pt(0.6, -0.45), control: pt(0, -0.32)); ctx.stroke(br, with: fill, lineWidth: max(2, s * 0.05))
            fig.addPath(ell(0, -0.65, 0.3, 0.42))
            var ears = Path(); ears.move(to: pt(-0.13, -0.8)); ears.addLine(to: pt(-0.12, -0.92)); ears.addLine(to: pt(-0.04, -0.84)); ears.move(to: pt(0.13, -0.8)); ears.addLine(to: pt(0.12, -0.92)); ears.addLine(to: pt(0.04, -0.84)); fig.addPath(ears)
            ctx.fill(fig, with: fill); ctx.stroke(fig, with: rim, lineWidth: 0.6)
            for ex in [-0.06, 0.06] { ctx.fill(ell(CGFloat(ex), -0.74, 0.07, 0.07), with: col(P.accent)) }
            fig = Path()
        case 5: // 孤树
            fig.addRect(CGRect(x: bx - 0.04 * s, y: by - 0.55 * s, width: 0.08 * s, height: 0.55 * s))
            for (dx, dy, rr) in [(0.0, -0.8, 0.3), (-0.22, -0.65, 0.22), (0.22, -0.66, 0.22), (-0.1, -1.0, 0.2), (0.12, -0.98, 0.2)] {
                fig.addPath(ell(CGFloat(dx), CGFloat(dy), CGFloat(rr) * 2, CGFloat(rr) * 1.7))
            }
        case 6: // 山居
            fig.addRect(CGRect(x: bx - 0.25 * s, y: by - 0.35 * s, width: 0.5 * s, height: 0.35 * s))
            var roof = Path(); roof.move(to: pt(-0.36, -0.33)); roof.addQuadCurve(to: pt(0, -0.62), control: pt(-0.12, -0.42)); roof.addQuadCurve(to: pt(0.36, -0.33), control: pt(0.12, -0.42)); roof.closeSubpath(); fig.addPath(roof)
            ctx.fill(fig, with: fill); ctx.stroke(fig, with: rim, lineWidth: 0.6)
            ctx.fill(Path(CGRect(x: bx - 0.07 * s, y: by - 0.25 * s, width: 0.14 * s, height: 0.14 * s)), with: col(P.accent))
            fig = Path()
        case 7: // 兔
            fig.addPath(ell(0, -0.17, 0.32, 0.3))
            fig.addPath(ell(0.12, -0.38, 0.16, 0.15))
            fig.addPath(ell(0.1, -0.56, 0.05, 0.22)); fig.addPath(ell(0.16, -0.55, 0.05, 0.22))
        default: break
        }
        if !fig.isEmpty { ctx.fill(fig, with: fill); ctx.stroke(fig, with: rim, lineWidth: 0.6) }

        // 前景花草
        let fg = (no * 11) % 3
        let n = compact ? 4 : 7
        for i in 0..<n {
            let fx = w * (CGFloat(i) + 0.5) / CGFloat(n) + (r() - 0.5) * w * 0.06
            let fh = h * (0.08 + r() * 0.12)
            var stem = Path(); stem.move(to: CGPoint(x: fx, y: h)); stem.addQuadCurve(to: CGPoint(x: fx + (r() - 0.5) * 8, y: h - fh), control: CGPoint(x: fx + (r() - 0.5) * 10, y: h - fh * 0.5))
            ctx.stroke(stem, with: col(P.far), lineWidth: 1)
            let top = CGPoint(x: fx, y: h - fh)
            switch fg {
            case 0: // 芦苇与微光
                var leaf = Path(); leaf.move(to: CGPoint(x: fx, y: h)); leaf.addQuadCurve(to: CGPoint(x: fx + fh * 0.35, y: h - fh * 0.75), control: CGPoint(x: fx + fh * 0.05, y: h - fh * 0.6))
                ctx.stroke(leaf, with: col(P.far), lineWidth: 0.8)
                ctx.fill(Path(ellipseIn: CGRect(x: top.x - 4, y: top.y - 4, width: 8, height: 8)), with: .radialGradient(Gradient(colors: [Color(hex: P.accent).opacity(0.6), .clear]), center: top, startRadius: 0, endRadius: 4))
                ctx.fill(Path(ellipseIn: CGRect(x: top.x - 1.2, y: top.y - 3, width: 2.4, height: 6)), with: col(P.accent, 0.9))
            case 1: // 蕨
                for k in 1...4 {
                    let yy = h - fh * CGFloat(k) / 4.5
                    var lf = Path(); lf.move(to: CGPoint(x: fx, y: yy)); lf.addQuadCurve(to: CGPoint(x: fx - fh * 0.3, y: yy - fh * 0.1), control: CGPoint(x: fx - fh * 0.15, y: yy + 2))
                    lf.move(to: CGPoint(x: fx, y: yy)); lf.addQuadCurve(to: CGPoint(x: fx + fh * 0.3, y: yy - fh * 0.1), control: CGPoint(x: fx + fh * 0.15, y: yy + 2))
                    ctx.stroke(lf, with: col(P.far), lineWidth: 0.8)
                }
            default: // 萤火
                let gp = CGPoint(x: top.x + (r() - 0.5) * 12, y: top.y - r() * h * 0.12)
                ctx.fill(Path(ellipseIn: CGRect(x: gp.x - 5, y: gp.y - 5, width: 10, height: 10)), with: .radialGradient(Gradient(colors: [Color(hex: P.accent).opacity(0.55), .clear]), center: gp, startRadius: 0, endRadius: 5))
                ctx.fill(Path(ellipseIn: CGRect(x: gp.x - 1, y: gp.y - 1, width: 2, height: 2)), with: col(P.cream))
            }
        }

        // 暗角 + 胶片颗粒：让画面沉下去、更像旧牌
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(Gradient(colors: [.clear, Color.black.opacity(0.55)]),
                                                                               center: CGPoint(x: w / 2, y: h * 0.45), startRadius: min(w, h) * 0.35, endRadius: max(w, h) * 0.75))
        for _ in 0..<(compact ? 60 : 420) {
            let x = r() * w, y = r() * h
            ctx.fill(Path(CGRect(x: x, y: y, width: 0.8, height: 0.8)), with: .color((r() > 0.5 ? Color.white : Color.black).opacity(0.10)))
        }
    }
}
