import SwiftUI
import AppKit

// MARK: - 求签仪式（v10）：夜色星图 + 缓缓转动的八卦星盘 + 一扇形展开的签牌（牌背像塔罗，但纹样是八卦与月相）
// 颜色只用墨、夜蓝、黄铜与旧纸色，不用红色。浅色模式是旧书纸底，深色模式是夜空底。

enum Mystic {
    static let brass = Color(hex: 0xC9B37E)
    static let brassDeep = Color(hex: 0x7A6535)
    static let cardTop = Color(hex: 0x1C1F2E)
    static let cardBottom = Color(hex: 0x0D0F17)
    static let paper = [Color(hex: 0xF4EDDB), Color(hex: 0xE3D7B9)]
    static let paperInk = Color(hex: 0x2A2418)
    /// 卦象：从上到下三爻，1 = 阳（实线），0 = 阴（断线）
    static let trigrams: [[Int]] = [[1, 1, 1], [0, 1, 1], [1, 0, 1], [0, 0, 1], [1, 1, 0], [0, 1, 0], [1, 0, 0], [0, 0, 0]]

    struct Theme {
        let dark: Bool
        var bg: [Color] { dark ? [Color(hex: 0x161825), Color(hex: 0x07080C)] : [Color(hex: 0xEEE7D6), Color(hex: 0xD9CFB6)] }
        var ink: Color { dark ? Color(hex: 0xEDE6D3) : Mystic.paperInk }
        var ink2: Color { ink.opacity(0.62) }
        var line: Color { dark ? Mystic.brass : Mystic.brassDeep }
    }
}

struct TrigramGlyph: View {
    let lines: [Int]
    var width: CGFloat = 16
    var color: Color
    var body: some View {
        VStack(spacing: width * 0.14) {
            ForEach(0..<3, id: \.self) { i in
                if lines[i] == 1 {
                    Rectangle().fill(color).frame(width: width, height: width * 0.14)
                } else {
                    HStack(spacing: width * 0.2) {
                        Rectangle().fill(color).frame(width: width * 0.4, height: width * 0.14)
                        Rectangle().fill(color).frame(width: width * 0.4, height: width * 0.14)
                    }
                }
            }
        }
    }
}

/// 背景：星点 + 八卦星盘（慢慢转）
struct MysticBackdrop: View {
    let t: Mystic.Theme
    var spin = true
    var showDial = true
    @State private var angle: Double = 0
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                LinearGradient(colors: t.bg, startPoint: .top, endPoint: .bottom)
                Canvas { ctx, size in
                    var seed: UInt64 = 0xA57E
                    func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(Double(seed >> 33) / Double(1 << 31)) }
                    for _ in 0..<110 {
                        let x = rnd() * size.width, y = rnd() * size.height, r = 0.4 + rnd() * 1.2
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(t.line.opacity(0.18 + Double(rnd()) * 0.45)))
                    }
                }
                if showDial {
                    Astrolabe(t: t).frame(width: 330, height: 330)
                        .rotationEffect(.degrees(angle))
                        .position(x: w / 2, y: h * 0.47)
                }
                RadialGradient(colors: [t.line.opacity(t.dark ? 0.16 : 0.12), .clear], center: .center, startRadius: 0, endRadius: 200)
                    .position(x: w / 2, y: h * 0.47)
            }
        }
        .onAppear {
            guard spin && !Snap.active else { return }
            withAnimation(.linear(duration: 240).repeatForever(autoreverses: false)) { angle = 360 }
        }
        .allowsHitTesting(false)
    }
}

