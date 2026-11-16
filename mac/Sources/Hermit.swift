import SwiftUI

// MARK: - v10「山人」：一位隐居山中的先生替你看日子
// 设计底层逻辑：今日签不是工具箱，而是一位话不多的山中高人。
// 他每天早上递你一支签（抽签）；把一天摊成一只时辰轮给你看（首页）；
// 你有事就上山叩门问他（问山人）；你做完一件事，他在上面盖一个「毕」字（待办印章）。
// 山人只看时辰与八字，不替人拿主意：钱、病、官司一律只说「慎」。

// MARK: 首页

struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                HermitHeader()
                ZStack {
                    TodayDial(size: 286)
                        .demoTarget("home.dial")
                        .id(ui.dialDay)
                        .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity))
                    HStack {
                        dayArrow("chevron.left", -1)
                        Spacer()
                        dayArrow("chevron.right", 1)
                    }
                    .padding(.horizontal, -2)
                    VStack {
                        DayBadge()
                        Spacer()
                    }
                    // 择日：放在表盘左上角，一眼能看到
                    VStack {
                        HStack {
                            Button(action: { ui.go(.pickDay) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar.badge.checkmark").font(.system(size: 11, weight: .semibold))
                                    Text(L("择日")).font(Typo.ui(11.5, .bold))
                                }
                                .foregroundColor(p.ink)
                                .padding(.horizontal, 10).frame(height: 28)
                                .background(Capsule().fill(p.glassFill2))
                                .overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
                                .contentShape(Capsule())
                            }
                            .buttonStyle(PressStyle())
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(.leading, 14).padding(.top, 18)
                }
                .frame(height: 290)
                Scroller {
                    VStack(spacing: 10) {
                        ProbeCard()
                        FortuneCard()
                        Text(L("签文原创 · 黄历按传统算法本地推算 · 仅供娱乐参考"))
                            .font(Typo.ui(10)).foregroundColor(p.ink3)
                    }
                    .padding(.horizontal, 16).padding(.top, 2).padding(.bottom, 10)
                }
                .edgeFade(top: 6, bottom: 12)
                ReminderDock()
            }
        }
    }

    private func dayArrow(_ sym: String, _ d: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                ui.dialDay = max(-30, min(30, ui.dialDay + d)); ui.probeMinutes = nil
            }
        }) {
            Image(systemName: sym).font(.system(size: 11, weight: .bold)).foregroundColor(p.ink2)
                .frame(width: 24, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .demoTarget(d > 0 ? "home.arrowR" : "home.arrowL")
    }
}

