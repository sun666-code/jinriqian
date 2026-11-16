import SwiftUI
import AppKit

// MARK: - 时辰轮：今日的主画面
// 外圈 = 一天 24 小时（0 点在正上方），按十二时辰分成 12 格：实心 = 吉时，空心 = 凶时，蓝虚线 = 你的冲时。
// 指针 = 现在；外圈小圆点 = 待办（实心已做、空心未做）；圆心 = 今天的签。
// 两指旋转 / 上下滑 = 拨动时辰（每过一个时辰触控板轻震）；两指左右滑 = 换一天；
// 拖动外圈 = 拨时辰；按住待办圆点沿圈拖动 = 改时间；点圆心 = 看签。

struct ArcBand: Shape {
    var start: Double   // 度，0 = 正上方，顺时针
    var end: Double
    var inner: CGFloat
    var outer: CGFloat
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        var p = Path()
        p.addArc(center: c, radius: outer, startAngle: .degrees(start - 90), endAngle: .degrees(end - 90), clockwise: false)
        p.addArc(center: c, radius: inner, startAngle: .degrees(end - 90), endAngle: .degrees(start - 90), clockwise: true)
        p.closeSubpath()
        return p
    }
}

enum DialMath {
    static func deg(_ minutes: Double) -> Double { minutes / 1440 * 360 }
    static func point(_ minutes: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let a = (deg(minutes) - 90) * .pi / 180
        return CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius)
    }
    static func minutes(at p: CGPoint, center: CGPoint) -> Double {
        var a = atan2(p.y - center.y, p.x - center.x) * 180 / .pi + 90
        if a < 0 { a += 360 }
        return a / 360 * 1440
    }
    static func branch(_ minutes: Int) -> Int { ((minutes / 60 + 1) / 2) % 12 }
    static func minuteOfDay(_ d: Date) -> Int {
        let c = Days.cal.dateComponents([.hour, .minute], from: d)
        return c.hour! * 60 + c.minute!
    }
    static func hm(_ m: Int) -> String { String(format: "%02d:%02d", (m / 60) % 24, m % 60) }
}

