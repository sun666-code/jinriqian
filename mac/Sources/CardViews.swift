import SwiftUI

// MARK: - 纸张色调（无红色、无荧光：象牙 / 淡紫 / 天蓝 / 薄荷 / 柠檬黄 / 雾灰）

enum Tone {
    static let paper: [UInt32] = [0xF5EFDF, 0xDDD5FF, 0xD5E5FA, 0xD4EEE3, 0xFBF0B8, 0xE4E6EB]
    static let paperDeep: [UInt32] = [0xE8DEC4, 0xC8BBF7, 0xBBD3F3, 0xBCE2D2, 0xF3E194, 0xD2D5DD]
    static func color(_ i: Int, dark: Bool = false) -> Color { Color(hex: paper[((i % 6) + 6) % 6]) }
    static func deep(_ i: Int, dark: Bool = false) -> Color { Color(hex: paperDeep[((i % 6) + 6) % 6]) }
}

let paperInk = Color(hex: 0x1A1A1E)

// MARK: - 签纸（牌堆里的一张，横向）

struct SlipBack: View {
    @Environment(\.pal) private var p
    var index: Int
    var focused: Bool
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let tone = Draw.toneFor(index)
        ZStack {
            shape.fill(LinearGradient(colors: p.dark ? [Color(hex: 0x3A3A3E), Color(hex: 0x252528)] : [Color.white, Color(hex: 0xF0F0F3)],
                                      startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .leading) {
                    Rectangle().fill(LinearGradient(colors: [Tone.color(tone), Tone.deep(tone)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 54)
                }
                .overlay(alignment: .center) {
                    ZStack {
                        ForEach(0..<3) { i in
                            Circle().strokeBorder(p.ink.opacity(0.10 - Double(i) * 0.025), lineWidth: 1)
                                .frame(width: CGFloat(44 + i * 30), height: CGFloat(44 + i * 30))
                        }
                        Circle().fill(focused ? p.tint : p.ink3).frame(width: 9, height: 9)
                            .shadow(color: p.tint.opacity(focused ? 0.7 : 0), radius: 8)
                    }
                    .offset(x: 20)
                }
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    ForEach(I18n.en ? ["D", "A", "Y"] : ["今", "日", "签"], id: \.self) { Text($0).font(Typo.song(14, bold: true)) }
                }
                .foregroundColor(paperInk.opacity(0.75))
                .frame(width: 54)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(String(format: "No.%04d", index)).font(Typo.num(11, .semibold)).foregroundColor(p.ink3)
                    Spacer()
                    Image(systemName: "sparkle").font(.system(size: 10, weight: .bold)).foregroundColor(p.ink3)
                }
                .padding(14)
            }
            shape.fill(LinearGradient(colors: [Color.white.opacity(p.dark ? 0.10 : 0.55), .clear], startPoint: .top, endPoint: .center))
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(LinearGradient(colors: [p.strokeTop, p.strokeBottom], startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }
}

extension Draw {
    static func toneFor(_ i: Int) -> Int { Int(mix(UInt64(bitPattern: Int64(i)) &+ 77) % 6) }
}

// MARK: - 签面

struct LotFace: View {
    @Environment(\.pal) private var p
    let lot: Lot
    var date: Date
    var compact = false
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: compact ? 18 : 26, style: .continuous)
        let ink = paperInk
        let lines = lot.poem.replacingOccurrences(of: "。", with: "").split(separator: "，").map(String.init)
        ZStack {
            shape.fill(LinearGradient(colors: [Tone.color(lot.tone), Tone.deep(lot.tone)],
                                      startPoint: .top, endPoint: .bottom))
                .overlay(
                    GeometryReader { g in
                        Circle().fill(RadialGradient(colors: [Color.white.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: g.size.width * 0.6))
                            .frame(width: g.size.width * 1.2, height: g.size.width * 1.2)
                            .position(x: g.size.width * 0.2, y: g.size.height * 0.05)
                    }
                )
            VStack(spacing: 0) {
                if compact {
                    Text(lot.level).font(Typo.ui(9, .bold)).foregroundColor(Tone.color(lot.tone))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(ink))
                } else {
                    HStack {
                        Text(lot.noText).font(Typo.song(13, bold: true)).foregroundColor(ink.opacity(0.7))
                        Spacer()
                        Text(lot.levelText)
                            .font(Typo.ui(11.5, .bold)).foregroundColor(Tone.color(lot.tone))
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Capsule().fill(ink))
                    }
                }
                Spacer(minLength: 4)
                VStack(spacing: 0) {
                    ForEach(Array(lot.name), id: \.self) { ch in
                        Text(String(ch)).font(Typo.song(compact ? 22 : 50, bold: true)).foregroundColor(ink)
                    }
                }
                Spacer(minLength: 4)
                if !compact {
                    VStack(spacing: 3) {
                        ForEach(lines, id: \.self) { l in
                            Text(l).font(Typo.song(13)).foregroundColor(ink.opacity(0.78))
                        }
                    }
                    .padding(.bottom, 10)
                }
                if compact {
                    Text(Days.md(date)).font(Typo.ui(8.5, .semibold)).foregroundColor(ink.opacity(0.55))
                } else {
                    HStack {
                        Text(Days.md(date)).font(Typo.ui(11, .semibold))
                        Spacer()
                        Text(Almanac.of(date).dayGZ + (I18n.en ? "" : "日")).font(Typo.ui(11, .semibold))
                    }
                    .foregroundColor(ink.opacity(0.55))
                }
            }
            .padding(compact ? 8 : 18)
            RoundedRectangle(cornerRadius: compact ? 12 : 18, style: .continuous)
                .strokeBorder(ink.opacity(0.10), lineWidth: 1)
                .padding(compact ? 4 : 9)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
    }
}

