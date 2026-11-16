import SwiftUI

// MARK: - 日程（单独一页）

struct ScheduleView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p

    var body: some View {
        let today = store.todayReminders
        let upcoming = store.upcoming
        let doneOld = store.data.reminders.filter { $0.done && $0.day < Days.todayKey }.sorted { $0.day > $1.day }.prefix(5)
        VStack(spacing: 0) {
            PageHeader(title: L("日程"), subtitle: L("一句话添加，时间自动识别"), back: { ui.go(.home) })
            Scroller {
                VStack(alignment: .leading, spacing: 14) {
                    NewTodoButton()

                    group(L("今天"), today)
                    let byDay = Dictionary(grouping: upcoming, by: { $0.day })
                    ForEach(byDay.keys.sorted(), id: \.self) { k in
                        group(Days.relative(Days.date(fromKey: k) ?? Days.now) + (k == Days.key(Days.addDays(1, to: Days.now)) ? "" : ""), byDay[k] ?? [], dayKey: k)
                    }
                    if !doneOld.isEmpty { group(L("最近完成"), Array(doneOld), showDay: true) }

                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge").foregroundColor(p.ink2)
                        Text(L("有时间的日程会发系统通知，可直接点「完成」或「稍后」；前一晚 21:00 预告（可在设置关闭）"))
                            .font(Typo.ui(10.5)).foregroundColor(p.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 16)
            }
            .edgeFade()
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ items: [Reminder], dayKey: String? = nil, showDay: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(Typo.ui(13, .bold)).foregroundColor(p.ink)
                if let k = dayKey, let d = Days.date(fromKey: k) {
                    let a = Almanac.of(d)
                    Text(Days.md(d) + " · " + a.officerName).font(Typo.ui(11)).foregroundColor(p.ink2)
                }
                Spacer()
                Text(LF("%d 项", items.filter { !$0.done }.count)).font(Typo.ui(11)).foregroundColor(p.ink3)
            }
            if items.isEmpty {
                Text(L("暂无")).font(Typo.ui(12)).foregroundColor(p.ink3).padding(.vertical, 4)
            }
            Collapsible(items, spacing: 8) { r in row(r, showDay: showDay) }
        }
        .padding(14)
        .glass(22, depth: 1)
    }

    private func row(_ r: Reminder, showDay: Bool) -> some View {
        let d = Days.date(fromKey: r.day) ?? Days.now
        let a = Almanac.of(d)
        let act = Almanac.guessActivity(r.title)
        let clash = act.map { a.ji.contains($0) } ?? false
        return HStack(spacing: 8) {
            ReminderPill(r: r, ink: p.ink, ink2: p.ink2, chip: p.glassFill2, dotColor: p.dark ? p.accent : p.ink, showDay: showDay)
            if clash, let act = act, !r.done {
                Button(action: {
                    if let best = Almanac.bestDays(for: act, from: Days.now).first {
                        withAnimation { store.move(r, toDay: Days.key(best.date)) }
                    }
                }) {
                    Text(L("忌") + L(act) + " · " + L("换日")).font(Typo.ui(10.5, .bold)).foregroundColor(p.onAccent)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Capsule().fill(p.accent))
                }.buttonStyle(PressStyle())
            }
            Button(action: { withAnimation { store.delete(r) } }) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(p.ink3)
                    .frame(width: 24, height: 24)
            }.buttonStyle(.plain)
        }
    }
}

// MARK: - 择日（未来 30 天挑最宜的 5 天）