struct Astrolabe: View {
    let t: Mystic.Theme
    var body: some View {
        GeometryReader { g in
            let r = min(g.size.width, g.size.height) / 2
            let c = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            ZStack {
                Circle().strokeBorder(t.line.opacity(0.28), lineWidth: 0.8)
                Circle().strokeBorder(t.line.opacity(0.20), lineWidth: 0.6).padding(r * 0.12)
                Circle().strokeBorder(t.line.opacity(0.14), lineWidth: 0.6).padding(r * 0.34)
                // 二十八宿刻度
                ForEach(0..<28, id: \.self) { k in
                    let a = Double(k) / 28 * 2 * .pi
                    Path { p in
                        p.move(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
                        p.addLine(to: CGPoint(x: c.x + cos(a) * r * 0.94, y: c.y + sin(a) * r * 0.94))
                    }
                    .stroke(t.line.opacity(0.3), lineWidth: 0.7)
                }
                // 八卦
                ForEach(0..<8, id: \.self) { k in
                    let a = Double(k) / 8 * 360
                    TrigramGlyph(lines: Mystic.trigrams[k], width: 15, color: t.line.opacity(0.42))
                        .rotationEffect(.degrees(a))
                        .position(x: c.x + CGFloat(sin(a * .pi / 180)) * r * 0.77, y: c.y - CGFloat(cos(a * .pi / 180)) * r * 0.77)
                }
            }
        }
    }
}

/// 牌背：夜蓝底 + 黄铜双框 + 八卦环 + 新月与星
struct TarotBack: View {
    var focused: Bool
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let shape = RoundedRectangle(cornerRadius: w * 0.08, style: .continuous)
            ZStack {
                shape.fill(LinearGradient(colors: [Mystic.cardTop, Mystic.cardBottom], startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: w * 0.05, style: .continuous).strokeBorder(Mystic.brass.opacity(0.85), lineWidth: 1).padding(w * 0.05)
                RoundedRectangle(cornerRadius: w * 0.04, style: .continuous).strokeBorder(Mystic.brass.opacity(0.4), lineWidth: 0.6).padding(w * 0.08)
                ZStack {
                    Circle().strokeBorder(Mystic.brass.opacity(0.8), lineWidth: 0.9).frame(width: w * 0.62, height: w * 0.62)
                    Circle().strokeBorder(Mystic.brass.opacity(0.4), lineWidth: 0.6).frame(width: w * 0.46, height: w * 0.46)
                    ForEach(0..<8, id: \.self) { k in
                        let a = Double(k) / 8 * 360
                        TrigramGlyph(lines: Mystic.trigrams[k], width: w * 0.075, color: Mystic.brass.opacity(0.75))
                            .rotationEffect(.degrees(a))
                            .offset(x: CGFloat(sin(a * .pi / 180)) * w * 0.27, y: -CGFloat(cos(a * .pi / 180)) * w * 0.27)
                    }
                    // 新月
                    ZStack {
                        Circle().fill(Mystic.brass).frame(width: w * 0.16, height: w * 0.16)
                        Circle().fill(Mystic.cardTop).frame(width: w * 0.14, height: w * 0.14).offset(x: w * 0.045, y: -w * 0.02)
                    }
                }
                .position(x: w / 2, y: h / 2)
                Text("✦").font(.system(size: w * 0.08)).foregroundColor(Mystic.brass.opacity(0.8)).position(x: w / 2, y: h * 0.14)
                Text("✦").font(.system(size: w * 0.08)).foregroundColor(Mystic.brass.opacity(0.8)).position(x: w / 2, y: h * 0.86)
                shape.fill(LinearGradient(colors: [Color.white.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .center))
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Mystic.brass.opacity(focused ? 0.9 : 0.3), lineWidth: focused ? 1.2 : 0.6))
            .shadow(color: Mystic.brass.opacity(focused ? 0.45 : 0), radius: focused ? 14 : 0)
        }
    }
}