struct TodayDial: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p

    let size: CGFloat
    @State private var breathe = false
    @State private var dragTodo: UUID? = nil
    @State private var dragMin: Int = 0
    @State private var dragStarted = false
    @State private var dragFromCenter = false
    @State private var acc: CGFloat = 0
    @State private var accX: CGFloat = 0
    @State private var rot: CGFloat = 0
    @State private var lastBranch = -1
    @State private var hoverCenter = false

    private var outerR: CGFloat { size / 2 - 22 }
    private var innerR: CGFloat { outerR - 34 }
    private var orbitR: CGFloat { outerR + 12 }

    var body: some View {
        let day = Days.addDays(ui.dialDay, to: Days.startOfDay(Days.now))
        let s = store.data.settings
        let r = Fortune.reading(for: day, birth: s.birthOn ? s.birthDate : nil, birthHour: s.birthHour)
        let nowMin = DialMath.minuteOfDay(Days.now)
        let todos = store.reminders(on: Days.key(day)).filter { $0.time != nil }
        let c = CGPoint(x: size / 2, y: size / 2)
        let curB = DialMath.branch(nowMin)
        let probeMin = ui.probeMinutes

        ZStack {
            // 底盘：凸起的圆盘 + 内凹圈
            Circle()
                .fill(LinearGradient(colors: p.dark ? [Color(hex: 0x323236), Color(hex: 0x1C1C1F)] : [Color.white, Color(hex: 0xE9E9ED)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: outerR * 2 + 20, height: outerR * 2 + 20)
                .shadow(color: Color.black.opacity(p.dark ? 0.55 : 0.12), radius: 22, x: 8, y: 14)
                .shadow(color: Color.white.opacity(p.dark ? 0.04 : 0.9), radius: 14, x: -6, y: -6)

            // 十二时辰格
            ForEach(r.slots) { sl in
                let st = Double(sl.start * 60)
                let isNow = ui.dialDay == 0 && sl.branch == curB
                let isProbe = probeMin.map { DialMath.branch($0) == sl.branch } ?? false
                ArcBand(start: DialMath.deg(st) + 0.9, end: DialMath.deg(st + 120) - 0.9, inner: innerR, outer: outerR)
                    .fill(sl.good ? p.ink.opacity(isNow || isProbe ? 1 : 0.86) : p.glassFill2)
                    .overlay(
                        ArcBand(start: DialMath.deg(st) + 0.9, end: DialMath.deg(st + 120) - 0.9, inner: innerR, outer: outerR)
                            .stroke(sl.personalClash ? p.mono : (sl.good ? Color.clear : p.ink3.opacity(0.6)),
                                    style: StrokeStyle(lineWidth: sl.personalClash ? 1.6 : 1, dash: sl.personalClash ? [3, 2] : []))
                    )
                    .scaleEffect(isNow && breathe ? 1.035 : (isProbe ? 1.03 : 1))
                    .shadow(color: (isNow || isProbe) ? p.mono.opacity(p.dark ? 0.6 : 0.35) : .clear, radius: isNow && breathe ? 10 : 4)
                let mid = DialMath.point(st + 60, radius: (innerR + outerR) / 2, center: c)
                Text(Almanac.branches[sl.branch])
                    .font(Typo.song(14, bold: true))
                    .foregroundColor(sl.good ? p.onAccent : p.ink2)
                    .position(mid)
            }

            // 外刻度：每小时一刻，每 3 小时一个数字
            ForEach(0..<24, id: \.self) { h in
                let a = DialMath.point(Double(h * 60), radius: outerR + 4, center: c)
                let b = DialMath.point(Double(h * 60), radius: outerR + (h % 3 == 0 ? 9 : 6), center: c)
                Path { pa in pa.move(to: a); pa.addLine(to: b) }
                    .stroke(p.ink3, lineWidth: h % 3 == 0 ? 1.4 : 0.8)
                if h % 6 == 0 && h != 0 {
                    Text("\(h)").font(Typo.num(9, .bold)).foregroundColor(p.ink3)
                        .position(DialMath.point(Double(h * 60), radius: outerR + 17, center: c))
                }
            }

            // 待办圆点（外轨道）
            ForEach(todos) { t in
                let m = dragTodo == t.id ? dragMin : DialMath.minuteOfDay(t.time!)
                let pt = DialMath.point(Double(m), radius: orbitR, center: c)
                ZStack {
                    Circle().fill(t.done ? p.ink : (p.dark ? Color(hex: 0x1C1C1F) : Color.white))
                    Circle().strokeBorder(t.done ? Color.clear : p.mono, lineWidth: 2)
                    if t.done { Image(systemName: "checkmark").font(.system(size: 6.5, weight: .heavy)).foregroundColor(p.onAccent) }
                }
                .frame(width: dragTodo == t.id ? 18 : 12, height: dragTodo == t.id ? 18 : 12)
                .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                .position(pt)
                if dragTodo == t.id {
                    Text(DialMath.hm(m)).font(Typo.num(11, .bold)).foregroundColor(p.onMono)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(p.mono))
                        .position(DialMath.point(Double(m), radius: orbitR + 22, center: c))
                }
            }

            // 一天的进度：从 0 点（正上方）顺时针走到现在，走满一圈 = 一天
            if ui.dialDay == 0 {
                let pr = innerR - 8
                Circle().stroke(p.ink3.opacity(0.18), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.1, 5]))
                    .frame(width: pr * 2, height: pr * 2)
                Path { pa in pa.addArc(center: c, radius: pr, startAngle: .degrees(-90), endAngle: .degrees(DialMath.deg(Double(nowMin)) - 90), clockwise: false) }
                    .stroke(AngularGradient(colors: [p.mono.opacity(0.25), p.mono], center: .center, startAngle: .degrees(-90), endAngle: .degrees(DialMath.deg(Double(nowMin)) - 90)),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                Circle().fill(p.mono).frame(width: 7, height: 7)
                    .shadow(color: p.mono.opacity(0.6), radius: 4)
                    .position(DialMath.point(Double(nowMin), radius: pr, center: c))
            }

            // 指针：现在
            if ui.dialDay == 0 {
                hand(min: nowMin, color: p.ink, width: 2.2, c: c)
            }
            center(r: r, day: day)

            // 探针：拨到的时辰（画在圆心之上，时间标签不被遮住）
            if let pm = probeMin {
                hand(min: pm, color: p.mono, width: 2, c: c)
                    .mask(Circle().strokeBorder(Color.black, lineWidth: outerR - innerR + 30).frame(width: outerR * 2 + 4, height: outerR * 2 + 4))
                Text(DialMath.hm(pm)).font(Typo.num(11, .bold)).foregroundColor(p.onMono)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(p.mono))
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                    .position(DialMath.point(Double(pm), radius: innerR - 22, center: c))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(dragGesture(c: c, todos: todos))
        .background(Group { if !Snap.active && !ui.overlayOpen {
            ScrollCatcher(onScroll: { dy in
                acc += dy
                while abs(acc) >= 6 { nudge(acc > 0 ? -5 : 5); acc -= acc > 0 ? 6 : -6 }
            }, onScrollX: { dx in
                accX += dx
                if abs(accX) > 60 { changeDay(accX > 0 ? -1 : 1); accX = 0 }
            }, onRotate: { deg in
                rot += deg
                while abs(rot) >= 1.5 { nudge(rot > 0 ? -5 : 5); rot -= rot > 0 ? 1.5 : -1.5 }
            })
        } })
        .onAppear {
            guard !Snap.active else { breathe = true; return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    private func hand(min: Int, color: Color, width: CGFloat, c: CGPoint) -> some View {
        let tip = DialMath.point(Double(min), radius: outerR + 2, center: c)
        let base = DialMath.point(Double(min), radius: innerR - 44, center: c)
        return ZStack {
            Path { pa in pa.move(to: base); pa.addLine(to: tip) }
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
            Circle().fill(color).frame(width: 7, height: 7).position(tip)
        }
    }

    @ViewBuilder
    private func center(r: Reading, day: Date) -> some View {
        let key = Days.key(day)
        let lot = ui.dialDay == 0 ? store.todayLot : store.lot(forDay: key)
        let d = innerR * 2 - 34
        ZStack {
            Circle()
                .fill(LinearGradient(colors: p.dark ? [Color(hex: 0x19191C), Color(hex: 0x2B2B2F)] : [Color(hex: 0xECECF0), Color.white],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color.black.opacity(p.dark ? 0.5 : 0.08), radius: 6, x: 3, y: 4)
            if let lot = lot {
                VStack(spacing: 4) {
                    Text(lot.levelShort).font(Typo.ui(9.5, .bold)).foregroundColor(paperInk)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Tone.color(lot.tone)))
                    if I18n.en {
                        Text(lot.displayName).font(Typo.song(20, bold: true)).foregroundColor(p.ink).multilineTextAlignment(.center)
                    } else {
                        VStack(spacing: -2) {
                            ForEach(Array(lot.name.enumerated()), id: \.offset) { _, ch in
                                Text(String(ch)).font(Typo.song(lot.name.count > 2 ? 18 : 28, bold: true)).foregroundColor(p.ink)
                            }
                        }
                    }
                    if ui.dialDay == 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "rectangle.portrait.on.rectangle.portrait").font(.system(size: 8, weight: .bold))
                            Text(L("翻看今日签"))
                            Image(systemName: "chevron.right").font(.system(size: 7, weight: .bold))
                        }
                        .font(Typo.ui(9.5, .bold)).foregroundColor(p.mono)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(p.mono.opacity(hoverCenter ? 0.22 : 0.12)))
                        .overlay(Capsule().strokeBorder(p.mono.opacity(0.45), lineWidth: 0.8))
                        .padding(.top, 2)
                    } else {
                        Text(Days.md(day)).font(Typo.ui(9.5, .semibold)).foregroundColor(p.ink3)
                    }
                }
            } else {
                VStack(spacing: 2) {
                    Text("\(Days.cal.component(.day, from: day))").font(Typo.num(40, .bold)).foregroundColor(p.ink)
                    Text(Days.weekday(day) + " · " + Almanac.of(day).lunarShort).font(Typo.ui(11, .semibold)).foregroundColor(p.ink2)
                }
            }
        }
        .frame(width: d, height: d)
        .scaleEffect(hoverCenter && ui.dialDay == 0 ? 1.03 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hoverCenter)
        .onHover { h in hoverCenter = h; (h && ui.dialDay == 0 ? NSCursor.pointingHand : NSCursor.arrow).set() }
        .demoTarget("dial.center")
        .onDemo { c in
            if case .act(let a) = c {
                if a == "dial.hover" { hoverCenter = true } else if a == "dial.unhover" { hoverCenter = false }
            }
        }
    }

    // MARK: 交互

    private func setProbe(_ m: Int) {
        let mm = ((m % 1440) + 1440) % 1440
        let b = DialMath.branch(mm)
        if b != lastBranch {
            lastBranch = b
            if !Snap.active { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
        }
        ui.probeMinutes = mm
    }

    private func nudge(_ delta: Int) {
        let base = ui.probeMinutes ?? DialMath.minuteOfDay(Days.now)
        setProbe(base + delta)
    }

    private func changeDay(_ d: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            ui.dialDay = max(-30, min(30, ui.dialDay + d))
            ui.probeMinutes = nil
        }
        if !Snap.active { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
    }

    private func dragGesture(c: CGPoint, todos: [Reminder]) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let dist = hypot(v.location.x - c.x, v.location.y - c.y)
                if !dragStarted {
                    dragStarted = true
                    dragFromCenter = dist < innerR - 16
                    // 是否按在某个待办圆点上
                    for t in todos where !t.done {
                        let pt = DialMath.point(Double(DialMath.minuteOfDay(t.time!)), radius: orbitR, center: c)
                        if hypot(v.startLocation.x - pt.x, v.startLocation.y - pt.y) < 14 {
                            dragTodo = t.id
                            dragMin = DialMath.minuteOfDay(t.time!)
                            break
                        }
                    }
                }
                if dragFromCenter && dragTodo == nil { return }
                let m = Int(DialMath.minutes(at: v.location, center: c))
                if dragTodo != nil {
                    let snapped = (m / 5) * 5
                    if DialMath.branch(snapped) != DialMath.branch(dragMin) && !Snap.active {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    }
                    dragMin = snapped
                } else {
                    setProbe((m / 5) * 5)
                }
            }
            .onEnded { v in
                defer { dragStarted = false; dragFromCenter = false }
                if let id = dragTodo {
                    store.retime(id: id, minuteOfDay: dragMin)
                    dragTodo = nil
                    return
                }
                let moved = hypot(v.translation.width, v.translation.height)
                if dragFromCenter && moved < 6 {
                    if ui.dialDay == 0 && store.todayLot != nil {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { ui.lotOpen = true }
                    } else if ui.dialDay != 0 {
                        changeDay(-ui.dialDay)
                    }
                }
            }
    }
}

