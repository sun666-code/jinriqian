// 生成 App 图标：夜蓝圆角方块 + 黄铜星盘环 + 一张微斜的塔罗式签牌（日、松林、方印），无红色
import AppKit
let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
func rgb(_ h: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: a)
}
func draw(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.1
    let box = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let sq = NSBezierPath(roundedRect: box, xRadius: box.width * 0.225, yRadius: box.width * 0.225)
    NSGradient(colors: [rgb(0x232848), rgb(0x0A0C18)])!.draw(in: sq, angle: -90)
    NSGraphicsContext.current?.saveGraphicsState(); sq.addClip()
    // 光晕 + 星点
    NSGradient(colors: [rgb(0xD9C58E, 0.28), rgb(0xD9C58E, 0)])!.draw(fromCenter: NSPoint(x: s / 2, y: s / 2), radius: 0, toCenter: NSPoint(x: s / 2, y: s / 2), radius: s * 0.42, options: [])
    var seed: UInt64 = 7
    func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(Double(seed >> 33) / Double(1 << 31)) }
    if px >= 64 {
        for _ in 0..<40 {
            let x = box.minX + rnd() * box.width, y = box.minY + rnd() * box.height, r = s * (0.002 + rnd() * 0.004)
            rgb(0xF3EBD3, 0.3 + rnd() * 0.5).setFill(); NSBezierPath(ovalIn: NSRect(x: x, y: y, width: r * 2, height: r * 2)).fill()
        }
    }
    // 星盘环 + 刻度
    let c = NSPoint(x: s / 2, y: s / 2), R = s * 0.34
    rgb(0xD9C58E, 0.55).setStroke()
    let ring = NSBezierPath(ovalIn: NSRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2)); ring.lineWidth = max(1, s * 0.006); ring.stroke()
    for k in 0..<24 {
        let a = CGFloat(k) / 24 * .pi * 2, l = k % 2 == 0 ? s * 0.03 : s * 0.016
        let t = NSBezierPath(); t.move(to: NSPoint(x: c.x + cos(a) * R, y: c.y + sin(a) * R)); t.line(to: NSPoint(x: c.x + cos(a) * (R + l), y: c.y + sin(a) * (R + l)))
        t.lineWidth = max(1, s * 0.005); t.stroke()
    }
    NSGraphicsContext.current?.restoreGraphicsState()
    // 签牌（微斜）
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.translateBy(x: c.x, y: c.y); ctx.rotate(by: 0.1); ctx.translateBy(x: -c.x, y: -c.y)
    let cw = s * 0.36, ch = s * 0.54
    let card = NSRect(x: c.x - cw / 2, y: c.y - ch / 2, width: cw, height: ch)
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.5); shadow.shadowBlurRadius = s * 0.04; shadow.shadowOffset = NSSize(width: 0, height: -s * 0.015)
    NSGraphicsContext.current?.saveGraphicsState(); shadow.set()
    let cp = NSBezierPath(roundedRect: card, xRadius: cw * 0.09, yRadius: cw * 0.09)
    NSGradient(colors: [rgb(0xF4EDDB), rgb(0xE3D7B9)])!.draw(in: cp, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()
    rgb(0xC9B37E).setFill(); cp.lineWidth = max(1, s * 0.006); rgb(0xC9B37E).setStroke(); cp.stroke()
    // 画面
    let art = NSRect(x: card.minX + cw * 0.09, y: card.minY + ch * 0.27, width: cw * 0.82, height: ch * 0.64)
    let ap = NSBezierPath(roundedRect: art, xRadius: cw * 0.04, yRadius: cw * 0.04)
    NSGraphicsContext.current?.saveGraphicsState(); ap.addClip()
    NSGradient(colors: [rgb(0x1B1F3B), rgb(0x3E5266)])!.draw(in: art, angle: -90)
    let sunR = cw * 0.17
    rgb(0xE6B866).setFill(); NSBezierPath(ovalIn: NSRect(x: art.midX - sunR, y: art.minY + art.height * 0.56, width: sunR * 2, height: sunR * 2)).fill()
    rgb(0x17242E).setFill()
    let pines = NSBezierPath()
    var x = art.minX - cw * 0.05
    var i = 0
    while x < art.maxX + cw * 0.05 {
        let hgt = art.height * (i % 2 == 0 ? 0.42 : 0.3), bw = cw * 0.1
        pines.move(to: NSPoint(x: x, y: art.minY + art.height * 0.18 + hgt)); pines.line(to: NSPoint(x: x - bw, y: art.minY + art.height * 0.16)); pines.line(to: NSPoint(x: x + bw, y: art.minY + art.height * 0.16)); pines.close()
        x += cw * 0.13; i += 1
    }
    pines.fill()
    rgb(0x0D151B).setFill(); NSBezierPath(rect: NSRect(x: art.minX, y: art.minY, width: art.width, height: art.height * 0.18)).fill()
    NSGraphicsContext.current?.restoreGraphicsState()
    rgb(0x2A2418, 0.85).setStroke(); ap.lineWidth = max(1, s * 0.004); ap.stroke()
    // 底部「签」字方印（墨色）
    let sealS = cw * 0.24
    let seal = NSRect(x: card.midX - sealS / 2, y: card.minY + ch * 0.045, width: sealS, height: sealS)
    let sp = NSBezierPath(roundedRect: seal, xRadius: sealS * 0.16, yRadius: sealS * 0.16)
    rgb(0x2A2418).setFill(); sp.fill()
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let font = NSFont(name: "Songti SC Bold", size: sealS * 0.62) ?? NSFont.boldSystemFont(ofSize: sealS * 0.62)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: rgb(0xF4EDDB), .paragraphStyle: para]
    ("签" as NSString).draw(in: NSRect(x: seal.minX, y: seal.minY + sealS * 0.12, width: sealS, height: sealS * 0.8), withAttributes: attrs)
    ctx.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                   ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! draw(px).write(to: URL(fileURLWithPath: out + "/icon_\(name).png"))
}