/// 签面（塔罗式）：黑底金框 + 签图 + 金色签名与方印
struct MysticFace: View {
    let lot: Lot
    var date: Date
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let gold = Mystic.brass
            let shape = RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
            ZStack {
                shape.fill(LinearGradient(colors: [Color(hex: 0x1B1C24), Color(hex: 0x0B0C10)], startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: w * 0.045, style: .continuous).strokeBorder(gold.opacity(0.85), lineWidth: 1).padding(w * 0.03)
                RoundedRectangle(cornerRadius: w * 0.035, style: .continuous).strokeBorder(gold.opacity(0.35), lineWidth: 0.6).padding(w * 0.048)
                ForEach(0..<4, id: \.self) { k in
                    Text("✦").font(.system(size: w * 0.045)).foregroundColor(gold.opacity(0.8))
                        .position(x: k % 2 == 0 ? w * 0.075 : w * 0.925, y: k < 2 ? h * 0.05 : h * 0.95)
                }
                VStack(spacing: 0) {
                    Text(lot.noText).font(Typo.song(w * 0.05, bold: true)).foregroundColor(gold.opacity(0.85)).tracking(w * 0.01)
                        .padding(.bottom, w * 0.025)
                    FolkArt(no: lot.no)
                        .frame(height: h * 0.66)
                        .clipShape(ArchWindow())
                        .overlay(ArchWindow().stroke(gold.opacity(0.85), lineWidth: 1))
                        .overlay(ArchWindow().stroke(gold.opacity(0.3), lineWidth: 0.6).padding(w * 0.02))
                    Spacer(minLength: 0)
                    Text(lot.displayName)
                        .font(Typo.song(I18n.en ? w * 0.075 : (lot.name.count > 2 ? w * 0.1 : w * 0.13), bold: true))
                        .tracking(I18n.en ? 0 : w * 0.03)
                        .foregroundColor(Color(hex: 0xEFE3C2)).lineLimit(1).minimumScaleFactor(0.5)
                    Spacer(minLength: 0)
                    HStack {
                        Text(Days.md(date)).font(Typo.ui(w * 0.04, .semibold))
                        Spacer()
                        SealMark(text: lot.levelShort, size: w * 0.1, color: gold)
                        Spacer()
                        Text(Almanac.of(date).dayGZ + (I18n.en ? "" : "日")).font(Typo.ui(w * 0.04, .semibold))
                    }
                    .foregroundColor(gold.opacity(0.6))
                }
                .padding(.horizontal, w * 0.09).padding(.top, w * 0.07).padding(.bottom, w * 0.065)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(gold.opacity(0.55), lineWidth: 1))
        }
    }
}

/// 不随外观变色的方印（签面在旧纸上，永远是墨色）
struct SealMark: View {
    let text: String
    var size: CGFloat
    var color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous).strokeBorder(color, lineWidth: max(1.1, size * 0.06))
            if !I18n.en && text.count == 2 {
                VStack(spacing: -size * 0.04) {
                    ForEach(Array(text.enumerated()), id: \.offset) { _, ch in Text(String(ch)).font(Typo.song(size * 0.36, bold: true)) }
                }
            } else {
                Text(text).font(Typo.ui(size * 0.26, .heavy)).minimumScaleFactor(0.5).lineLimit(1).padding(size * 0.08)
            }
        }
        .foregroundColor(color)
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-6))
    }
}

// MARK: 求签

