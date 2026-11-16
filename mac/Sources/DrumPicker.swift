import SwiftUI

// MARK: - 滚轮列（像 iPhone 闹钟）：中间一行大字，上下渐隐带透视；两指滑动 / 两指旋转 / 拖动 / 点上下行

struct WheelColumn: View {
    @Environment(\.pal) private var p
    let count: Int
    let label: (Int) -> String
    @Binding var selection: Int
    var wrap = true
    var width: CGFloat = 80
    var rowH: CGFloat = 36
    var font: CGFloat = 30
    var align: Alignment = .center

    @State private var virt: Int? = nil
    @State private var drag: CGFloat = 0
    @State private var acc: CGFloat = 0
    @State private var rot: CGFloat = 0

    private func mod(_ i: Int) -> Int { ((i % count) + count) % count }

    private func step(_ d: Int) {
        let cur = virt ?? selection
        var n = cur + d
        if !wrap { n = max(0, min(count - 1, n)) }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { virt = n; selection = mod(n) }
    }

    var body: some View {
        let v = virt ?? selection
        let pos = Double(v) - Double(drag / rowH)
        let c = Int(pos.rounded())
        ZStack {
            ForEach((c - 3)...(c + 3), id: \.self) { k in
                if wrap || (0..<count).contains(k) {
                    let rel = Double(k) - pos
                    let a = abs(rel)
                    Text(label(mod(k)))
                        .font(.system(size: font, weight: a < 0.5 ? .medium : .regular, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(a < 0.5 ? p.ink : p.ink2)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .frame(width: width - 8, alignment: align)
                        .scaleEffect(1 - min(a, 3) * 0.12)
                        .rotation3DEffect(.degrees(-rel * 20), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
                        .opacity(max(0, 1 - a * 0.33))
                        .offset(y: CGFloat(rel) * rowH * (1 - min(a, 3) * 0.05))
                        .onTapGesture { if a > 0.5 { step(k - v) } }
                }
            }
        }
        .frame(width: width, height: rowH * 5)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { g in drag = g.translation.height }
                .onEnded { g in
                    let target = Int((Double(v) - Double(g.predictedEndTranslation.height / rowH)).rounded())
                    drag = 0
                    step(target - v)
                }
        )
        .background(Group { if !Snap.active {
            ScrollCatcher(onScroll: { dy in
                acc += dy
                while abs(acc) >= 11 { step(acc > 0 ? -1 : 1); acc -= acc > 0 ? 11 : -11 }
            }, onRotate: { r in
                rot += r
                if abs(rot) >= 8 { step(rot > 0 ? -1 : 1); rot = 0 }
            })
        } })
        .onChange(of: selection) { s in
            let cur = virt ?? s
            if mod(cur) != s { virt = cur - mod(cur) + s }
        }
    }
}

/// 一组滚轮的公共底板：一条贯穿的选中高亮带
struct WheelGroup<Content: View>: View {
    @Environment(\.pal) private var p
    var rowH: CGFloat = 36
    let content: Content
    init(rowH: CGFloat = 36, @ViewBuilder content: () -> Content) { self.rowH = rowH; self.content = content() }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(p.dark ? Color.white.opacity(0.09) : Color(hex: 0x111113, alpha: 0.05))
                .frame(height: rowH + 4)
            HStack(spacing: 0) { content }
        }
        .frame(height: rowH * 5)
    }
}

// MARK: - 生辰编辑（只在“修改”时出现）

struct BirthEditor: View {
    @Environment(\.pal) private var p
    @State private var y: Int
    @State private var m: Int
    @State private var d: Int
    @State private var h: Int
    var onSave: (Date, Int) -> Void
    var onCancel: () -> Void
    var showCancel = true
    var saveTitle = "保存并固定"

    private let years = Array(1940...2026)
    private var dayCount: Int {
        let c = DateComponents(year: years[y], month: m + 1)
        return Days.cal.range(of: .day, in: .month, for: Days.cal.date(from: c)!)?.count ?? 31
    }