struct PickDayView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p

    var body: some View {
        let best = Almanac.bestDays(for: ui.pickAct, from: Days.now)
        VStack(spacing: 0) {
            PageHeader(title: L("择日"), subtitle: L("未来 30 天 · 按传统建除宜忌本地推算"), back: { ui.go(.home) })
            Scroller {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("想做什么？")).font(Typo.ui(13, .bold)).foregroundColor(p.ink)
                        FlowLayout(spacing: 7) {
                            ForEach(Almanac.activities, id: \.self) { act in
                                Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { ui.pickAct = act } }) {
                                    Chip(text: act, strong: act == ui.pickAct)
                                }.buttonStyle(PressStyle())
                            }
                        }
                    }
                    .padding(14).glass(22, depth: 1)

                    HStack(alignment: .firstTextBaseline) {
                        Text(LF("最宜「%@」的 %d 天", L(ui.pickAct), best.count)).font(Typo.ui(15, .heavy)).foregroundColor(p.ink)
                        Spacer()
                        Text(L("已避开忌日")).font(Typo.ui(11)).foregroundColor(p.ink2)
                    }
                    .padding(.horizontal, 4)

                    ForEach(Array(best.enumerated()), id: \.offset) { i, a in dayRow(a, rank: i, all: best) }

                    HStack(spacing: 12) {
                        Image(systemName: "moon.stars").font(.system(size: 15, weight: .semibold)).foregroundColor(p.ink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("前一晚 21:00 提醒")).font(Typo.ui(13, .bold)).foregroundColor(p.ink)
                            Text(L("提前告诉你明天要做的事和宜忌")).font(Typo.ui(11)).foregroundColor(p.ink2)
                        }
                        Spacer()
                        GlassToggle(isOn: Binding(get: { store.data.settings.eveReminder },
                                                  set: { v in store.update { $0.eveReminder = v }; Notifier.shared.reschedule() }))
                    }
                    .padding(14).glass(22, depth: 1)
                    Text(L("新日程撞上忌日时，日程页会提示你换到更宜的一天 · 仅供娱乐参考"))
                        .font(Typo.ui(10.5)).foregroundColor(p.ink3).padding(.horizontal, 4)
                }
                .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 16)
            }
            .edgeFade()
        }
    }

    private func dayRow(_ a: DayAlmanac, rank: Int, all: [DayAlmanac]) -> some View {
        let s = Almanac.score(a, for: ui.pickAct)
        let maxS = all.map { Almanac.score($0, for: ui.pickAct) }.max() ?? 1
        let top = rank == 0 || s == maxS
        return HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(I18n.en ? Days.monthNamesEn[Days.cal.component(.month, from: a.date) - 1] : "\(Days.cal.component(.month, from: a.date))月").font(Typo.ui(10, .bold))
                Text("\(Days.cal.component(.day, from: a.date))").font(Typo.num(22, .heavy))
            }
            .foregroundColor(top ? p.onAccent : p.ink)
            .frame(width: 52, height: 56)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(top ? p.accent : p.glassFill2))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(Days.relative(a.date).count <= 2 ? Days.relative(a.date) + " · " + Days.weekday(a.date) : Days.weekday(a.date))
                        .font(Typo.ui(13, .bold)).foregroundColor(p.ink)
                    Text(a.lunarFull).font(Typo.ui(11)).foregroundColor(p.ink2)
                }
                HStack(spacing: 4) {
                    Text(a.officerName).font(Typo.ui(11, .bold)).foregroundColor(p.ink)
                    Text(L("宜") + " " + a.yi.prefix(3).map(L).joined(separator: "·")).font(Typo.ui(11)).foregroundColor(p.ink2).lineLimit(1)
                }
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        Capsule().fill(i < max(1, min(5, s)) ? (p.dark ? p.accent : p.ink) : p.ink3.opacity(0.5)).frame(width: 14, height: 4)
                    }
                }
            }
            Spacer()
            Button(action: {
                ui.scheduleDraft = Days.md(a.date) + " " + L(ui.pickAct)
                ui.go(.schedule)
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { ui.composerOpen = true }
            }) {
                Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundColor(p.ink)
                    .frame(width: 34, height: 34).background(Circle().fill(p.glassFill2))
                    .overlay(Circle().strokeBorder(p.hairline, lineWidth: 1))
            }.buttonStyle(PressStyle())
        }
        .padding(12)
        .glass(22, depth: 1)
    }
}

// MARK: - 便签：真正的便利贴（一叠贴在墙上，图钉固定；左右甩动换下一张）