// MARK: - 邮票（签册用：齿孔边）

struct Perforated: Shape {
    var hole: CGFloat = 4.2
    var gap: CGFloat = 12
    func path(in r: CGRect) -> Path {
        var p = Path(r)
        func holes(from a: CGPoint, to b: CGPoint) {
            let len = hypot(b.x - a.x, b.y - a.y)
            let n = max(1, Int(len / gap))
            for i in 0...n {
                let t = CGFloat(i) / CGFloat(n)
                let c = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                p.addEllipse(in: CGRect(x: c.x - hole, y: c.y - hole, width: hole * 2, height: hole * 2))
            }
        }
        holes(from: CGPoint(x: r.minX, y: r.minY), to: CGPoint(x: r.maxX, y: r.minY))
        holes(from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.maxY))
        holes(from: CGPoint(x: r.minX, y: r.minY), to: CGPoint(x: r.minX, y: r.maxY))
        holes(from: CGPoint(x: r.maxX, y: r.minY), to: CGPoint(x: r.maxX, y: r.maxY))
        return p
    }
}

struct LotStamp: View {
    @Environment(\.pal) private var p
    let lot: Lot
    let day: String
    var body: some View {
        let date = Days.date(fromKey: day) ?? Days.now
        let ink = paperInk
        ZStack {
            Rectangle().fill(Color(hex: 0xFBFAF7))
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(LinearGradient(colors: [Tone.color(lot.tone), Tone.deep(lot.tone)], startPoint: .top, endPoint: .bottom))
                    Circle().strokeBorder(ink.opacity(0.18), lineWidth: 1).frame(width: 84, height: 84)
                    Circle().strokeBorder(ink.opacity(0.12), lineWidth: 1).frame(width: 120, height: 120)
                    VStack(spacing: 2) {
                        Text(lot.name).font(Typo.song(34, bold: true)).foregroundColor(ink)
                        Text(lot.levelText).font(Typo.ui(10, .bold)).foregroundColor(ink.opacity(0.65))
                    }
                    VStack {
                        HStack {
                            Text(lot.noText).font(Typo.song(10, bold: true))
                            Spacer()
                            Text(String(format: "%02d", Days.cal.component(.day, from: date))).font(Typo.num(18, .heavy))
                        }
                        Spacer()
                        Text(lot.poem.split(separator: "，").first.map(String.init) ?? "")
                            .font(Typo.song(9.5)).lineLimit(1)
                    }
                    .foregroundColor(ink.opacity(0.75))
                    .padding(9)
                }
                HStack {
                    Text(L("今日签") + " · " + Days.md(date)).font(Typo.ui(9, .semibold))
                    Spacer()
                    Text(Almanac.of(date).dayGZ).font(Typo.ui(9, .semibold))
                }
                .foregroundColor(ink.opacity(0.5))
            }
            .padding(10)
        }
        .frame(width: 150, height: 196)
        .mask(Perforated().fill(style: FillStyle(eoFill: true)))
        .shadow(color: Color.black.opacity(p.dark ? 0.5 : 0.14), radius: 14, x: 0, y: 10)
    }
}