struct DrawView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    var onFinish: () -> Void

    private let cardW: CGFloat = 112
    private let cardH: CGFloat = 190
    @State private var busy = false
    @State private var initialized = false
    @State private var acc: CGFloat = 0

    var body: some View {
        let t = Mystic.Theme(dark: p.dark)
        let lot = LotLibrary.lot(store.lotNo(at: ui.drawIndex))
        let today = Days.date(fromKey: store.qianDay) ?? Days.now
        let a = Almanac.of(today)
        ZStack {
            MysticBackdrop(t: t)
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(Days.md(today) + " " + Days.weekday(today) + " · " + a.lunarFull)
                        .font(Typo.ui(11.5, .medium)).foregroundColor(t.ink2)
                    Text(L(ui.drawFlipped ? "山人给你的签" : "向山人求一支签"))
                        .font(Typo.song(25, bold: true)).foregroundColor(t.ink)
                    Text(ui.drawFlipped ? lot.levelText + " · " + lot.displayName : L("静心，默念所求之事 · 左右拨牌，点正中那张"))
                        .font(Typo.ui(11.5)).foregroundColor(t.ink2)
                }
                .padding(.top, 26)

                ZStack {
                    if !ui.drawPulled {
                        ForEach(window, id: \.self) { i in card(i) }
                    } else {
                        Group {
                            if ui.drawFlipped {
                                MysticFace(lot: lot, date: today).frame(width: 196, height: 318)
                            } else {
                                TarotBack(focused: true).frame(width: 170, height: 288)
                            }
                        }
                        .rotation3DEffect(.degrees(ui.drawAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                        .shadow(color: Color.black.opacity(t.dark ? 0.6 : 0.25), radius: 30, x: 0, y: 18)
                        .shadow(color: t.line.opacity(ui.drawFlipped ? 0.35 : 0.2), radius: 40)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                    }
                }
                .frame(height: 360)
                .frame(maxWidth: .infinity)
                .demoTarget("draw.fan")
                .contentShape(Rectangle())
                .gesture(drag, including: ui.drawPulled ? .none : .all)
                .background(Group { if !Snap.active && !ui.drawPulled {
                    ScrollCatcher(onScroll: { dy in scrollBy(dy) }, onScrollX: { dx in scrollBy(dx) })
                } })
                .padding(.top, 10)

                Spacer(minLength: 0)

                if ui.drawFlipped && ui.drawAngle == 0 {
                    result(lot, t).transition(.move(edge: .bottom).combined(with: .opacity))
                } else if !ui.drawPulled {
                    controls(t)
                } else {
                    Text(L("牌在翻开…")).font(Typo.song(13)).foregroundColor(t.ink2).padding(.bottom, 40)
                }
            }
            .padding(.bottom, 18)
        }
        .onAppear {
            if !initialized && !Snap.active { ui.drawIndex = store.startIndex; initialized = true }
        }
    }

    private var window: [Int] { Array((ui.drawIndex - 6)...(ui.drawIndex + 6)) }

    /// 扇形展开：每张牌绕着下方很远的一点旋转
    @ViewBuilder
    private func card(_ i: Int) -> some View {
        let rel = Double(i - ui.drawIndex) + Double(ui.drawDrag)
        let a = abs(rel)
        TarotBack(focused: a < 0.5)
            .frame(width: cardW, height: cardH)
            .offset(y: a < 0.5 ? -16 * (1 - a * 2) : 0)
            .rotationEffect(.degrees(rel * 11), anchor: UnitPoint(x: 0.5, y: 3.0))
            .scaleEffect(1 - min(a, 5) * 0.03)
            .shadow(color: Color.black.opacity(a < 0.5 ? 0.45 : 0.25), radius: a < 0.5 ? 18 : 6, x: 0, y: a < 0.5 ? 12 : 3)
            .opacity(max(0, 1 - max(0, a - 3.5) * 0.45))
            .offset(y: 40)
            .zIndex(-a)
            .onTapGesture { if a < 0.5 { pull() } else { select(i) } }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { v in ui.drawDrag = v.translation.width / 64 }
            .onEnded { v in
                let predicted = v.predictedEndTranslation.width / 64
                let target = Int((Double(ui.drawIndex) - Double(predicted)).rounded())
                withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) { ui.drawIndex = target; ui.drawDrag = 0 }
                tick()
            }
    }

    private func scrollBy(_ d: CGFloat) {
        acc += d
        if abs(acc) > 16 {
            let step = acc > 0 ? -1 : 1
            acc = 0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { ui.drawIndex += step }
            tick()
        }
    }

    private func tick() { if !Snap.active { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) } }

    private func select(_ i: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) { ui.drawIndex = i }
        tick()
    }

    private func pull() {
        guard !ui.drawPulled, !busy else { return }
        busy = true
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { ui.drawPulled = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeIn(duration: 0.25)) { ui.drawAngle = 90 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                ui.drawFlipped = true
                ui.drawAngle = -90
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { ui.drawAngle = 0 }
                busy = false
            }
        }
    }

    private func controls(_ t: Mystic.Theme) -> some View {
        VStack(spacing: 12) {
            Text(LF("第 %d 张", ui.drawIndex))
                .font(Typo.ui(11, .medium)).foregroundColor(t.ink2)
            HStack(spacing: 14) {
                circleButton("chevron.left", t) { select(ui.drawIndex - 1) }
                Button(action: pull) {
                    Text(L("抽出这一张")).font(Typo.song(16, bold: true))
                        .foregroundColor(t.ink)
                        .frame(width: 168, height: 46)
                        .background(Capsule().fill(t.line.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(t.line, lineWidth: 1))
                        .overlay(Capsule().strokeBorder(t.line.opacity(0.4), lineWidth: 0.6).padding(3))
                }.buttonStyle(PressStyle())
                circleButton("chevron.right", t) { select(ui.drawIndex + 1) }
            }
            Text(L("签文为原创 · 仅供娱乐参考")).font(Typo.ui(10)).foregroundColor(t.ink2.opacity(0.8))
        }
    }

    private func circleButton(_ sym: String, _ t: Mystic.Theme, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: sym).font(.system(size: 13, weight: .semibold)).foregroundColor(t.line)
                .frame(width: 40, height: 40)
                .overlay(Circle().strokeBorder(t.line.opacity(0.7), lineWidth: 1))
        }.buttonStyle(PressStyle())
    }

    private func result(_ lot: Lot, _ t: Mystic.Theme) -> some View {
        VStack(spacing: 12) {
            Text(lot.poem).font(Typo.song(15, bold: true)).foregroundColor(t.ink)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
            Text(lot.displayNote)
                .font(Typo.ui(12)).foregroundColor(t.ink2)
                .multilineTextAlignment(.center).lineSpacing(3)
                .padding(.horizontal, 30)
            Button(action: { store.commitDraw(pick: ui.drawIndex); onFinish() }) {
                HStack(spacing: 8) {
                    Text(L("收下这支签")).font(Typo.song(16, bold: true))
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(t.dark ? Mystic.cardBottom : Color(hex: 0xF4EDDB))
                .frame(width: 220, height: 46)
                .background(Capsule().fill(t.line))
            }.buttonStyle(PressStyle()).demoTarget("draw.take")
            .onDemo { c in if case .act("draw.take") = c { store.commitDraw(pick: ui.drawIndex); onFinish() } }
        }
    }
}

