import SwiftUI

// MARK: - 截图模式开关
// 截图模式下用纯 SwiftUI 渲染（ImageRenderer），原生滚动/输入控件换成等价的静态视图。

enum Snap {
    static var active = false
    static var scroll: CGFloat = 0
}

struct Scroller<Content: View>: View {
    var axis: Axis.Set = .vertical
    let content: Content
    init(_ axis: Axis.Set = .vertical, @ViewBuilder content: () -> Content) {
        self.axis = axis
        self.content = content()
    }
    var body: some View {
        if Snap.active {
            // 用 overlay 承载内容：内容再高也不会撑大外层布局（真实 ScrollView 的行为）
            Color.clear
                .overlay(alignment: .top) {
                    content
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(y: axis == .vertical ? -Snap.scroll : 0)
                }
                .clipped()
        } else if Demo.active {
            ScrollViewReader { proxy in
                ScrollView(axis, showsIndicators: false) { content }
                    .onDemo { c in
                        if case .scroll(let id) = c { withAnimation(.easeInOut(duration: 1.3)) { proxy.scrollTo(id, anchor: .top) } }
                    }
            }
        } else {
            ScrollView(axis, showsIndicators: false) { content }
        }
    }
}

/// 上下边缘渐隐（渐进模糊感），让内容滚到边缘时“沉”进玻璃，不会被硬切
struct EdgeFade: ViewModifier {
    var top: CGFloat = 12
    var bottom: CGFloat = 18
    func body(content: Content) -> some View {
        content.mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: top)
                Rectangle().fill(Color.black)
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: bottom)
            }
        )
    }
}

extension View {
    func edgeFade(top: CGFloat = 12, bottom: CGFloat = 18) -> some View { modifier(EdgeFade(top: top, bottom: bottom)) }
}

struct Field: View {
    @Environment(\.pal) private var p
    let placeholder: String
    @Binding var text: String
    var size: CGFloat = 13
    var onSubmit: () -> Void = {}
    var body: some View {
        if Snap.active {
            Text(text.isEmpty ? placeholder : text)
                .font(Typo.ui(size))
                .foregroundColor(text.isEmpty ? p.ink3 : p.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
        } else {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Typo.ui(size))
                .foregroundColor(p.ink)
                .onSubmit(onSubmit)
        }
    }
}

struct SecretField: View {
    @Environment(\.pal) private var p
    let placeholder: String
    @Binding var text: String
    var body: some View {
        if Snap.active {
            Text(text.isEmpty ? placeholder : String(repeating: "•", count: 12))
                .font(Typo.ui(12.5)).foregroundColor(p.ink3)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            SecureField(placeholder, text: $text).textFieldStyle(.plain).font(Typo.ui(12.5)).foregroundColor(p.ink)
        }
    }
}

struct MultiField: View {
    @Environment(\.pal) private var p
    let placeholder: String
    @Binding var text: String
    var size: CGFloat = 14
    var minHeight: CGFloat = 80
    var body: some View {
        ZStack(alignment: .topLeading) {
            if Snap.active {
                Text(text.isEmpty ? placeholder : text)
                    .font(Typo.ui(size)).foregroundColor(text.isEmpty ? p.ink3 : p.ink)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                if text.isEmpty {
                    Text(placeholder).font(Typo.ui(size)).foregroundColor(p.ink3).padding(.top, 1).padding(.leading, 5)
                }
                TextEditor(text: $text)
                    .font(Typo.ui(size))
                    .foregroundColor(p.ink)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
        }
        .frame(minHeight: minHeight, alignment: .topLeading)
    }
}

// MARK: - 提醒胶囊行（已做=实心点，未做=空心点）

struct ReminderPill: View {
    @EnvironmentObject var store: Store
    let r: Reminder
    var ink: Color
    var ink2: Color
    var chip: Color
    var dotColor: Color
    var showDay = false

    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.toggle(r) } }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().strokeBorder(r.done ? dotColor : ink2, lineWidth: 1.6)
                    if r.done { Circle().fill(dotColor).padding(3.5) }
                }
                .frame(width: 18, height: 18)
                Text(r.time.map(Days.hm) ?? L("全天"))
                    .font(Typo.num(13, .semibold)).monospacedDigit()
                    .foregroundColor(r.done ? ink2 : ink)
                    .frame(width: 44, alignment: .leading)
                Text(r.title)
                    .font(Typo.ui(13.5, .semibold))
                    .foregroundColor(r.done ? ink2 : ink)
                    .strikethrough(r.done, color: ink2)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if r.done {
                    InkSeal(text: L("毕"), size: 22, color: ink2)
                        .transition(.asymmetric(insertion: .scale(scale: 2.2).combined(with: .opacity), removal: .opacity))
                }
                if showDay {
                    Text(Days.relative(Days.date(fromKey: r.day) ?? Days.now)).font(Typo.ui(11)).foregroundColor(ink2)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Capsule().fill(chip))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .contextMenu {
            Button(L("删除")) { store.delete(r) }
        }
    }
}

