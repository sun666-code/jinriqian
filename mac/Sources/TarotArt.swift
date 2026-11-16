import SwiftUI

// MARK: - 塔罗式签图（原创矢量绘制）：22 种主图 × 7 种夜色 × 星空/光芒随签变化
// 主图：日、月、星、塔、轮、杯、树、莲、葫芦、灯笼、牌坊、双鱼、鹤、峰、沙漏、钥匙、钟、桥、舟、天平、烛、八卦盘。
// 只用黄铜色线条与象牙色高光，底色是深夜蓝、墨绿、深紫、石板灰等，不用红色。

struct TarotArt: View {
    let no: Int
    var level: String = "中平"
    var compact = false
    var body: some View {
        Canvas { ctx, size in TarotArt.paint(&ctx, size, no: no, level: level, compact: compact) }
    }

    static let palettes: [(UInt32, UInt32)] = [(0x1B1F3B, 0x090B17), (0x10343A, 0x061719), (0x16301F, 0x08140C), (0x2A1D3D, 0x110A1C),
                                               (0x22262E, 0x0B0D11), (0x0F2747, 0x050F1D), (0x2E2618, 0x120E07)]
    static let motifNames = ["日", "月", "星", "塔", "轮", "杯", "树", "莲", "葫芦", "灯", "牌坊", "双鱼", "鹤", "峰", "沙漏", "钥", "钟", "桥", "舟", "衡", "烛", "八卦"]
    static func motif(_ no: Int) -> Int { (no * 7 + no / 22) % 22 }

    static func paint(_ ctx: inout GraphicsContext, _ size: CGSize, no: Int, level: String, compact: Bool) {
        var seed = UInt64(truncatingIfNeeded: no &* 40503 &+ 17)
        func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(Double(seed >> 33) / Double(1 << 31)) }
        let w = size.width, h = size.height
        let pal = palettes[(no * 3 + (level == "上上" ? 5 : 0)) % palettes.count]
        let brass = Color(hex: 0xD9C58E), ivory = Color(hex: 0xF3EBD3)
        let lw: CGFloat = compact ? 1.4 : max(1, w / 120)