// MARK: 新用户第一步：先报生辰，再求签

struct BirthGate: View {
    @EnvironmentObject var store: Store
    @Environment(\.pal) private var p

    var body: some View {
        let t = Mystic.Theme(dark: p.dark)
        ZStack {
            MysticBackdrop(t: t, spin: false, showDial: false)
            VStack(spacing: 14) {
                Spacer(minLength: 0)
                SealMark(text: I18n.en ? "Hi" : "山人", size: 54, color: t.ink)
                Text(L("先报上生辰")).font(Typo.song(26, bold: true)).foregroundColor(t.ink)
                Text(L("山人看命，先看八字。\n你的签、每天的吉凶时辰、问事与命理总批，都由它推算。"))
                    .font(Typo.ui(12.5)).foregroundColor(t.ink2).multilineTextAlignment(.center).lineSpacing(3)
                    .padding(.horizontal, 24)
                BirthEditor(initialDate: nil, initialHour: 12, showCancel: false, saveTitle: "就是这个时辰，开始求签", onSave: { date, hour in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        store.update { $0.birthDate = date; $0.birthHour = hour; $0.birthOn = true }
                    }
                })
                .padding(16)
                .glass(24, depth: 2)
                .padding(.horizontal, 14)
                Text(L("生辰只存在这台 Mac 上，不上传、不发给任何接口。不知道时辰就选午时。"))
                    .font(Typo.ui(10.5)).foregroundColor(t.ink2).multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Spacer(minLength: 0)
            }
        }
    }
}