// MARK: - 时辰轮下方：拨到的时辰怎么样

struct ProbeCard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p

    var body: some View {
        let day = Days.addDays(ui.dialDay, to: Days.startOfDay(Days.now))
        let s = store.data.settings
        let r = Fortune.reading(for: day, birth: s.birthOn ? s.birthDate : nil, birthHour: s.birthHour)
        let m = ui.probeMinutes ?? (ui.dialDay == 0 ? DialMath.minuteOfDay(Days.now) : 9 * 60)
        let b = DialMath.branch(m)
        let sl = r.slots.first { $0.branch == b }!
        let k = Fortune.gods.firstIndex(of: sl.god) ?? 0
        let advice = sl.good ? LF("宜%@", L(Fortune.godDo[k])) : LF("忌%@", L(Fortune.godDont[k]))
        let inSlot = store.reminders(on: Days.key(day)).filter { t in
            guard let tm = t.time else { return false }
            return DialMath.branch(DialMath.minuteOfDay(tm)) == b
        }
        HStack(spacing: 12) {
            Text(Almanac.branches[b])
                .font(Typo.song(22, bold: true))
                .foregroundColor(sl.good ? p.onAccent : p.ink)
                .frame(width: 46, height: 46)
                .background(Circle().fill(sl.good ? p.accent : Color.clear))
                .overlay(Circle().strokeBorder(sl.personalClash ? p.mono : (sl.good ? Color.clear : p.ink2), style: StrokeStyle(lineWidth: 1.5, dash: sl.personalClash ? [3, 2] : [])))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(ui.probeMinutes == nil && ui.dialDay == 0 ? L("现在") : DialMath.hm(m)).font(Typo.ui(11, .bold)).foregroundColor(p.mono)
                    Text(sl.range + " · " + L(sl.god) + " · " + L(sl.good ? "吉" : "凶"))
                        .font(Typo.ui(11.5, .semibold)).foregroundColor(p.ink2).lineLimit(1)
                }
                Text(sl.personalClash ? L("你的冲时：别拍板、别签字") : advice)
                    .font(Typo.ui(13.5, .bold)).foregroundColor(p.ink).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                if ui.probeMinutes == nil && ui.dialDay == 0 {
                    let el = (m - ((b * 2 + 23) % 24) * 60 + 1440) % 1440
                    Text(LF("%@已过 %@ · 还剩 %d 分", sl.name, el >= 60 ? LF("%d 小时 %d 分", el / 60, el % 60) : LF("%d 分", el), 120 - el))
                        .font(Typo.ui(10.5, .semibold)).foregroundColor(p.mono)
                }
                if let t = inSlot.first {
                    HStack(spacing: 4) {
                        Image(systemName: "alarm").font(.system(size: 9.5, weight: .bold))
                        Text((t.time.map(Days.hm) ?? "") + " " + t.title + (inSlot.count > 1 ? LF(" 等 %d 件", inSlot.count) : ""))
                    }
                    .font(Typo.ui(11)).foregroundColor(sl.good ? p.ink2 : p.ink).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if ui.probeMinutes != nil || ui.dialDay != 0 {
                Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { ui.probeMinutes = nil; ui.dialDay = 0 } }) {
                    Image(systemName: "arrow.uturn.backward").font(.system(size: 11, weight: .bold)).foregroundColor(p.ink)
                        .frame(width: 30, height: 30).background(Circle().fill(p.glassFill2))
                }.buttonStyle(PressStyle())
            }
        }
        .padding(12)
        .glass(22, depth: 1)
    }
}