struct HermitHeader: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @EnvironmentObject var weather: WeatherService
    @Environment(\.pal) private var p
    var body: some View {
        let now = Days.now
        let a = Almanac.of(now)
        HStack(alignment: .center, spacing: 10) {
            InkSeal(text: "山", size: 30, color: p.ink, filled: true)
            Button(action: {
                ui.selectedDay = Days.todayKey; ui.calMonth = now; ui.go(.calendar)
            }) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(Days.md(now) + " " + Days.weekday(now)).font(Typo.ui(16, .heavy)).foregroundColor(p.ink).lineLimit(1)
                        Image(systemName: "chevron.down.circle.fill").font(.system(size: 11, weight: .semibold)).foregroundColor(p.ink3)
                    }
                    Text((I18n.en ? a.lunarFull : a.lunarText + " · " + a.yearGZ + "年") + " · " + L("黄历"))
                        .font(Typo.ui(10.5, .medium)).foregroundColor(p.ink2).lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .demoTarget("home.date")
            .layoutPriority(1)
            Spacer(minLength: 0)
            // 今日宜忌一眼看
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Text(L("宜")).font(Typo.song(10.5, bold: true)).foregroundColor(p.onAccent)
                        .frame(width: 16, height: 16).background(Circle().fill(p.accent))
                    Text(a.yi.prefix(2).map { L($0) }.joined(separator: " ")).font(Typo.ui(10.5, .semibold)).foregroundColor(p.ink).lineLimit(1)
                }
                HStack(spacing: 3) {
                    Text(L("忌")).font(Typo.song(10.5, bold: true)).foregroundColor(p.ink)
                        .frame(width: 16, height: 16).overlay(Circle().strokeBorder(p.ink2, lineWidth: 1))
                    Text(a.ji.prefix(2).map { L($0) }.joined(separator: " ")).font(Typo.ui(10.5, .semibold)).foregroundColor(p.ink2).lineLimit(1)
                }
            }
        }
        .padding(.leading, 16).padding(.trailing, 6)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }

    private func nav(_ sym: String, _ page: Page) -> some View {
        Button(action: { if page == .ask { ui.askDraft = "" }; ui.go(page) }) {
            Image(systemName: sym).font(.system(size: 13, weight: .semibold)).foregroundColor(p.ink)
                .frame(width: 31, height: 30).contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

/// 表盘上方：今天给一句玩法提示；翻到别的日子则显示是哪天
struct DayBadge: View {
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    var body: some View {
        let d = Days.addDays(ui.dialDay, to: Days.startOfDay(Days.now))
        Group {
            if ui.dialDay == 0 {
                // 一眼看出现在是哪个时辰
                let nb = DialMath.branch(DialMath.minuteOfDay(Days.now))
                let st = (nb * 2 + 23) % 24
                HStack(spacing: 5) {
                    Circle().fill(p.mono).frame(width: 5, height: 5)
                    Text(LF("现在 · %@（%02d–%02d 点）", L(Almanac.branches[nb] + "时"), st, (st + 2) % 24))
                        .font(Typo.ui(10.5, .bold)).foregroundColor(p.mono)
                }
            } else {
                let rel = Days.relative(d)
                Text(Days.md(d) + " " + Days.weekday(d) + (rel.contains(Days.md(d)) ? "" : " · " + rel))
                    .font(Typo.ui(10.5, .bold)).foregroundColor(p.onMono)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Capsule().fill(p.mono))
            }
        }
        .padding(.top, 0)
    }
}

/// 山人今日说一句：点开看细说
struct HermitSays: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    var body: some View {
        let day = Days.addDays(ui.dialDay, to: Days.startOfDay(Days.now))
        let s = store.data.settings
        let r = Fortune.reading(for: day, birth: s.birthOn ? s.birthDate : nil, birthHour: s.birthHour)
        Button(action: { ui.go(.fortune) }) {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 0) {
                    ForEach(Array((I18n.en ? "" : "山人说").enumerated()), id: \.offset) { _, ch in
                        Text(String(ch)).font(Typo.song(10.5, bold: true)).foregroundColor(p.ink3)
                    }
                    if I18n.en { Text("Hermit").font(Typo.ui(9, .bold)).foregroundColor(p.ink3).rotationEffect(.degrees(-90)).frame(width: 14, height: 40) }
                }
                .frame(width: 14)
                Rectangle().fill(p.ink3.opacity(0.5)).frame(width: 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.headline)
                        .font(I18n.en ? Typo.ui(13, .bold) : Typo.song(14.5, bold: true))
                        .foregroundColor(p.ink).lineSpacing(2).lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        Text(L(r.personal ? "按你的八字" : "未填生辰 · 按当日黄历"))
                        Text("·")
                        Text(L("细说"))
                        Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                    }
                    .font(Typo.ui(10.5, .semibold)).foregroundColor(p.ink3)
                }
                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14).padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(20, depth: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: 山人细说（原首页的断语与签卡）

struct FortunePage: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    var body: some View {
        let s = store.data.settings
        VStack(spacing: 0) {
            PageHeader(title: L("山人细说"), subtitle: L(s.birthOn ? "按你的八字推算 · 仅供娱乐参考" : "未填生辰 · 按当日黄历推算"), back: { ui.go(.home) })
            Scroller {
                VStack(spacing: 14) {
                    FortuneCard()
                    TodayLotCard().id("fortune.bottom")
                    Text(L("签文原创 · 黄历按传统算法本地推算 · 仅供娱乐参考"))
                        .font(Typo.ui(10.5)).foregroundColor(p.ink3)
                }
                .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 16)
            }
            .edgeFade()
        }
    }
}

// MARK: 印章（不用红色：墨色 / 白色）

