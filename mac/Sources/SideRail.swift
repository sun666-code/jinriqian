import SwiftUI
import AppKit

// MARK: - 侧栏（参考 iPhone 侧边栏的思路）：常用入口都在右边一竖条里，任何页面都在
// 上：天气（会动）、日期（点开万年历·老黄历）、提醒（带未完成数）、新建待办、设置
// 中：签条——今天的签在正中，上下拨会翻过一张张签牌（有 3D 翻动和轻震），松手总会弹回今天这一支；点它看签
// 下：山人——一颗墨珠，随时点开问

let railWidth: CGFloat = 62

extension UIState {
    /// 有浮层盖着时，底下的触控板手势要停掉（否则会一直转表盘、拖慢界面）
    var overlayOpen: Bool { lotOpen || dockOpen || composerOpen || shareOpen || chatOpen || weatherOpen }
}

struct SideRail: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @EnvironmentObject var weather: WeatherService
    @Environment(\.pal) private var p

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 4) {
                if store.data.settings.weatherOn {
                    WeatherMini()
                        .demoTarget("rail.weather")
                        .onTapGesture { spring { ui.weatherOpen.toggle(); ui.chatOpen = false } }
                    divider
                }
                DateMini()
                    .demoTarget("rail.date")
                    .onTapGesture {
                        ui.weatherOpen = false
                        if ui.page == .calendar { ui.go(.home) } else { ui.selectedDay = Days.todayKey; ui.calMonth = Days.now; ui.go(.calendar) }
                    }
                    .background(Circle().fill(ui.page == .calendar ? p.glassFill2 : Color.clear).frame(width: 44, height: 44))
                RailButton(symbol: "checklist", badge: store.pendingToday, active: ui.dockOpen) {
                    spring { ui.dockOpen.toggle(); ui.chatOpen = false; ui.lotOpen = false; ui.weatherOpen = false }
                }
                RailButton(symbol: "plus", active: ui.composerOpen) {
                    ui.scheduleDraft = ""
                    spring { ui.composerOpen.toggle(); ui.dockOpen = false; ui.chatOpen = false; ui.weatherOpen = false }
                }
                .demoTarget("rail.plus")
                RailButton(symbol: "gearshape", active: ui.page == .settings) {
                    ui.weatherOpen = false
                    if ui.page == .settings { ui.go(.home) } else { ui.go(.settings) }
                }
                .demoTarget("rail.gear")
            }
            .padding(.vertical, 8)
            .frame(width: railWidth - 10)
            .background(railCapsule)

            LotStrip()
                .demoTarget("rail.strip")
                .frame(width: railWidth - 10)
                .frame(maxHeight: .infinity)
                .background(railCapsule)

            Button(action: { spring { ui.chatOpen.toggle(); ui.dockOpen = false; ui.lotOpen = false; ui.weatherOpen = false } }) {
                VStack(spacing: 3) {
                    HermitOrb(size: 42, active: ui.chatOpen)
                    Text(L("问山人")).font(Typo.song(9.5, bold: true)).foregroundColor(p.ink2)
                }
                .padding(.vertical, 8)
                .frame(width: railWidth - 10)
                .background(railCapsule)
            }
            .buttonStyle(PressStyle())
            .demoTarget("rail.orb")
        }
        .padding(.vertical, 12)
        .padding(.trailing, 8)
        .frame(width: railWidth + 8)
    }

    private var divider: some View { Rectangle().fill(p.hairline).frame(width: 26, height: 1).padding(.vertical, 2) }

    private var railCapsule: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(p.dark ? Color.white.opacity(0.07) : Color.white.opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(p.hairline, lineWidth: 1))
            .shadow(color: Color.black.opacity(p.dark ? 0.3 : 0.06), radius: 8, x: 0, y: 4)
    }

    private func spring(_ f: () -> Void) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { f() }
        if !Snap.active { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now) }
    }
}

struct RailButton: View {
    let symbol: String
    var badge = 0
    var active = false
    let action: () -> Void
    @Environment(\.pal) private var p
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(active ? p.onAccent : p.ink)
                .rotationEffect(.degrees(active && symbol == "gearshape" ? 90 : 0))
                .rotationEffect(.degrees(active && symbol == "plus" ? 45 : 0))
                .frame(width: 40, height: 40)
                .background(Circle().fill(active ? p.accent : Color.clear))
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(badge)").font(Typo.num(9, .heavy)).foregroundColor(p.onTint)
                            .frame(minWidth: 15, minHeight: 15).background(Circle().fill(p.tint))
                            .offset(x: 2, y: -1)
                            .transition(.scale)
                    }
                }
                .contentShape(Circle())
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: active)
        }
        .buttonStyle(PressStyle())
    }
}