        // 底色 + 中心光晕
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [Color(hex: pal.0), Color(hex: pal.1)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        let c = CGPoint(x: w / 2, y: h * 0.46)
        let u = min(w, h)
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - u * 0.55, y: c.y - u * 0.55, width: u * 1.1, height: u * 1.1)),
                 with: .radialGradient(Gradient(colors: [brass.opacity(0.28), .clear]), center: c, startRadius: 0, endRadius: u * 0.55))

        // 星空
        for _ in 0..<(compact ? 10 : 46) {
            let x = rnd() * w, y = rnd() * h * 0.8, r = 0.4 + rnd() * (compact ? 0.8 : 1.3)
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(ivory.opacity(0.25 + Double(rnd()) * 0.5)))
        }
        // 背景光芒（一半的签有）
        if no % 2 == 0 {
            for k in 0..<36 {
                let a = Double(k) / 36 * 2 * .pi
                var p = Path()
                p.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * u * 0.3, y: c.y + CGFloat(sin(a)) * u * 0.3))
                p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * u * (k % 2 == 0 ? 0.62 : 0.5), y: c.y + CGFloat(sin(a)) * u * (k % 2 == 0 ? 0.62 : 0.5)))
                ctx.stroke(p, with: .color(brass.opacity(0.12)), lineWidth: 0.6)
            }
        }
        // 地平线（一部分签有）
        if no % 3 != 0 {
            var p = Path(); p.move(to: CGPoint(x: 0, y: h * 0.82)); p.addLine(to: CGPoint(x: w, y: h * 0.82))
            ctx.stroke(p, with: .color(brass.opacity(0.35)), lineWidth: 0.6)
            for i in 1...3 {
                var q = Path(); let y = h * 0.82 + CGFloat(i) * h * 0.04
                q.move(to: CGPoint(x: w * (0.15 + 0.05 * CGFloat(i)), y: y)); q.addLine(to: CGPoint(x: w * (0.85 - 0.05 * CGFloat(i)), y: y))
                ctx.stroke(q, with: .color(brass.opacity(0.18)), lineWidth: 0.5)
            }
        }

        let s = u * (compact ? 0.42 : 0.36)          // 主图尺度
        let line = GraphicsContext.Shading.color(brass)
        let fillS = GraphicsContext.Shading.color(brass.opacity(0.16))
        let hi = GraphicsContext.Shading.color(ivory)
        let st = StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
        func circle(_ p: CGPoint, _ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)) }
        func star(_ p: CGPoint, _ r1: CGFloat, _ r2: CGFloat, _ n: Int, rot: Double = -.pi / 2) -> Path {
            var path = Path()
            for i in 0..<(n * 2) {
                let a = rot + Double(i) * .pi / Double(n), r = i % 2 == 0 ? r1 : r2
                let pt = CGPoint(x: p.x + CGFloat(cos(a)) * r, y: p.y + CGFloat(sin(a)) * r)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath(); return path
        }
        func draw(_ p: Path, fill: Bool = true) { if fill { ctx.fill(p, with: fillS) }; ctx.stroke(p, with: line, style: st) }
        func pt(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: c.x + dx * s, y: c.y + dy * s) }

        switch motif(no) {
        case 0: // 日
            draw(circle(c, s * 0.42))
            ctx.stroke(circle(c, s * 0.3), with: line, lineWidth: lw * 0.7)
            for k in 0..<24 {
                let a = Double(k) / 24 * 2 * .pi, r2 = s * (k % 2 == 0 ? 0.95 : 0.72)
                var p = Path(); p.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * s * 0.5, y: c.y + CGFloat(sin(a)) * s * 0.5))
                p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * r2, y: c.y + CGFloat(sin(a)) * r2)); ctx.stroke(p, with: line, style: st)
            }
        case 1: // 月
            ctx.fill(circle(c, s * 0.62), with: hi)
            ctx.fill(circle(pt(0.28, -0.12), s * 0.56), with: .color(Color(hex: pal.0)))
            for k in 0..<3 { ctx.fill(star(pt(0.55 + CGFloat(k) * 0.12, -0.5 + CGFloat(k) * 0.35), s * 0.08, s * 0.03, 4), with: hi) }
            for k in 0..<3 { var p = Path(); p.move(to: pt(-0.7 + CGFloat(k) * 0.2, 0.9 + CGFloat(k) * 0.12)); p.addLine(to: pt(0.7 - CGFloat(k) * 0.2, 0.9 + CGFloat(k) * 0.12)); ctx.stroke(p, with: line, lineWidth: lw * 0.6) }
        case 2: // 星
            draw(star(c, s * 0.75, s * 0.26, 8))
            ctx.fill(star(c, s * 0.3, s * 0.1, 4), with: hi)
            for k in 0..<7 {
                let a = Double(k) / 7 * 2 * .pi
                ctx.fill(star(CGPoint(x: c.x + CGFloat(cos(a)) * s, y: c.y + CGFloat(sin(a)) * s), s * 0.09, s * 0.03, 4), with: hi)
            }
        case 3: // 塔
            for i in 0..<5 {
                let y = 0.75 - CGFloat(i) * 0.32, hw = 0.55 - CGFloat(i) * 0.08
                var roof = Path()
                roof.move(to: pt(-hw - 0.12, y - 0.02)); roof.addQuadCurve(to: pt(0, y - 0.16), control: pt(-hw * 0.5, y - 0.04))
                roof.addQuadCurve(to: pt(hw + 0.12, y - 0.02), control: pt(hw * 0.5, y - 0.04))
                ctx.stroke(roof, with: line, style: st)
                draw(Path(CGRect(x: c.x - (hw - 0.1) * s, y: c.y + (y - 0.02) * s, width: (hw - 0.1) * 2 * s, height: 0.26 * s)))
            }
            var spire = Path(); spire.move(to: pt(0, -0.85)); spire.addLine(to: pt(0, -1.1)); ctx.stroke(spire, with: line, style: st)
            ctx.fill(circle(pt(0, -1.12), s * 0.05), with: hi)
        case 4: // 轮
            draw(circle(c, s * 0.8)); ctx.stroke(circle(c, s * 0.55), with: line, lineWidth: lw)
            draw(circle(c, s * 0.12))
            for k in 0..<8 {
                let a = Double(k) / 8 * 2 * .pi
                var p = Path(); p.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * s * 0.12, y: c.y + CGFloat(sin(a)) * s * 0.12))
                p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * s * 0.8, y: c.y + CGFloat(sin(a)) * s * 0.8)); ctx.stroke(p, with: line, style: st)
                ctx.fill(circle(CGPoint(x: c.x + CGFloat(cos(a + .pi / 8)) * s * 0.68, y: c.y + CGFloat(sin(a + .pi / 8)) * s * 0.68), s * 0.04), with: hi)
            }
        case 5: // 杯
            var cup = Path()
            cup.move(to: pt(-0.55, -0.45)); cup.addQuadCurve(to: pt(0.55, -0.45), control: pt(0, 0.55))
            cup.closeSubpath(); draw(cup)
            var stem = Path(); stem.move(to: pt(0, 0.05)); stem.addLine(to: pt(0, 0.6)); ctx.stroke(stem, with: line, style: st)
            draw(Path(ellipseIn: CGRect(x: c.x - 0.35 * s, y: c.y + 0.58 * s, width: 0.7 * s, height: 0.16 * s)))
            for k in 0..<3 { var w2 = Path(); let x = -0.3 + CGFloat(k) * 0.3; w2.move(to: pt(x, -0.55)); w2.addQuadCurve(to: pt(x + 0.05, -1.0), control: pt(x + 0.2, -0.8)); ctx.stroke(w2, with: hi, lineWidth: lw * 0.8) }
        case 6: // 树
            func branch(_ a: CGPoint, _ ang: Double, _ len: CGFloat, _ d: Int) {
                let b = CGPoint(x: a.x + CGFloat(cos(ang)) * len, y: a.y + CGFloat(sin(ang)) * len)
                var p = Path(); p.move(to: a); p.addLine(to: b); ctx.stroke(p, with: line, lineWidth: lw * CGFloat(d) * 0.5 + 0.4)
                if d > 0 { branch(b, ang - 0.45, len * 0.7, d - 1); branch(b, ang + 0.45, len * 0.7, d - 1) }
                else { ctx.fill(circle(b, s * 0.035), with: hi) }
            }
            branch(pt(0, 0.85), -.pi / 2, s * 0.55, 4)
            for k in [-1.0, 1.0] { var r = Path(); r.move(to: pt(0, 0.85)); r.addQuadCurve(to: pt(CGFloat(k) * 0.5, 1.05), control: pt(CGFloat(k) * 0.15, 1.0)); ctx.stroke(r, with: line, style: st) }
        case 7: // 莲
            for k in 0..<7 {
                let a = -Double.pi / 2 + (Double(k) - 3) * 0.38
                var petal = Path()
                petal.move(to: pt(0, 0.4))
                let tip = CGPoint(x: c.x + CGFloat(cos(a)) * s * 0.85, y: c.y + 0.4 * s + CGFloat(sin(a)) * s * 0.85)
                petal.addQuadCurve(to: tip, control: CGPoint(x: c.x + CGFloat(cos(a - 0.3)) * s * 0.55, y: c.y + 0.4 * s + CGFloat(sin(a - 0.3)) * s * 0.55))
                petal.addQuadCurve(to: pt(0, 0.4), control: CGPoint(x: c.x + CGFloat(cos(a + 0.3)) * s * 0.55, y: c.y + 0.4 * s + CGFloat(sin(a + 0.3)) * s * 0.55))
                draw(petal)
            }
            for k in 0..<3 { ctx.stroke(Path(ellipseIn: CGRect(x: c.x - s * (0.4 + CGFloat(k) * 0.25), y: c.y + s * (0.5 + CGFloat(k) * 0.08), width: s * (0.8 + CGFloat(k) * 0.5), height: s * 0.16)), with: line, lineWidth: lw * 0.6) }
        case 8: // 葫芦
            draw(circle(pt(0, -0.35), s * 0.28)); draw(circle(pt(0, 0.3), s * 0.45))
            var st2 = Path(); st2.move(to: pt(0, -0.62)); st2.addLine(to: pt(0.05, -0.82)); ctx.stroke(st2, with: line, style: st)
            var leaf = Path(); leaf.move(to: pt(0.05, -0.78)); leaf.addQuadCurve(to: pt(0.4, -0.9), control: pt(0.25, -1.0)); leaf.addQuadCurve(to: pt(0.05, -0.78), control: pt(0.22, -0.72)); draw(leaf)
            var band = Path(); band.move(to: pt(-0.2, -0.08)); band.addLine(to: pt(0.2, -0.08)); ctx.stroke(band, with: hi, lineWidth: lw * 1.4)
        case 9: // 灯
            draw(Path(ellipseIn: CGRect(x: c.x - 0.5 * s, y: c.y - 0.55 * s, width: s, height: 1.1 * s)))
            for k in [-0.3, 0.0, 0.3] { var r = Path(); r.move(to: pt(CGFloat(k), -0.53)); r.addQuadCurve(to: pt(CGFloat(k), 0.53), control: pt(CGFloat(k) * 1.9, 0)); ctx.stroke(r, with: line, lineWidth: lw * 0.7) }
            draw(Path(CGRect(x: c.x - 0.25 * s, y: c.y - 0.68 * s, width: 0.5 * s, height: 0.14 * s)))
            draw(Path(CGRect(x: c.x - 0.25 * s, y: c.y + 0.54 * s, width: 0.5 * s, height: 0.14 * s)))
            for k in -2...2 { var t = Path(); t.move(to: pt(CGFloat(k) * 0.06, 0.68)); t.addLine(to: pt(CGFloat(k) * 0.08, 1.0)); ctx.stroke(t, with: line, lineWidth: lw * 0.6) }
            ctx.fill(circle(c, s * 0.12), with: .color(ivory.opacity(0.7)))
        case 10: // 牌坊
            ctx.fill(circle(pt(0, -0.1), s * 0.35), with: .color(ivory.opacity(0.85)))
            for x in [-0.6, 0.6] { draw(Path(CGRect(x: c.x + CGFloat(x) * s - 0.06 * s, y: c.y - 0.55 * s, width: 0.12 * s, height: 1.4 * s))) }
            for (y, ext) in [(-0.62, 0.95), (-0.35, 0.8)] {
                var beam = Path(); beam.move(to: pt(-CGFloat(ext), CGFloat(y) - 0.08)); beam.addQuadCurve(to: pt(CGFloat(ext), CGFloat(y) - 0.08), control: pt(0, CGFloat(y) + 0.05))
                ctx.stroke(beam, with: line, style: StrokeStyle(lineWidth: lw * 2, lineCap: .round))
            }
            var path = Path(); path.move(to: pt(-0.35, 0.85)); path.addLine(to: pt(0, 0.2)); path.addLine(to: pt(0.35, 0.85)); ctx.stroke(path, with: line, lineWidth: lw * 0.7)
        case 11: // 双鱼
            for k in 0..<2 {
                let sign: CGFloat = k == 0 ? 1 : -1
                var f = Path()
                f.move(to: pt(-0.5 * sign, -0.2 * sign))
                f.addQuadCurve(to: pt(0.45 * sign, 0.1 * sign), control: pt(0, -0.75 * sign))
                f.addQuadCurve(to: pt(-0.5 * sign, -0.2 * sign), control: pt(0, 0.25 * sign))
                draw(f)
                var tail = Path(); tail.move(to: pt(0.45 * sign, 0.1 * sign)); tail.addLine(to: pt(0.7 * sign, -0.05 * sign)); tail.addLine(to: pt(0.65 * sign, 0.3 * sign)); tail.closeSubpath(); draw(tail)
                ctx.fill(circle(pt(-0.3 * sign, -0.25 * sign), s * 0.04), with: hi)
            }
            ctx.stroke(circle(c, s * 0.95), with: line, lineWidth: lw * 0.6)
        case 12: // 鹤
            ctx.fill(circle(pt(0.4, -0.5), s * 0.32), with: .color(ivory.opacity(0.85)))
            var body = Path(); body.move(to: pt(-0.4, 0.1)); body.addQuadCurve(to: pt(0.4, 0.05), control: pt(0, 0.3)); ctx.stroke(body, with: hi, style: StrokeStyle(lineWidth: lw * 2, lineCap: .round))
            for k in [-1.0, 1.0] {
                var wing = Path(); wing.move(to: pt(0, 0.12)); wing.addQuadCurve(to: pt(0.15 * CGFloat(k) - 0.1, -0.75), control: pt(0.6 * CGFloat(k), -0.3)); ctx.stroke(wing, with: line, style: st)
                var wing2 = Path(); wing2.move(to: pt(0, 0.12)); wing2.addQuadCurve(to: pt(0.4 * CGFloat(k), -0.55), control: pt(0.75 * CGFloat(k), -0.05)); ctx.stroke(wing2, with: line, lineWidth: lw * 0.7)
            }
            var neck = Path(); neck.move(to: pt(-0.4, 0.1)); neck.addQuadCurve(to: pt(-0.75, -0.15), control: pt(-0.65, 0.15)); ctx.stroke(neck, with: hi, lineWidth: lw)
            var legs = Path(); legs.move(to: pt(0.35, 0.08)); legs.addLine(to: pt(0.85, 0.35)); ctx.stroke(legs, with: line, lineWidth: lw * 0.7)
        case 13: // 峰
            ctx.fill(circle(pt(0, -0.55), s * 0.25), with: .color(ivory.opacity(0.9)))
            var m = Path(); m.move(to: pt(-1.1, 0.85)); m.addLine(to: pt(-0.45, -0.1)); m.addLine(to: pt(-0.2, 0.2)); m.addLine(to: pt(0.15, -0.35)); m.addLine(to: pt(0.6, 0.25)); m.addLine(to: pt(0.8, 0.05)); m.addLine(to: pt(1.1, 0.85)); m.closeSubpath(); draw(m)
            var snow = Path(); snow.move(to: pt(0.03, -0.2)); snow.addLine(to: pt(0.15, -0.35)); snow.addLine(to: pt(0.27, -0.18)); ctx.stroke(snow, with: hi, lineWidth: lw)
            var cloud = Path(); cloud.move(to: pt(-0.9, 0.35)); cloud.addQuadCurve(to: pt(-0.2, 0.35), control: pt(-0.55, 0.15)); ctx.stroke(cloud, with: hi, lineWidth: lw * 0.8)
        case 14: // 沙漏
            for y in [-0.85, 0.85] { draw(Path(CGRect(x: c.x - 0.55 * s, y: c.y + CGFloat(y) * s - 0.05 * s, width: 1.1 * s, height: 0.1 * s))) }
            var g = Path(); g.move(to: pt(-0.4, -0.8)); g.addLine(to: pt(0.4, -0.8)); g.addLine(to: pt(0.05, 0)); g.addLine(to: pt(0.4, 0.8)); g.addLine(to: pt(-0.4, 0.8)); g.addLine(to: pt(-0.05, 0)); g.closeSubpath(); draw(g)
            var sand = Path(); sand.move(to: pt(-0.3, 0.78)); sand.addQuadCurve(to: pt(0.3, 0.78), control: pt(0, 0.4)); ctx.fill(sand, with: .color(ivory.opacity(0.7)))
            var fall = Path(); fall.move(to: pt(0, 0)); fall.addLine(to: pt(0, 0.5)); ctx.stroke(fall, with: hi, style: StrokeStyle(lineWidth: lw * 0.7, dash: [2, 2]))
        case 15: // 钥
            ctx.stroke(circle(pt(0, -0.55), s * 0.28), with: line, style: st); ctx.stroke(circle(pt(0, -0.55), s * 0.12), with: line, lineWidth: lw * 0.7)
            var shaft = Path(); shaft.move(to: pt(0, -0.27)); shaft.addLine(to: pt(0, 0.85)); ctx.stroke(shaft, with: line, style: StrokeStyle(lineWidth: lw * 1.8, lineCap: .round))
            for y in [0.55, 0.75] { var t = Path(); t.move(to: pt(0, CGFloat(y))); t.addLine(to: pt(0.25, CGFloat(y))); ctx.stroke(t, with: line, style: StrokeStyle(lineWidth: lw * 1.6, lineCap: .round)) }
            for k in 0..<4 { ctx.fill(star(pt(-0.7 + CGFloat(k % 2) * 1.4, -0.7 + CGFloat(k / 2) * 1.3), s * 0.08, s * 0.03, 4), with: hi) }
        case 16: // 钟
            var bell = Path()
            bell.move(to: pt(-0.6, 0.55)); bell.addQuadCurve(to: pt(-0.3, -0.5), control: pt(-0.45, -0.1))
            bell.addQuadCurve(to: pt(0.3, -0.5), control: pt(0, -0.75)); bell.addQuadCurve(to: pt(0.6, 0.55), control: pt(0.45, -0.1)); bell.closeSubpath(); draw(bell)
            for y in [0.0, 0.3] { var b = Path(); b.move(to: pt(-0.47, CGFloat(y))); b.addLine(to: pt(0.47, CGFloat(y))); ctx.stroke(b, with: line, lineWidth: lw * 0.6) }
            ctx.fill(circle(pt(0, 0.7), s * 0.1), with: hi)
            var rope = Path(); rope.move(to: pt(0, -0.65)); rope.addLine(to: pt(0, -1.05)); ctx.stroke(rope, with: line, style: st)
        case 17: // 桥
            ctx.fill(circle(pt(0.45, -0.6), s * 0.2), with: .color(ivory.opacity(0.85)))
            var arch = Path(); arch.move(to: pt(-1.0, 0.25)); arch.addQuadCurve(to: pt(1.0, 0.25), control: pt(0, -0.75)); ctx.stroke(arch, with: line, style: StrokeStyle(lineWidth: lw * 2, lineCap: .round))
            var under = Path(); under.move(to: pt(-0.55, 0.25)); under.addQuadCurve(to: pt(0.55, 0.25), control: pt(0, -0.35)); ctx.stroke(under, with: line, lineWidth: lw)
            var refl = Path(); refl.move(to: pt(-0.55, 0.3)); refl.addQuadCurve(to: pt(0.55, 0.3), control: pt(0, 0.85)); ctx.stroke(refl, with: line, style: StrokeStyle(lineWidth: lw * 0.6, dash: [3, 3]))
        case 18: // 舟
            ctx.fill(circle(pt(-0.45, -0.6), s * 0.22), with: .color(ivory.opacity(0.85)))
            var hull = Path(); hull.move(to: pt(-0.75, 0.35)); hull.addQuadCurve(to: pt(0.75, 0.35), control: pt(0, 0.75)); hull.closeSubpath(); draw(hull)
            var mast = Path(); mast.move(to: pt(0, 0.35)); mast.addLine(to: pt(0, -0.75)); ctx.stroke(mast, with: line, style: st)
            var sail = Path(); sail.move(to: pt(0.05, -0.7)); sail.addLine(to: pt(0.6, 0.2)); sail.addLine(to: pt(0.05, 0.2)); sail.closeSubpath(); draw(sail)
            for k in 0..<3 { var wv = Path(); let y = 0.62 + CGFloat(k) * 0.13; wv.move(to: pt(-0.9, y)); wv.addQuadCurve(to: pt(0.9, y), control: pt(0, y - 0.1)); ctx.stroke(wv, with: line, lineWidth: lw * 0.6) }
        case 19: // 衡
            var pole = Path(); pole.move(to: pt(0, -0.75)); pole.addLine(to: pt(0, 0.75)); ctx.stroke(pole, with: line, style: StrokeStyle(lineWidth: lw * 1.6, lineCap: .round))
            var beam = Path(); beam.move(to: pt(-0.75, -0.5)); beam.addLine(to: pt(0.75, -0.5)); ctx.stroke(beam, with: line, style: st)
            for x in [-0.75, 0.75] {
                var ch = Path(); ch.move(to: pt(CGFloat(x), -0.5)); ch.addLine(to: pt(CGFloat(x) - 0.22, 0.05)); ch.move(to: pt(CGFloat(x), -0.5)); ch.addLine(to: pt(CGFloat(x) + 0.22, 0.05)); ctx.stroke(ch, with: line, lineWidth: lw * 0.6)
                var pan = Path(); pan.move(to: pt(CGFloat(x) - 0.28, 0.05)); pan.addQuadCurve(to: pt(CGFloat(x) + 0.28, 0.05), control: pt(CGFloat(x), 0.3)); pan.closeSubpath(); draw(pan)
            }
            draw(Path(CGRect(x: c.x - 0.3 * s, y: c.y + 0.75 * s, width: 0.6 * s, height: 0.1 * s)))
            ctx.fill(circle(pt(0, -0.78), s * 0.06), with: hi)
        case 20: // 烛
            draw(Path(CGRect(x: c.x - 0.18 * s, y: c.y - 0.1 * s, width: 0.36 * s, height: 0.95 * s)))
            var flame = Path(); flame.move(to: pt(0, -0.75)); flame.addQuadCurve(to: pt(0, -0.12), control: pt(0.3, -0.3)); flame.addQuadCurve(to: pt(0, -0.75), control: pt(-0.3, -0.3)); ctx.fill(flame, with: .color(ivory.opacity(0.9)))
            ctx.fill(circle(pt(0, -0.4), s * 0.5), with: .radialGradient(Gradient(colors: [ivory.opacity(0.35), .clear]), center: pt(0, -0.4), startRadius: 0, endRadius: s * 0.5))
            draw(Path(ellipseIn: CGRect(x: c.x - 0.45 * s, y: c.y + 0.82 * s, width: 0.9 * s, height: 0.16 * s)))
        default: // 八卦盘
            var oct = Path()
            for i in 0..<8 { let a = Double(i) / 8 * 2 * .pi - .pi / 8; let p0 = CGPoint(x: c.x + CGFloat(cos(a)) * s * 0.85, y: c.y + CGFloat(sin(a)) * s * 0.85); if i == 0 { oct.move(to: p0) } else { oct.addLine(to: p0) } }
            oct.closeSubpath(); draw(oct)
            ctx.stroke(circle(c, s * 0.3), with: line, lineWidth: lw)
            let tri: [[Int]] = [[1, 1, 1], [0, 1, 1], [1, 0, 1], [0, 0, 1], [1, 1, 0], [0, 1, 0], [1, 0, 0], [0, 0, 0]]
            for i in 0..<8 {
                let a = Double(i) / 8 * 2 * .pi
                for j in 0..<3 {
                    let r = s * (0.48 + CGFloat(j) * 0.1)
                    let cx = c.x + CGFloat(cos(a)) * r, cy = c.y + CGFloat(sin(a)) * r
                    let tx = CGFloat(-sin(a)), ty = CGFloat(cos(a)), half = s * 0.13
                    var b = Path()
                    if tri[i][j] == 1 { b.move(to: CGPoint(x: cx - tx * half, y: cy - ty * half)); b.addLine(to: CGPoint(x: cx + tx * half, y: cy + ty * half)) }
                    else {
                        b.move(to: CGPoint(x: cx - tx * half, y: cy - ty * half)); b.addLine(to: CGPoint(x: cx - tx * half * 0.25, y: cy - ty * half * 0.25))
                        b.move(to: CGPoint(x: cx + tx * half * 0.25, y: cy + ty * half * 0.25)); b.addLine(to: CGPoint(x: cx + tx * half, y: cy + ty * half))
                    }
                    ctx.stroke(b, with: line, lineWidth: lw)
                }
            }
            ctx.fill(circle(c, s * 0.1), with: hi)
        }
    }
}

/// 拱顶窗（塔罗牌常见的画框）
struct ArchWindow: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let rad = r.width / 2
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + rad))
        p.addArc(center: CGPoint(x: r.midX, y: r.minY + rad), radius: rad, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