struct NotesView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    @State private var draft = ""
    @State private var dragX: CGFloat = 0
    @State private var scrollAccX: CGFloat = 0

    var body: some View {
        let notes = store.data.notes
        let idx = notes.isEmpty ? 0 : ((ui.noteIndex % notes.count) + notes.count) % notes.count
        VStack(spacing: 0) {
            PageHeader(title: L("便签"), subtitle: LF("%d 张 · 左右拖动翻看，点开写回顾", notes.count), back: { ui.go(.home) })
            Scroller {
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.pencil").font(.system(size: 13, weight: .bold)).foregroundColor(p.ink3)
                        Field(placeholder: L("随手记一句…"), text: $draft, onSubmit: add)
                        if !draft.isEmpty {
                            Button(action: add) {
                                Text(L("贴上")).font(Typo.ui(12, .bold)).foregroundColor(p.onAccent)
                                    .padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(p.accent))
                            }.buttonStyle(PressStyle())
                        }
                    }
                    .padding(.leading, 14).padding(.trailing, 6).frame(height: 44)
                    .glass(22, depth: 1)

                    if notes.isEmpty {
                        Text(L("还没有便签。写下一个想法、一句话、一个念头。")).font(Typo.ui(12.5)).foregroundColor(p.ink2).padding(.top, 40)
                    } else {
                        stack(notes, idx)
                            .frame(height: 260)
                        HStack(spacing: 5) {
                            ForEach(0..<min(notes.count, 12), id: \.self) { i in
                                Capsule().fill(i == idx ? p.ink : p.ink3.opacity(0.5)).frame(width: i == idx ? 14 : 5, height: 5)
                            }
                        }
                        Collapsible(notes, spacing: 0) { n in
                            listRow(n, i: notes.firstIndex(of: n) ?? 0, last: n.id == notes.last?.id)
                        }
                        .glass(20, depth: 1)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 16)
            }
            .edgeFade()
        }
    }

    private func stack(_ notes: [Note], _ idx: Int) -> some View {
        ZStack {
            ForEach((0..<min(3, notes.count)).reversed(), id: \.self) { k in
                let n = notes[(idx + k) % notes.count]
                let isTop = k == 0
                PostIt(note: n, showPin: isTop)
                    .frame(width: 232, height: 220)
                    .rotationEffect(.degrees(isTop ? Double(dragX / 18) - 1.5 : (k == 1 ? 4 : -5)))
                    .offset(x: isTop ? dragX : CGFloat(k) * 6, y: CGFloat(k) * 5)
                    .zIndex(Double(10 - k))
                    .onTapGesture { if isTop { ui.go(.note(n.id)) } }
            }
        }
        .background(Group { if !Snap.active { ScrollCatcher(onScrollX: { dx in
            scrollAccX += dx
            if abs(scrollAccX) > 40 {
                let dir: CGFloat = scrollAccX > 0 ? 1 : -1
                scrollAccX = 0
                withAnimation(.easeIn(duration: 0.18)) { dragX = dir * 420 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { ui.noteIndex += 1; dragX = 0 }
            }
        }) } })
        .gesture(DragGesture(minimumDistance: 4)
            .onChanged { v in dragX = v.translation.width }
            .onEnded { v in
                if abs(v.translation.width) > 70 {
                    withAnimation(.easeIn(duration: 0.18)) { dragX = v.translation.width > 0 ? 420 : -420 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        ui.noteIndex += 1; dragX = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { dragX = 0 }
                }
            })
    }

    private func listRow(_ n: Note, i: Int, last: Bool) -> some View {
        let d = Days.date(fromKey: n.day) ?? Days.now
        return Button(action: { ui.go(.note(n.id)) }) {
            HStack(spacing: 12) {
                Text(Days.cal.component(.day, from: d).description)
                    .font(Typo.num(13, .bold)).foregroundColor(paperInk)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Tone.color(n.tone)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(n.text).font(Typo.ui(12.5, .semibold)).foregroundColor(p.ink).lineLimit(1)
                    Text(Days.md(d) + (store.lot(forDay: n.day).map { " · " + $0.displayName } ?? "") + (n.review.isEmpty ? "" : " · " + L("已写回顾")))
                        .font(Typo.ui(10.5)).foregroundColor(p.ink2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundColor(p.ink3)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .overlay(alignment: .bottom) { if !last { Rectangle().fill(p.hairline).frame(height: 1).padding(.leading, 58) } }
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func add() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { store.addNote(t); draft = ""; ui.noteIndex = 0 }
    }
}

/// 一张便利贴：方形纸、顶部胶黏区、图钉、右下角微卷翘、手写感字体
struct PostIt: View {
    @EnvironmentObject var store: Store
    let note: Note
    var showPin = true
    var body: some View {
        let d = Days.date(fromKey: note.day) ?? Days.now
        let base = Tone.color(note.tone)
        let deep = Tone.deep(note.tone)
        ZStack(alignment: .topLeading) {
            // 纸
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(LinearGradient(colors: [base, base, deep], startPoint: .top, endPoint: .bottomTrailing))
                .overlay(alignment: .top) {
                    Rectangle().fill(deep.opacity(0.35)).frame(height: 30)   // 背胶条
                }
                .overlay(alignment: .bottomTrailing) {
                    // 卷角
                    LinearGradient(colors: [Color.black.opacity(0.10), Color.white.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: 38, height: 38)
                        .clipShape(Triangle())
                }
                .shadow(color: Color.black.opacity(0.10), radius: 1, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.18), radius: 14, x: 4, y: 12)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(Days.md(d).uppercased()).font(Typo.ui(9.5, .bold)).tracking(1)
                    Spacer()
                    if let l = store.lot(forDay: note.day) { Text(l.displayName).font(Typo.song(10.5, bold: true)) }
                }
                .foregroundColor(paperInk.opacity(0.5))
                .frame(height: 22)
                Text(note.text)
                    .font(Typo.hand(19))
                    .foregroundColor(paperInk.opacity(0.88))
                    .lineSpacing(5)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if !note.review.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "text.bubble").font(.system(size: 10, weight: .bold))
                        Text(note.review).font(Typo.ui(10.5)).lineLimit(1)
                    }.foregroundColor(paperInk.opacity(0.5))
                }
            }
            .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 14)
            if showPin {
                Pushpin().offset(y: -12).frame(maxWidth: .infinity)
            }
        }
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct Pushpin: View {
    var body: some View {
        ZStack {
            Ellipse().fill(Color.black.opacity(0.25)).frame(width: 14, height: 6).blur(radius: 2).offset(x: 3, y: 13)
            Rectangle().fill(LinearGradient(colors: [Color(hex: 0x9A9AA0), Color(hex: 0x5A5A60)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 2, height: 10).offset(y: 9)
            Circle().fill(RadialGradient(colors: [Color(hex: 0x6A6A72), Color(hex: 0x1F1F24)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 11))
                .frame(width: 20, height: 20)
                .overlay(Circle().fill(Color.white.opacity(0.55)).frame(width: 6, height: 6).offset(x: -4, y: -4))
        }
    }
}

struct NoteDetailView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    let id: UUID
    @State private var text = ""
    @State private var review = ""
    @State private var loaded = false

    var body: some View {
        if let note = store.data.notes.first(where: { $0.id == id }) {
            let d = Days.date(fromKey: note.day) ?? Days.now
            let ink = Color(hex: 0x0E1206)
            VStack(spacing: 0) {
                PageHeader(title: L("便签"), subtitle: L("写于 ") + Days.md(d) + " " + Days.weekday(d), back: { save(note); ui.go(.notes) },
                           trailing: AnyView(Button(action: { store.deleteNote(note); ui.go(.notes) }) { IconCircle(symbol: "trash", size: 32) }.buttonStyle(PressStyle())))
                Scroller {
                    VStack(alignment: .leading, spacing: 14) {
                        MultiField(placeholder: L("写点什么…"), text: Binding(get: { loaded ? text : note.text }, set: { text = $0; loaded = true }), size: 15, minHeight: 110)
                            .environment(\.pal, Palette.make(dark: false))
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(LinearGradient(colors: [Tone.color(note.tone, dark: p.dark), Tone.deep(note.tone, dark: p.dark)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
                            .shadow(color: Color.black.opacity(p.dark ? 0.45 : 0.12), radius: 18, x: 0, y: 10)
                            .foregroundColor(ink)

                        SectionTitle(text: L("那天的签"))
                        if let lot = store.lot(forDay: note.day) {
                            HStack(alignment: .top, spacing: 12) {
                                LotFace(lot: lot, date: d, compact: true).frame(width: 70, height: 100)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(lot.levelText + " · " + lot.name).font(Typo.ui(12, .bold)).foregroundColor(p.ink2)
                                    Text(lot.poem).font(Typo.song(14, bold: true)).foregroundColor(p.ink).fixedSize(horizontal: false, vertical: true)
                                    Text(L("宜：") + lot.displayTodo.joined(separator: I18n.en ? ", " : "、")).font(Typo.ui(11.5)).foregroundColor(p.ink2).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(14).glass(22, depth: 1)
                        } else {
                            Text(L("那天没有抽签")).font(Typo.ui(12)).foregroundColor(p.ink2).padding(14).frame(maxWidth: .infinity, alignment: .leading).glass(22, depth: 1)
                        }

                        SectionTitle(text: L("回顾"))
                        MultiField(placeholder: L("现在回头看，这件事怎么样了？"), text: Binding(get: { loaded ? review : note.review }, set: { review = $0; if !loaded { text = note.text }; loaded = true }), size: 13, minHeight: 70)
                            .padding(14).glass(22, depth: 1)

                        if !Snap.active {
                            Button(action: { save(note); ui.go(.notes) }) {
                                Text(L("保存")).font(Typo.ui(14, .bold)).foregroundColor(p.onAccent)
                                    .frame(maxWidth: .infinity).frame(height: 42).background(Capsule().fill(p.accent))
                            }.buttonStyle(PressStyle())
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 16)
                }
                .edgeFade()
            }
        }
    }

    private func save(_ n: Note) {
        guard loaded else { return }
        var m = n
        m.text = text.isEmpty ? n.text : text
        m.review = review
        store.updateNote(m)
    }
}

// MARK: - 日历（有记录=小黑点，选中=黑底）

struct CalendarView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p

    var body: some View {
        let cal = Days.cal
        let month = cal.date(from: cal.dateComponents([.year, .month], from: ui.calMonth))!
        let comps = cal.dateComponents([.year, .month], from: month)
        let firstWeekday = (cal.component(.weekday, from: month) + 5) % 7
        let gridStart = Days.addDays(-firstWeekday, to: month)
        VStack(spacing: 0) {
            PageHeader(title: L("万年历 · 老黄历"), subtitle: L("点任意一天，看那天的宜忌、冲煞、时辰吉凶"), back: { ui.go(.home) })
            Scroller {
                VStack(spacing: 14) {
                    VStack(spacing: 12) {
                        HStack {
                            Text(verbatim: I18n.en ? "\(Days.monthNamesEn[comps.month! - 1]) \(comps.year!)" : "\(comps.year!)年\(comps.month!)月").font(Typo.ui(20, .heavy)).foregroundColor(p.ink)
                            Spacer()
                            Button(action: { shift(-1) }) { IconCircle(symbol: "chevron.left", size: 30) }.buttonStyle(PressStyle())
                            Button(action: { shift(1) }) { IconCircle(symbol: "chevron.right", size: 30) }.buttonStyle(PressStyle())
                            Button(action: { ui.go(.schedule) }) { IconCircle(symbol: "plus", size: 30, filled: true) }.buttonStyle(PressStyle())
                        }
                        HStack(spacing: 5) {
                            ForEach(I18n.en ? ["M", "T", "W", "T ", "F", "S", "S "] : ["一", "二", "三", "四", "五", "六", "日"], id: \.self) { w in
                                Text(w).font(Typo.ui(11, .bold)).foregroundColor(p.ink2)
                                    .frame(maxWidth: .infinity).frame(height: 24)
                                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(p.glassFill2))
                            }
                        }
                        VStack(spacing: 5) {
                            ForEach(0..<6, id: \.self) { row in
                                HStack(spacing: 5) {
                                    ForEach(0..<7, id: \.self) { col in
                                        cell(Days.addDays(row * 7 + col, to: gridStart), month: comps.month!)
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .glass(26, depth: 2)

                    HuangliCard()
                }
                .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 16)
            }
            .edgeFade()
        }
    }

    private func shift(_ n: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            ui.calMonth = Days.cal.date(byAdding: .month, value: n, to: ui.calMonth) ?? ui.calMonth
        }
    }

    private func cell(_ d: Date, month: Int) -> some View {
        let key = Days.key(d)
        let inMonth = Days.cal.component(.month, from: d) == month
        let sel = key == ui.selectedDay
        let isToday = key == Days.todayKey
        let has = store.hasRecord(key)
        let selFill: Color = p.dark ? p.accent : Color(hex: 0x111318)
        let selInk: Color = p.dark ? p.onAccent : .white
        return Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { ui.selectedDay = key } }) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    Text("\(Days.cal.component(.day, from: d))").font(Typo.num(14, .semibold))
                    Text(Almanac.of(d).lunarDayText).font(Typo.ui(7.5))
                        .opacity(0.7)
                }
                .foregroundColor(sel ? selInk : (inMonth ? p.ink : p.ink3))
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(sel ? selFill : (inMonth ? (p.dark ? Color.white.opacity(0.08) : Color.white) : (p.dark ? Color.white.opacity(0.02) : Color(hex: 0x111318, alpha: 0.04))))
                )
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isToday && !sel ? (p.dark ? p.accent : p.ink) : (inMonth && !p.dark ? Color(hex: 0x111318, alpha: 0.05) : .clear), lineWidth: isToday && !sel ? 1.5 : 1))
                .shadow(color: inMonth && !p.dark && !sel ? Color(hex: 0x1B2440, alpha: 0.06) : .clear, radius: 3, x: 0, y: 2)
                if has {
                    Circle().fill(sel ? selInk : (p.dark ? Color.white : Color(hex: 0x111318))).frame(width: 4.5, height: 4.5).padding(5)
                }
            }
        }
        .buttonStyle(PressStyle())
    }

    private var daySummary: some View {
        let d = Days.date(fromKey: ui.selectedDay) ?? Days.now
        let a = Almanac.of(d)
        let list = store.reminders(on: ui.selectedDay)
        let notes = store.data.notes.filter { $0.day == ui.selectedDay }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(Days.md(d) + " " + Days.weekday(d)).font(Typo.ui(15, .heavy)).foregroundColor(p.ink)
                Text(a.lunarFull + " · " + a.dayGZ + " · " + a.officerDisplay).font(Typo.ui(11)).foregroundColor(p.ink2)
            }
            FlowLayout(spacing: 6) {
                Text(L("宜")).font(Typo.ui(11.5, .heavy)).foregroundColor(p.ink).padding(.vertical, 5)
                ForEach(a.yi, id: \.self) { Chip(text: $0, strong: true) }
                Text(L("忌")).font(Typo.ui(11.5, .heavy)).foregroundColor(p.ink2).padding(.vertical, 5).padding(.leading, 4)
                ForEach(a.ji, id: \.self) { Chip(text: $0) }
            }
            if let lot = store.lot(forDay: ui.selectedDay) {
                HStack(spacing: 8) {
                    Image(systemName: "seal").foregroundColor(p.dark ? p.accent : p.ink)
                    Text(L("那天的签：") + lot.levelText + " · " + lot.displayName + "　" + lot.poem).font(Typo.ui(12)).foregroundColor(p.ink).lineLimit(1)
                }
            }
            Collapsible(list) { r in
                ReminderPill(r: r, ink: p.ink, ink2: p.ink2, chip: p.glassFill2, dotColor: p.dark ? p.accent : p.ink)
            }
            if !notes.isEmpty {
                Text(LF("便签 %d 张：", notes.count) + notes.map { $0.text }.joined(separator: " / ")).font(Typo.ui(11.5)).foregroundColor(p.ink2).lineLimit(2)
            }
            if list.isEmpty && store.lot(forDay: ui.selectedDay) == nil && notes.isEmpty {
                Text(L("这一天还没有记录")).font(Typo.ui(12)).foregroundColor(p.ink3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(22, depth: 1)
    }
}

// MARK: - 签册（历史签，邮票扇形展开）

struct AlbumView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    @State private var drag: CGFloat = 0
    @State private var albumAcc: CGFloat = 0

    var body: some View {
        let hist = store.drawHistory
        let unique = Set(hist.map { $0.lotNo }).count
        VStack(spacing: 0) {
            PageHeader(title: L("签册"), subtitle: LF("已收 %d 支 · 图鉴 %d/%d", hist.count, unique, LotLibrary.all.count), back: { ui.go(.home) })
            if hist.isEmpty {
                Spacer()
                Text(L("还没有签。明天早上 8 点后再来抽一支吧。")).font(Typo.ui(13)).foregroundColor(p.ink2)
                Spacer()
            } else {
                let idx = min(ui.albumIndex, hist.count - 1)
                ZStack {
                    ForEach(Array(hist.enumerated()), id: \.offset) { i, rec in
                        let rel = Double(i - idx) + Double(drag)
                        let a = abs(rel)
                        if a < 4.5 {
                            LotStamp(lot: LotLibrary.lot(rec.lotNo), day: rec.day)
                                .rotationEffect(.degrees(rel * 9), anchor: .bottom)
                                .offset(x: rel * 46, y: a * a * 4)
                                .scaleEffect(1 - min(a, 3) * 0.06)
                                .blur(radius: max(0, a - 0.6) * 1.2)
                                .zIndex(-a)
                                .onTapGesture { withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) { ui.albumIndex = i } }
                        }
                    }
                }
                .frame(height: 260)
                .padding(.top, 14)
                .contentShape(Rectangle())
                .background(Group { if !Snap.active { ScrollCatcher(onScrollX: { dx in
                    albumAcc += dx
                    if abs(albumAcc) > 24 {
                        let step = albumAcc > 0 ? -1 : 1; albumAcc = 0
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { ui.albumIndex = max(0, min(hist.count - 1, idx + step)) }
                    }
                }) } })
                .gesture(DragGesture(minimumDistance: 4)
                    .onChanged { v in drag = v.translation.width / 90 }
                    .onEnded { v in
                        let t = Int((Double(idx) - Double(v.predictedEndTranslation.width / 90)).rounded())
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { ui.albumIndex = max(0, min(hist.count - 1, t)); drag = 0 }
                    })

                let rec = hist[idx]
                let lot = LotLibrary.lot(rec.lotNo)
                let d = Days.date(fromKey: rec.day) ?? Days.now
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(Days.md(d) + " " + Days.weekday(d)).font(Typo.ui(12, .bold)).foregroundColor(p.ink2)
                        Spacer()
                        Text("\(idx + 1) / \(hist.count)").font(Typo.num(12, .semibold)).foregroundColor(p.ink3)
                    }
                    HStack(spacing: 8) {
                        Chip(text: lot.levelText, strong: true)
                        Text(lot.noText + "「" + lot.name + "」").font(Typo.song(17, bold: true)).foregroundColor(p.ink)
                    }
                    Text(lot.poem).font(Typo.song(14)).foregroundColor(p.ink)
                    Text(lot.note).font(Typo.ui(12)).foregroundColor(p.ink2).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        ForEach(0..<LotLibrary.all.count, id: \.self) { i in
                            let got = hist.contains { $0.lotNo == i + 1 }
                            RoundedRectangle(cornerRadius: 2).fill(got ? (p.dark ? p.accent : p.ink) : p.ink3.opacity(0.4)).frame(height: 5)
                        }
                    }
                    .padding(.top, 4)
                    Text(L("签库图鉴：收集全部 24 支")).font(Typo.ui(10.5)).foregroundColor(p.ink3)
                }
                .padding(16)
                .glass(24, depth: 1)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer(minLength: 0)
            }
        }
    }
}