/// 天气：太阳慢慢转、云轻轻飘、雨点往下落
struct WeatherMini: View {
    @EnvironmentObject var weather: WeatherService
    @Environment(\.pal) private var p
    @State private var t = false
    var body: some View {
        let sym = weather.now?.symbol ?? "cloud"
        VStack(spacing: 1) {
            ZStack {
                Image(systemName: sym).symbolRenderingMode(.multicolor)
                    .font(.system(size: 17, weight: .semibold))
                    .rotationEffect(.degrees(sym.contains("sun") && !sym.contains("cloud") && t ? 25 : 0))
                    .offset(x: sym.contains("cloud") && t ? 2 : (sym.contains("cloud") ? -2 : 0),
                            y: (sym.contains("rain") || sym.contains("drizzle") || sym.contains("snow")) && t ? 1.5 : 0)
                    .scaleEffect(sym.contains("moon") && t ? 1.06 : 1)
            }
            .frame(width: 30, height: 24)
            Text(weather.now.map { "\(Int($0.temp.rounded()))°" } ?? "--").font(Typo.num(11.5, .bold)).foregroundColor(p.ink)
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .onAppear {
            guard !Snap.active else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { t = true }
        }
    }
}

struct DateMini: View {
    @Environment(\.pal) private var p
    var body: some View {
        let d = Days.now
        let a = Almanac.of(d)
        VStack(spacing: -1) {
            Text("\(Days.cal.component(.day, from: d))").font(Typo.num(17, .heavy)).foregroundColor(p.ink)
            Text(I18n.en ? Days.weekday(d) : a.lunarDayText).font(Typo.ui(8.5, .semibold)).foregroundColor(p.ink2)
        }
        .frame(width: 44, height: 40)
        .contentShape(Rectangle())
    }
}

// MARK: 签条：一只摸不到底的签筒
// 上下拨动（拖、两指滑都行）会一直翻下去，带惯性；停下时正中那一张会翻过来——永远是今天抽到的那支签。

struct LotStrip: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    @State private var offset: CGFloat = 0
    @State private var start: CGFloat? = nil
    @State private var moving = false
    @State private var lastIdx = 0
    @State private var settle: DispatchWorkItem? = nil

    private let step: CGFloat = 58
    private let cardW: CGFloat = 38
    private let cardH: CGFloat = 54

    var body: some View {
        let off = Snap.active ? -ui.railLotDrag : offset
        let isMoving = Snap.active ? ui.railLotDrag != 0 : moving
        let rest = Int((off / step).rounded())
        GeometryReader { g in
            let midY = g.size.height / 2
            let base = Int((off / step).rounded(.down))
            ZStack {
                ForEach((base - 4)...(base + 5), id: \.self) { k in
                    let y = CGFloat(k) * step - off
                    let a = abs(y) / step
                    Group {
                        if k == rest && !isMoving { face.transition(.scale(scale: 0.8).combined(with: .opacity)) }
                        else { TarotBack(focused: false) }
                    }
                    .frame(width: cardW, height: cardH)
                    .rotation3DEffect(.degrees(Double(-y / step) * 28), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                    .scaleEffect(max(0.55, 1 - a * 0.14))
                    .opacity(max(0, 1 - Double(a) * 0.28))
                    .position(x: g.size.width / 2, y: midY + y * (1 - min(a, 3) * 0.08))
                    .zIndex(-Double(a))
                }
                HStack {
                    Capsule().fill(Mystic.brass).frame(width: 3, height: 14)
                    Spacer()
                    Capsule().fill(Mystic.brass).frame(width: 3, height: 14)
                }
                .padding(.horizontal, 2)
                .position(x: g.size.width / 2, y: midY)
                .opacity(isMoving ? 0.3 : 1)
            }
            .frame(width: g.size.width, height: g.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { v in
                        if start == nil { start = offset; settle?.cancel() }
                        if !moving { withAnimation(.easeOut(duration: 0.15)) { moving = true } }
                        offset = (start ?? 0) - v.translation.height
                        tick()
                    }
                    .onEnded { v in
                        let predicted = (start ?? offset) - v.predictedEndTranslation.height
                        start = nil
                        land(at: predicted)
                    }
            )
            .simultaneousGesture(TapGesture().onEnded { if !moving { toggleOpen() } })
            .onDemo { c in
                if case .act("strip.fling") = c {
                    withAnimation(.easeOut(duration: 0.15)) { moving = true }
                    land(at: offset + step * 9)
                }
            }
            .background(Group { if !Snap.active && !ui.overlayOpen {
                ScrollCatcher(onScroll: { dy in
                    if !moving { withAnimation(.easeOut(duration: 0.15)) { moving = true } }
                    offset -= dy * 1.6
                    tick()
                    settle?.cancel()
                    let w = DispatchWorkItem { land(at: offset) }
                    settle = w
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: w)
                })
            } })
        }
    }

    @ViewBuilder
    private var face: some View {
        if let lot = store.todayLot {
            ZStack {
                FolkArt(no: lot.no, compact: true)
                VStack {
                    Spacer()
                    Text(String(lot.name.prefix(1))).font(Typo.song(13, bold: true)).foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                        .padding(.bottom, 3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Mystic.brass, lineWidth: 1.2))
            .shadow(color: Mystic.brass.opacity(0.55), radius: 6)
        } else {
            TarotBack(focused: true)
        }
    }

    private func tick() {
        let i = Int((offset / step).rounded())
        if i != lastIdx {
            lastIdx = i
            if !Snap.active { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
        }
    }

    /// 停在离预测终点最近的一张，然后把它翻开
    private func land(at target: CGFloat) {
        let snapped = (target / step).rounded() * step
        let dist = abs(snapped - offset) / step
        withAnimation(.spring(response: min(1.1, 0.4 + Double(dist) * 0.05), dampingFraction: 0.86)) { offset = snapped }
        lastIdx = Int((snapped / step).rounded())
        DispatchQueue.main.asyncAfter(deadline: .now() + min(0.9, 0.3 + Double(dist) * 0.04)) {
            guard start == nil else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { moving = false }
            if !Snap.active { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
        }
    }

    private func toggleOpen() {
        guard store.todayLot != nil else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            ui.lotOpen.toggle(); ui.chatOpen = false; ui.dockOpen = false; ui.weatherOpen = false
        }
    }
}