// MARK: - 一行快速添加（自然语言 + 时间高亮 + 必有提醒时间 + 忌日联动）
// 待办一定带时间：没说时间就默认“半小时后取整”（非今天则默认早上 9:00），可用 −/+ 或快捷按钮改。

struct QuickAdd: View {
    @EnvironmentObject var store: Store
    @Environment(\.pal) private var p
    @Binding var text: String
    var onLight = false
    var showConflict = true
    @State private var manual: Date? = nil

    private var hi: Color { p.tint }

    static func defaultTime(for day: Date, now: Date = Days.now) -> Date {
        let cal = Days.cal
        if cal.isDate(day, inSameDayAs: now) {
            let t = now.addingTimeInterval(30 * 60)
            let c = cal.dateComponents([.hour, .minute], from: t)
            let m = (c.minute! + 14) / 15 * 15
            return cal.date(bySettingHour: c.hour!, minute: 0, second: 0, of: day)!.addingTimeInterval(Double(m * 60))
        }
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: day)!
    }

    private func effective(_ e: ParsedEntry) -> Date {
        if let t = e.time { return t }
        if let m = manual { return m }
        return QuickAdd.defaultTime(for: e.day)
    }

    var body: some View {
        let parsed = NLParser.parse(text)
        let t = effective(parsed)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundColor(p.ink3)
                Field(placeholder: L("一句话添加：明天下午3点 开会"), text: $text, onSubmit: { add(parsed, at: t) })
                if !text.isEmpty {
                    Button(action: { add(parsed, at: t) }) {
                        Image(systemName: "arrow.up").font(.system(size: 12, weight: .bold))
                            .foregroundColor(p.onAccent)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(p.accent))
                    }.buttonStyle(PressStyle())
                }
            }
            .padding(.leading, 14).padding(.trailing, 6)
            .frame(height: 42)
            .background(Capsule().fill(p.glassFill2))
            .overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))

            if !text.isEmpty {
                preview(parsed)
                timeRow(parsed, t)
                if showConflict { conflict(parsed, t) }
            }
        }
        .onChange(of: text) { v in if v.isEmpty { manual = nil } }
    }

    private func preview(_ e: ParsedEntry) -> some View {
        let segs = NLParser.highlighted(text, ranges: e.ranges)
        var tx = Text("")
        for s in segs {
            tx = tx + Text(s.0).foregroundColor(s.1 ? hi : p.ink.opacity(0.75)).fontWeight(s.1 ? .bold : .regular)
        }
        return tx.font(Typo.ui(12)).lineLimit(1).padding(.horizontal, 6)
    }

    private func timeRow(_ e: ParsedEntry, _ t: Date) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Button(action: { manual = t.addingTimeInterval(-15 * 60) }) { Image(systemName: "minus").font(.system(size: 9, weight: .bold)).frame(width: 18, height: 18) }
                    .buttonStyle(.plain)
                Image(systemName: "alarm.fill").font(.system(size: 10, weight: .bold))
                Text(Days.relative(Days.startOfDay(t)).count > 3 ? Days.md(t) : Days.relative(t))
                    .font(Typo.ui(11.5, .bold)).lineLimit(1).fixedSize()
                Text(Days.hm(t)).font(Typo.num(12.5, .bold)).monospacedDigit().lineLimit(1).fixedSize()
                Button(action: { manual = t.addingTimeInterval(15 * 60) }) { Image(systemName: "plus").font(.system(size: 9, weight: .bold)).frame(width: 18, height: 18) }
                    .buttonStyle(.plain)
            }
            .foregroundColor(p.onTint)
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(Capsule().fill(p.tint))
            .fixedSize()
            if e.time == nil {
                quick(L("30分钟后"), Days.now.addingTimeInterval(30 * 60))
                quick(L("今晚8点"), Days.cal.date(bySettingHour: 20, minute: 0, second: 0, of: e.day)!)
                quick(L("明早9点"), Days.cal.date(bySettingHour: 9, minute: 0, second: 0, of: Days.addDays(1, to: Days.startOfDay(Days.now)))!)
            } else {
                Text("「\(e.title)」").font(Typo.ui(11.5)).foregroundColor(p.ink2).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private func quick(_ label: String, _ d: Date) -> some View {
        Button(action: { manual = d }) {
            Text(label).font(Typo.ui(10.5, .semibold)).foregroundColor(p.ink2).lineLimit(1).fixedSize()
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(Capsule().fill(p.glassFill2))
                .overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
        }.buttonStyle(PressStyle())
    }

    @ViewBuilder
    private func conflict(_ e: ParsedEntry, _ t: Date) -> some View {
        if let act = Almanac.guessActivity(e.title) {
            let a = Almanac.of(e.day)
            if a.ji.contains(act), let alt = Almanac.bestDays(for: act, from: Days.startOfDay(Days.now), within: 30, top: 5)
                .first(where: { $0.date > e.day }) ?? Almanac.bestDays(for: act).first {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "arrow.triangle.swap").font(.system(size: 13, weight: .bold)).foregroundColor(p.ink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Days.md(e.day) + " " + a.officerDisplay + " · " + L("忌") + " " + L(act)).font(Typo.ui(12, .bold)).foregroundColor(p.ink)
                        Text(L("建议改到") + " " + Days.md(alt.date) + " " + Days.weekday(alt.date) + " · " + alt.officerDisplay + " · " + L("宜") + " " + L(act))
                            .font(Typo.ui(11)).foregroundColor(p.ink2)
                    }
                    Spacer()
                    Button(action: { add(e, at: t, moveTo: alt.date) }) {
                        Text(L("改到那天")).font(Typo.ui(11.5, .bold))
                            .foregroundColor(p.onAccent)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(p.accent))
                    }.buttonStyle(PressStyle())
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.glassFill2))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(p.hairline, lineWidth: 1))
            }
        }
    }

    private func add(_ e: ParsedEntry, at t: Date, moveTo: Date? = nil) {
        let raw = text.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        var time = t
        if let m = moveTo {
            let hm = Days.cal.dateComponents([.hour, .minute], from: t)
            time = Days.cal.date(bySettingHour: hm.hour!, minute: hm.minute!, second: 0, of: m)!
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            store.addReminder(title: e.title, day: Days.key(time), time: time)
            text = ""
            manual = nil
        }
    }
}

// MARK: - 折叠列表：默认只显示前 3 条，其余折叠

struct Collapsible<Item: Identifiable, Row: View>: View {
    @Environment(\.pal) private var p
    let items: [Item]
    var limit = 3
    var spacing: CGFloat = 7
    let row: (Item) -> Row
    @State private var expanded = false

    init(_ items: [Item], limit: Int = 3, spacing: CGFloat = 7, @ViewBuilder row: @escaping (Item) -> Row) {
        self.items = items; self.limit = limit; self.spacing = spacing; self.row = row
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(expanded ? items : Array(items.prefix(limit))) { row($0) }
            if items.count > limit {
                Button(action: { withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { expanded.toggle() } }) {
                    HStack(spacing: 4) {
                        Text(expanded ? L("收起") : LF("展开全部 %d 项", items.count))
                        Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .bold))
                    }
                    .font(Typo.ui(11.5, .bold)).foregroundColor(p.ink2)
                    .frame(maxWidth: .infinity).frame(height: 28)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
    }
}