// MARK: - 宣纸纤维纹理（极淡）

struct PaperGrain: View {
    @Environment(\.pal) private var p
    var body: some View {
        Image(nsImage: PaperGrain.image(dark: p.dark))
            .resizable()
            .allowsHitTesting(false)
    }

    private static var cache: [Bool: NSImage] = [:]
    static func image(dark: Bool) -> NSImage {
        if let i = cache[dark] { return i }
        let size = NSSize(width: 380, height: 640)
        let img = NSImage(size: size, flipped: true) { r in
            var seed: UInt64 = 0x5EED
            func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(Double(seed >> 33) / Double(1 << 31)) }
            let base = dark ? NSColor.white : NSColor(red: 0.23, green: 0.19, blue: 0.13, alpha: 1)
            for _ in 0..<260 {
                let x = rnd() * r.width, y = rnd() * r.height
                let len = 4 + rnd() * 14, a = rnd() * .pi
                let path = NSBezierPath()
                path.move(to: NSPoint(x: x, y: y))
                path.curve(to: NSPoint(x: x + cos(a) * len, y: y + sin(a) * len),
                           controlPoint1: NSPoint(x: x + cos(a + 0.4) * len / 2, y: y + sin(a + 0.4) * len / 2),
                           controlPoint2: NSPoint(x: x + cos(a + 0.2) * len * 0.8, y: y + sin(a + 0.2) * len * 0.8))
                path.lineWidth = 0.6
                base.withAlphaComponent(0.035 + rnd() * 0.03).setStroke()
                path.stroke()
            }
            return true
        }
        cache[dark] = img
        return img
    }
}