    init(initialDate: Date?, initialHour: Int, showCancel: Bool = true, saveTitle: String = "保存并固定",
         onSave: @escaping (Date, Int) -> Void, onCancel: @escaping () -> Void = {}) {
        self.showCancel = showCancel
        self.saveTitle = saveTitle
        let b = initialDate ?? Days.cal.date(from: DateComponents(year: 1995, month: 6, day: 18))!
        let c = Days.cal.dateComponents([.year, .month, .day], from: b)
        _y = State(initialValue: max(0, min(86, c.year! - 1940)))
        _m = State(initialValue: c.month! - 1)
        _d = State(initialValue: c.day! - 1)
        _h = State(initialValue: ((initialHour + 1) / 2) % 12)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        let date = Days.cal.date(from: DateComponents(year: years[y], month: m + 1, day: min(d + 1, dayCount), hour: 12))!
        let bz = Fortune.bazi(date: date, hour: h * 2)
        VStack(spacing: 10) {
            WheelGroup(rowH: 30) {
                WheelColumn(count: years.count, label: { "\(years[$0])" }, selection: $y, wrap: false, width: 78, rowH: 30, font: 19).demoTarget("birth.y")
                WheelColumn(count: 12, label: { LF("%d月", $0 + 1) }, selection: $m, width: 62, rowH: 30, font: 19).demoTarget("birth.m")
                WheelColumn(count: dayCount, label: { LF("%d日", $0 + 1) }, selection: $d, width: 62, rowH: 30, font: 19).demoTarget("birth.d")
                WheelColumn(count: 12, label: { L(Almanac.branches[$0] + "时") }, selection: $h, width: 74, rowH: 30, font: 19).demoTarget("birth.h")
            }
            Text(L("八字") + "  " + bz.text + "  · " + LF("属%@", L(bz.zodiac)))
                .font(Typo.song(13, bold: true)).foregroundColor(p.ink2)
            HStack(spacing: 10) {
                if showCancel { Button(action: onCancel) {
                    Text(L("取消")).font(Typo.ui(13, .bold)).foregroundColor(p.ink)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(Capsule().fill(p.glassFill2)).overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
                }.buttonStyle(PressStyle()) }
                Button(action: { onSave(date, h * 2) }) {
                    Text(L(saveTitle)).font(Typo.ui(13, .bold)).foregroundColor(p.onAccent)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(Capsule().fill(p.accent))
                }.buttonStyle(PressStyle()).demoTarget("birth.save")
            }
        }
        .onDemo { c in
            switch c {
            case .text(let id, let v):
                let n = Int(v) ?? 0
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    switch id { case "birth.y": y = n; case "birth.m": m = n; case "birth.d": d = n; case "birth.h": h = n; default: break }
                }
            case .act("birth.save"): onSave(date, h * 2)
            default: break
            }
        }
        .onChange(of: m) { _ in if d >= dayCount { d = dayCount - 1 } }
        .onChange(of: y) { _ in if d >= dayCount { d = dayCount - 1 } }
    }
}

// MARK: - 命盘卡（生辰设好后固定显示，只给一个“修改”入口）

struct MingPan: View {
    @EnvironmentObject var store: Store
    @Environment(\.pal) private var p
    @State private var editing: Bool
    init(startEditing: Bool = false) { _editing = State(initialValue: startEditing) }

    var body: some View {
        let s = store.data.settings
        VStack(alignment: .leading, spacing: 12) {
            if editing {
                BirthEditor(initialDate: s.birthDate, initialHour: s.birthHour, onSave: { date, hour in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        store.update { $0.birthDate = date; $0.birthHour = hour; $0.birthOn = true }
                        editing = false
                    }
                }, onCancel: { withAnimation { editing = false } })
            } else if s.birthOn, let b = s.birthDate {
                let bz = Fortune.bazi(date: b, hour: s.birthHour)
                HStack(spacing: 6) {
                    ForEach(Array(zip([L("年柱"), L("月柱"), L("日柱"), L("时柱")], bz.pillars).enumerated()), id: \.offset) { i, pr in
                        VStack(spacing: 4) {
                            Text(pr.0).font(Typo.ui(9.5, .bold)).foregroundColor(p.ink3)
                            VStack(spacing: 0) {
                                Text(String(pr.1.prefix(1))).font(Typo.song(20, bold: true))
                                Text(String(pr.1.suffix(1))).font(Typo.song(20, bold: true))
                            }
                            .foregroundColor(i == 2 ? p.onAccent : p.ink)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(i == 2 ? p.accent : p.glassFill2))
                        }
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold)).foregroundColor(p.ink3)
                    Text(Days.key(b) + " " + L(Almanac.branches[((s.birthHour + 1) / 2) % 12] + "时") + " · " + LF("属%@", L(bz.zodiac))
                         + " · " + L("日主") + Almanac.stems[bz.dayStem] + L(Fortune.elements[bz.element]))
                        .font(Typo.ui(11)).foregroundColor(p.ink2).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Button(L("修改")) { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { editing = true } }
                        .buttonStyle(.plain).font(Typo.ui(12, .bold)).foregroundColor(p.tint)
                }
                Text(L("已固定。今日断语、问事、抽签都以这个八字为准。")).font(Typo.ui(10.5)).foregroundColor(p.ink3)
            } else {
                Text(L("还没设置生辰。设好后，断语、问事、抽签都会按你的八字推算；只存本机，不上传。"))
                    .font(Typo.ui(12)).foregroundColor(p.ink2).fixedSize(horizontal: false, vertical: true)
                Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { editing = true } }) {
                    HStack(spacing: 6) { Image(systemName: "plus"); Text(L("设置生辰")) }
                        .font(Typo.ui(13, .bold)).foregroundColor(p.onAccent)
                        .padding(.horizontal, 16).frame(height: 36).background(Capsule().fill(p.accent))
                }.buttonStyle(PressStyle())
            }
        }
    }
}