struct InkSeal: View {
    let text: String
    var size: CGFloat = 24
    var color: Color
    var filled = false
    var angle: Double = -8
    @Environment(\.pal) private var p
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(filled ? color : Color.clear)
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .strokeBorder(color, lineWidth: max(1.2, size * 0.065))
                .padding(filled ? size * 0.08 : 0)
                .opacity(filled ? 0 : 1)
            if filled {
                RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                    .strokeBorder(p.onAccent.opacity(0.55), lineWidth: 0.8)
                    .padding(size * 0.1)
            }
            if !I18n.en && text.count == 2 {
                // 两个字的印：竖排，像真的方印
                VStack(spacing: -size * 0.04) {
                    ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                        Text(String(ch)).font(Typo.song(size * 0.36, bold: true))
                    }
                }
                .foregroundColor(filled ? p.onAccent : color)
            } else {
                Text(text)
                    .font(I18n.en && text.count > 1 ? Typo.ui(size * 0.3, .heavy) : Typo.song(size * 0.56, bold: true))
                    .foregroundColor(filled ? p.onAccent : color)
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .padding(size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(angle))
    }
}

// MARK: 远山（背景最底层的水墨山影）

struct InkMountains: View {
    @Environment(\.pal) private var p
    var body: some View {
        GeometryReader { g in
            let col = p.dark ? Color.white : Color(hex: 0x23262B)
            ZStack {
                Ridge(base: 0.70, amp: 0.10, seed: 1.3).fill(LinearGradient(colors: [col.opacity(p.dark ? 0.035 : 0.045), col.opacity(0)], startPoint: .top, endPoint: .bottom))
                Ridge(base: 0.78, amp: 0.07, seed: 4.1).fill(LinearGradient(colors: [col.opacity(p.dark ? 0.05 : 0.06), col.opacity(0.0)], startPoint: .top, endPoint: .bottom))
            }
        }
        .allowsHitTesting(false)
    }
}

struct Ridge: Shape {
    var base: CGFloat
    var amp: CGFloat
    var seed: Double
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: 0, y: h))
        for i in 0...60 {
            let x = CGFloat(i) / 60
            let t = Double(x) * .pi
            let y = base - amp * CGFloat(0.55 * sin(t * 2.1 + seed) + 0.3 * sin(t * 5.3 + seed * 2) + 0.15 * sin(t * 11 + seed * 3))
            p.addLine(to: CGPoint(x: x * w, y: y * h))
        }
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}

// MARK: 问山人：三枚铜钱掷起来

struct CoinToss: View {
    @Environment(\.pal) private var p
    @State private var spin = false
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                ForEach(0..<3, id: \.self) { i in
                    coin
                        .rotation3DEffect(.degrees(spin ? 360 * Double(2 + i) : 0), axis: (x: CGFloat(1), y: CGFloat(0.2 * Double(i - 1)), z: CGFloat(0)))
                        .offset(y: spin ? -18 + CGFloat(i * 6) : 0)
                        .animation(.easeInOut(duration: 0.55 + Double(i) * 0.12).repeatForever(autoreverses: true), value: spin)
                }
            }
            .frame(height: 80)
            Text(L("山人掷钱起卦…")).font(Typo.song(14, bold: true)).foregroundColor(p.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .glass(24, depth: 2, fill: p.heroTop)
        .onAppear { if !Snap.active { spin = true } }
    }

    private var coin: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: p.dark ? [Color(hex: 0x6B6B70), Color(hex: 0x3A3A3E)] : [Color(hex: 0xD9D9DE), Color(hex: 0xA9A9B0)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(p.ink.opacity(0.35), lineWidth: 2).padding(3)
            RoundedRectangle(cornerRadius: 2).fill(p.dark ? Color(hex: 0x1C1C1F) : Color.white).frame(width: 11, height: 11)
            RoundedRectangle(cornerRadius: 2).strokeBorder(p.ink.opacity(0.4), lineWidth: 1).frame(width: 11, height: 11)
            ForEach(0..<4, id: \.self) { k in
                Text(["乾", "坤", "通", "宝"][k]).font(Typo.song(9, bold: true)).foregroundColor(p.ink.opacity(0.55))
                    .offset(x: ([0, 0, 13, -13] as [CGFloat])[k], y: ([-13, 13, 0, 0] as [CGFloat])[k])
            }
        }
        .frame(width: 46, height: 46)
        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 3)
    }
}
