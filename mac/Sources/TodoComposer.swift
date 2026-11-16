import SwiftUI

// MARK: - 新建待办（参考 iPhone 闹钟）
// 顶部：取消 · 新建待办 · 添加；中间：大号 时 : 分 滚轮；下面：事项名、日期胶囊、快捷时间；底部一句“将在……提醒”。

struct TodoComposer: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    @State private var title: String
    @State private var dayOffset: Int
    @State private var hour: Int
    @State private var minute: Int

    init(initial: String = "") {
        let t = Days.now.addingTimeInterval(30 * 60)
        let c = Days.cal.dateComponents([.hour, .minute], from: t)
        let m5 = (c.minute! + 4) / 5 * 5
        var h = c.hour! + m5 / 60
        var off = 0
        if h >= 24 { h -= 24; off = 1 }
        var text = initial
        if Snap.active && text.isEmpty { text = L("取快递") }
        _title = State(initialValue: text)
        _dayOffset = State(initialValue: off)
        _hour = State(initialValue: Snap.active ? 15 : h)
        _minute = State(initialValue: Snap.active ? 0 : m5 % 60)
    }

    private var when: Date {
        let d = Days.addDays(dayOffset, to: Days.startOfDay(Days.now))
        return Days.cal.date(bySettingHour: hour, minute: minute, second: 0, of: d)!
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 14) {
            // 顶栏
            HStack {
                Button(L("取消"), action: close).buttonStyle(.plain).font(Typo.ui(14)).foregroundColor(p.tint)
                Spacer()
                Text(L("新建待办")).font(Typo.ui(15, .bold)).foregroundColor(p.ink)
                Spacer()
                Button(L("添加"), action: save).buttonStyle(.plain).font(Typo.ui(14, .bold))
                    .foregroundColor(canSave ? p.tint : p.ink3).disabled(!canSave)
                    .demoTarget("composer.add")
            }

            // 大号时间滚轮
            WheelGroup(rowH: 44) {
                WheelColumn(count: 24, label: { String(format: "%02d", $0) }, selection: $hour, width: 96, rowH: 44, font: 40, align: .trailing)
                Text(":").font(.system(size: 36, weight: .light, design: .rounded)).foregroundColor(p.ink).frame(width: 22).offset(y: -3)
                WheelColumn(count: 60, label: { String(format: "%02d", $0) }, selection: $minute, width: 96, rowH: 44, font: 40, align: .leading)
            }
            .padding(.vertical, -6)
            .demoTarget("composer.wheel")
            .onDemo { c in
                switch c {
                case .text("composer.title", let v): title = v
                case .text("composer.time", let v):
                    let parts = v.split(separator: ":").compactMap { Int($0) }
                    if parts.count == 3 {
                        withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) { dayOffset = parts[0]; hour = parts[1]; minute = parts[2] }
                    }
                case .act("composer.add"): save()
                default: break
                }
            }

            // 日期胶囊
            dayStrip

            // 事项名 + 快捷时间
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text(L("事项")).font(Typo.ui(13.5)).foregroundColor(p.ink).fixedSize()
                    Field(placeholder: L("要做什么？也可以写「明天下午3点 开会」"), text: $title, size: 13.5, onSubmit: save)
                        .multilineTextAlignment(.trailing)
                        .demoTarget("composer.title")
                }
                .padding(.horizontal, 14).frame(height: 44)
                Rectangle().fill(p.hairline).frame(height: 1).padding(.leading, 14)
                HStack(spacing: 6) {
                    Text(L("快捷")).font(Typo.ui(13.5)).foregroundColor(p.ink).fixedSize()
                    Spacer(minLength: 4)
                    quick(L("20分钟后")) { set(Days.now.addingTimeInterval(20 * 60)) }
                    quick(L("1小时后")) { set(Days.now.addingTimeInterval(3600)) }
                    quick(L("今晚 8 点")) { set(Days.cal.date(bySettingHour: 20, minute: 0, second: 0, of: Days.now)!) }
                    quick(L("明早 9 点")) { set(Days.cal.date(bySettingHour: 9, minute: 0, second: 0, of: Days.addDays(1, to: Days.now))!) }
                }
                .padding(.horizontal, 14).frame(height: 44)
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.glassFill2))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(p.hairline, lineWidth: 1))

            // 提示
            HStack(spacing: 6) {
                Image(systemName: "alarm").font(.system(size: 12, weight: .semibold)).foregroundColor(p.ink2)
                Text(LF("将在 %@ 提醒", Days.relative(when) + " " + Days.hm(when)) + " · " + countdown)
                    .font(Typo.ui(12)).foregroundColor(p.ink2)
                Spacer()
            }
            conflict
        }
        .onAppear { if !ui.scheduleDraft.isEmpty { title = ui.scheduleDraft; ui.scheduleDraft = "" } }
        .onChange(of: title) { t in
            let e = NLParser.parse(t)
            if let tm = e.time { set(tm) }
            else if !e.ranges.isEmpty {
                let off = Days.cal.dateComponents([.day], from: Days.startOfDay(Days.now), to: Days.startOfDay(e.day)).day ?? 0
                withAnimation { dayOffset = max(0, min(13, off)) }
            }
        }
    }

    private var countdown: String {
        let mins = Int(when.timeIntervalSince(Days.now) / 60)
        if mins < 0 { return L("已过去，请换个时间") }
        if mins < 60 { return LF("%d 分钟后", mins) }
        if mins < 1440 { return LF("%d 小时 %d 分钟后", mins / 60, mins % 60) }
        return LF("%d 天后", mins / 1440)
    }

    private var dayStrip: some View {
        let row = HStack(spacing: 6) {
            ForEach(0..<14, id: \.self) { i in
                let d = Days.addDays(i, to: Days.startOfDay(Days.now))
                let sel = i == dayOffset
                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { dayOffset = i } }) {
                    VStack(spacing: 1) {
                        Text(i < 3 ? Days.relative(d) : Days.weekday(d)).font(Typo.ui(11.5, .bold))
                        Text(Days.md(d)).font(Typo.ui(9.5)).opacity(0.7)
                    }
                    .foregroundColor(sel ? p.onAccent : p.ink)
                    .frame(width: 58, height: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(sel ? p.accent : p.glassFill2))
                }.buttonStyle(PressStyle())
            }
        }
        return Group {
            if Snap.active {
                Color.clear.overlay(alignment: .leading) { row.fixedSize() }.clipped()
            } else {
                ScrollView(.horizontal, showsIndicators: false) { row }
            }
        }
        .frame(height: 40)
    }

    private func quick(_ t: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(t).font(Typo.ui(11, .semibold)).foregroundColor(p.tint).lineLimit(1).fixedSize()
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Capsule().fill(p.tint.opacity(0.10)))
        }.buttonStyle(PressStyle())
    }

    private func set(_ t: Date) {
        let off = Days.cal.dateComponents([.day], from: Days.startOfDay(Days.now), to: Days.startOfDay(t)).day ?? 0
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            dayOffset = max(0, min(13, off))
            hour = Days.cal.component(.hour, from: t)
            minute = Days.cal.component(.minute, from: t)
        }
    }

    @ViewBuilder
    private var conflict: some View {
        let e = NLParser.parse(title)
        if let act = Almanac.guessActivity(e.title) {
            let a = Almanac.of(when)
            if a.ji.contains(act), let alt = Almanac.bestDays(for: act, within: 14).first {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle").font(.system(size: 12, weight: .bold)).foregroundColor(p.ink)
                    Text(Days.md(when) + " " + L("忌") + L(act) + " · " + L("建议改到") + " " + Days.md(alt.date))
                        .font(Typo.ui(11.5, .semibold)).foregroundColor(p.ink).lineLimit(1)
                    Spacer()
                    Button(L("改到那天")) { set(Days.cal.date(bySettingHour: hour, minute: minute, second: 0, of: alt.date)!) }
                        .buttonStyle(.plain).font(Typo.ui(11.5, .bold)).foregroundColor(p.tint)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(p.glassFill2))
            }
        }
    }

    private func save() {
        let raw = title.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        let e = NLParser.parse(raw)
        let name = e.title.isEmpty ? raw : e.title
        store.addReminder(title: name, day: Days.key(when), time: when)
        title = ""
        close()
    }

    private func close() { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { ui.composerOpen = false } }
}

/// 打开新建待办的按钮
struct NewTodoButton: View {
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { ui.dockOpen = false; ui.composerOpen = true } }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(p.tint)
                Text(L("新建待办")).font(Typo.ui(13.5, .bold)).foregroundColor(p.ink)
                Spacer()
                Image(systemName: "alarm").font(.system(size: 12, weight: .semibold)).foregroundColor(p.ink3)
            }
            .padding(.horizontal, 14).frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.glassFill2))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(p.hairline, lineWidth: 1))
        }.buttonStyle(PressStyle())
    }
}
