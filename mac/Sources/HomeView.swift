import SwiftUI

// MARK: - 首页：顶栏（含天气小胶囊）→ 吊牌（布局内，可上拉收起）→ 滚动区 → 底部提醒胶囊（布局内，不遮挡）

struct OldHomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                HomeHeader()
                HangTag()
                Scroller {
                    VStack(spacing: 14) {
                        DateStrip()
                        if ui.selectedDay == Days.todayKey {
                            TodayHero()
                            FortuneCard()
                            TodayLotCard()
                            QuickLinks()
                        } else {
                            OtherDayCard(dayKey: ui.selectedDay)
                        }
                        Text(L("签文原创 · 黄历按传统算法本地推算 · 仅供娱乐参考"))
                            .font(Typo.ui(10.5)).foregroundColor(p.ink3)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                }
                .edgeFade(top: 10, bottom: 16)
                ReminderDock()
            }
            if ui.weatherOpen {
                Color.black.opacity(0.001).onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { ui.weatherOpen = false } }
                WeatherPopover()
                    .padding(.top, 58)
                    .padding(.horizontal, 16)
                    .transition(.scale(scale: 0.92, anchor: .top).combined(with: .opacity))
                    .zIndex(3)
            }
        }
    }
}

// MARK: 顶栏

struct HomeHeader: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @EnvironmentObject var weather: WeatherService
    @Environment(\.pal) private var p
    var body: some View {
        let now = Days.now
        let a = Almanac.of(now)
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Days.md(now) + " " + Days.weekday(now)).font(Typo.ui(18, .heavy)).foregroundColor(p.ink).lineLimit(1)
                Text(I18n.en ? a.lunarFull + " · " + L(a.zodiac) : a.lunarText + " · " + a.yearGZ + "年")
                    .font(Typo.ui(11, .medium)).foregroundColor(p.ink2).lineLimit(1)
            }
            .layoutPriority(1)
            if store.data.settings.weatherOn { WeatherChip() }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                navButton("questionmark.bubble", .ask)
                navButton("checklist", .schedule)
                navButton("note.text", .notes)
                navButton("calendar", .calendar)
                navButton("gearshape", .settings)
            }
            .padding(3)
            .glass(20, depth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private func navButton(_ sym: String, _ page: Page) -> some View {
        Button(action: { ui.go(page) }) {
            Image(systemName: sym)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(p.ink)
                .frame(width: 29, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: 天气小胶囊（顶栏内）+ 弹出详情

struct WeatherChip: View {
    @EnvironmentObject var ui: UIState
    @EnvironmentObject var weather: WeatherService
    @Environment(\.pal) private var p
    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { ui.weatherOpen.toggle() } }) {
            HStack(spacing: 4) {
                Image(systemName: weather.now?.symbol ?? "location.circle")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 12, weight: .semibold))
                Text(weather.now.map { "\(Int($0.temp.rounded()))°" } ?? "--")
                    .font(Typo.num(13, .bold)).foregroundColor(p.ink)
            }
            .padding(.horizontal, 8).frame(height: 28)
            .glass(14, depth: 1)
        }
        .buttonStyle(PressStyle())
    }
}

struct WeatherPopover: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @EnvironmentObject var weather: WeatherService
    @Environment(\.pal) private var p
    @State private var city = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let w = weather.now {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: w.symbol).symbolRenderingMode(.multicolor).font(.system(size: 30))
                        .frame(width: 52, height: 52)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(p.glassFill2))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(Int(w.temp.rounded()))°").font(Typo.num(30, .bold)).foregroundColor(p.ink)
                            Text(L(w.desc)).font(Typo.ui(14, .semibold)).foregroundColor(p.ink)
                        }
                        Text("\(Int(w.low.rounded()))° ~ \(Int(w.high.rounded()))°　" + LF("体感 %d°", Int(w.feels.rounded())))
                            .font(Typo.ui(11.5)).foregroundColor(p.ink2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill").font(.system(size: 9))
                            Text(w.city).font(Typo.ui(12, .semibold))
                        }.foregroundColor(p.ink2)
                        Text(LF("降水 %d%%", w.rain)).font(Typo.ui(11)).foregroundColor(p.ink3)
                    }
                }
                Text(L(w.tip)).font(Typo.ui(12, .semibold)).foregroundColor(p.ink)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(p.glassFill2))
                // 数据来源署名（Open-Meteo 要求，CC BY 4.0）
                Link(destination: URL(string: "https://open-meteo.com/")!) {
                    Text(L("天气数据：Open-Meteo.com")).font(Typo.ui(10)).foregroundColor(p.ink3).underline()
                }
                .buttonStyle(.plain)
            } else {
                Text(L(weather.status.isEmpty ? "正在定位并获取天气…" : weather.status)).font(Typo.ui(12.5)).foregroundColor(p.ink2)
            }
            // 手动输入城市（定位失败或想换城市时）
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .bold)).foregroundColor(p.ink3)
                Field(placeholder: L("换个城市：输入城市名回车"), text: $city, size: 12.5, onSubmit: { weather.search(city) })
                Button(action: {
                    // 点定位 = 回到自动定位（之前手动选过城市也一样），并立刻重新定位
                    store.update { $0.autoLocate = true }
                    weather.locateAndFetch(store: store, force: true)
                }) {
                    Image(systemName: weather.locating ? "location.fill" : "location").font(.system(size: 12, weight: .bold))
                        .foregroundColor(weather.locating ? p.tint : p.ink)
                        .scaleEffect(weather.locating ? 1.15 : 1)
                        .animation(weather.locating ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default, value: weather.locating)
                        .frame(width: 26, height: 26).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 12).frame(height: 36)
            .background(Capsule().fill(p.glassFill2))
            .overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
            if weather.now != nil && !weather.status.isEmpty {
                Text(L(weather.status)).font(Typo.ui(11)).foregroundColor(p.ink2)
            }
            ForEach(weather.results) { c in
                Button(action: {
                    store.update { $0.city = c.name; $0.lat = c.lat; $0.lon = c.lon; $0.autoLocate = false }
                    weather.results = []; city = ""
                    weather.fetch(lat: c.lat, lon: c.lon, city: c.name)
                }) {
                    HStack {
                        Text(c.name).font(Typo.ui(12.5, .semibold)).foregroundColor(p.ink)
                        Text(c.admin).font(Typo.ui(11)).foregroundColor(p.ink2)
                        Spacer()
                        Image(systemName: "checkmark.circle").foregroundColor(p.ink2)
                    }
                }.buttonStyle(.plain)
            }
        }
        .padding(16)
        .glass(24, depth: 2, fill: p.dark ? Color(hex: 0x2A2A2D, alpha: 0.97) : Color.white.opacity(0.97))
    }
}

// MARK: 吊牌（抽完的签挂在顶部；上拉收起成一条，下拉展开 / 再下拉看签）

struct HangTag: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    @State private var dragY: CGFloat = 0

    var body: some View {
        if let lot = store.todayLot {
            let collapsed = store.data.settings.tagCollapsed
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    rope
                    Spacer().frame(width: collapsed ? 150 : 190)
                    rope
                    Spacer()
                }
                .frame(height: collapsed ? 5 : 12)
                Group {
                    if collapsed { slim(lot) } else { full(lot) }
                }
                .offset(y: max(-30, min(30, dragY * 0.35)))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            .offset(y: ui.tagDropped ? 0 : -170)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { v in dragY = v.translation.height }
                    .onEnded { v in
                        let dy = v.translation.height
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                            dragY = 0
                            if dy < -14 { store.update { $0.tagCollapsed = true } }
                            else if dy > 14 {
                                if collapsed { store.update { $0.tagCollapsed = false } } else { ui.lotOpen = true }
                            }
                        }
                    }
            )
            .onTapGesture { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { ui.lotOpen = true } }
        }
    }

    private var rope: some View {
        Rectangle()
            .fill(LinearGradient(colors: [p.ink3.opacity(0.15), p.ink3], startPoint: .top, endPoint: .bottom))
            .frame(width: 1.2)
    }

    private func full(_ lot: Lot) -> some View {
        HStack(spacing: 12) {
            Circle().strokeBorder(p.ink3, lineWidth: 1.5)
                .background(Circle().fill(p.glassFill2))
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(lot.levelText).font(Typo.ui(11, .bold))
                        .foregroundColor(paperInk)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Tone.color(lot.tone)))
                    Text(I18n.en ? lot.noText + " · " + lot.displayName : lot.noText + "「" + lot.name + "」")
                        .font(Typo.song(15, bold: true)).foregroundColor(p.ink).lineLimit(1)
                }
                Text(lot.displayPoemGloss ?? lot.poem).font(I18n.en ? Typo.ui(11.5) : Typo.song(12.5)).foregroundColor(p.ink2).lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Image(systemName: "chevron.compact.up").font(.system(size: 16, weight: .bold))
                Text(L("上拉收起")).font(Typo.ui(9.5, .semibold))
            }
            .foregroundColor(p.ink3)
        }
        .padding(.horizontal, 14)
        .frame(height: 70)
        .glass(20, depth: 2, fill: p.heroTop)
    }

    private func slim(_ lot: Lot) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Tone.deep(lot.tone)).frame(width: 9, height: 9)
            Text(lot.levelText).font(Typo.ui(12, .bold)).foregroundColor(p.ink)
            Text("·").foregroundColor(p.ink3)
            Text(I18n.en ? lot.displayName : lot.noText + "「" + lot.name + "」").font(Typo.song(13, bold: true)).foregroundColor(p.ink).lineLimit(1)
            Spacer()
            Text(L("下拉展开")).font(Typo.ui(10.5, .semibold)).foregroundColor(p.ink2)
            Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).foregroundColor(p.ink2)
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .glass(17, depth: 1)
    }
}

// MARK: 日期条（可看过去/未来；过去的日子可回看当天签）

struct DateStrip: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    private let range = -14...14
    private let cellW: CGFloat = 44
    private let gap: CGFloat = 4

    var body: some View {
        let today = Days.startOfDay(Days.now)
        let row = HStack(spacing: gap) {
            ForEach(Array(range), id: \.self) { off in
                cell(Days.addDays(off, to: today), isToday: off == 0).id(off)
            }
        }
        .padding(.vertical, 6)
        if Snap.active {
            GeometryReader { g in
                let sel = range.first { Days.key(Days.addDays($0, to: today)) == ui.selectedDay } ?? 0
                let idx = CGFloat(sel - range.lowerBound)
                row.fixedSize()
                    .offset(x: g.size.width / 2 - (idx * (cellW + gap) + cellW / 2))
            }
            .frame(height: 76)
            .clipped()
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) { row.padding(.horizontal, 2) }
                    .onAppear { proxy.scrollTo(0, anchor: .center) }
                    .onChange(of: ui.selectedDay) { _ in
                        let off = range.first { Days.key(Days.addDays($0, to: today)) == ui.selectedDay } ?? 0
                        withAnimation { proxy.scrollTo(off, anchor: .center) }
                    }
            }
            .frame(height: 76)
        }
    }

    private func cell(_ d: Date, isToday: Bool) -> some View {
        let key = Days.key(d)
        let sel = key == ui.selectedDay
        let a = Almanac.of(d)
        let past = d < Days.startOfDay(Days.now)
        return Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { ui.selectedDay = key } }) {
            VStack(spacing: 3) {
                Text(isToday ? L("今天") : Days.weekday(d)).font(Typo.ui(10.5, isToday ? .bold : .medium))
                Text("\(Days.cal.component(.day, from: d))").font(Typo.num(17, .bold))
                Text(a.lunarShort).font(Typo.ui(9.5))
                Circle().fill(store.hasRecord(key) ? (sel ? p.onAccent : p.ink2) : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .foregroundColor(sel ? p.onAccent : (past ? p.ink2 : p.ink))
            .frame(width: cellW, height: 68)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(sel ? p.accent : (isToday ? p.glassFill : Color.clear))
            )
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(isToday && !sel ? p.hairline : .clear, lineWidth: 1))
            .shadow(color: sel ? Color.black.opacity(p.dark ? 0.35 : 0.15) : .clear, radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: 今日提醒（第一屏最显眼）

struct TodayHero: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    @State private var draft = ""

    var body: some View {
        let list = store.todayReminders
        let done = list.filter { $0.done }.count
        let pending = list.count - done
        let next = list.first { !$0.done }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LF("今日提醒 · %d/%d 完成", done, list.count)).font(Typo.ui(11.5, .bold)).foregroundColor(p.heroInk2)
                    Text(pending > 0 ? LF("还有 %d 件要做", pending) : L(list.isEmpty ? "今天还没有提醒" : "今天的事都做完了"))
                        .font(Typo.ui(24, .heavy)).foregroundColor(p.heroInk)
                    if let n = next {
                        HStack(spacing: 6) {
                            Text(L("下一件")).foregroundColor(p.heroInk2)
                            Text(n.time.map(Days.hm) ?? "--:--").font(Typo.num(13, .bold)).foregroundColor(p.tint)
                            Text(n.title).foregroundColor(p.heroInk).lineLimit(1)
                        }
                        .font(Typo.ui(13, .medium))
                    } else if list.isEmpty {
                        Text(L("一句话写下要做的事，到点会弹出提醒")).font(Typo.ui(12.5)).foregroundColor(p.heroInk2)
                    }
                }
                Spacer()
                Button(action: { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { ui.composerOpen = true } }) {
                    Image(systemName: "plus").font(.system(size: 18, weight: .bold))
                        .foregroundColor(p.onAccent)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(p.accent))
                        .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 5)
                }
                .buttonStyle(PressStyle())
            }
            if list.isEmpty {
                NewTodoButton()
            } else {
                Collapsible(list) { r in
                    ReminderPill(r: r, ink: p.heroInk, ink2: p.heroInk2, chip: p.heroChip, dotColor: p.heroInk)
                }
            }
        }
        .padding(16)
        .glass(26, depth: 2, fill: p.heroTop)
    }
}

// MARK: 今日签卡（宜做三件 / 避开三件 / 今日一事 / 黄历）

struct TodayLotCard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p

    var body: some View {
        if let lot = store.todayLot {
            let d = Days.date(fromKey: store.qianDay) ?? Days.now
            let a = Almanac.of(d)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    LotFace(lot: lot, date: d, compact: true)
                        .frame(width: 72, height: 104)
                        .shadow(color: Color.black.opacity(p.dark ? 0.4 : 0.1), radius: 8, x: 0, y: 5)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L("今日签")).font(Typo.ui(11.5, .bold)).foregroundColor(p.ink2)
                            Spacer()
                            Button(action: { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { ui.lotOpen = true } }) {
                                HStack(spacing: 2) { Text(L("看签")); Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)) }
                                    .font(Typo.ui(12, .bold)).foregroundColor(p.tint)
                            }.buttonStyle(.plain)
                        }
                        Text(lot.poem).font(Typo.song(14.5, bold: true)).foregroundColor(p.ink).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        if let g = lot.displayPoemGloss {
                            Text(g).font(Typo.ui(11, .medium)).italic().foregroundColor(p.ink2).fixedSize(horizontal: false, vertical: true)
                        }
                        Text(lot.displayNote).font(Typo.ui(12)).foregroundColor(p.ink2).lineSpacing(2).lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    column(L("宜做三件"), lot.displayTodo, sym: "checkmark.circle.fill", strong: true)
                    column(L("避开三件"), lot.displayAvoid, sym: "minus.circle", strong: false)
                }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles").font(.system(size: 12, weight: .bold)).foregroundColor(p.tint)
                    Text(L("今日一事：") + lot.displayOne).font(Typo.ui(12, .medium)).foregroundColor(p.ink).fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.glassFill2))

                Rectangle().fill(p.hairline).frame(height: 1)

                HStack {
                    Text(L("黄历") + " · " + a.officerDisplay + " · " + a.dayGZ).font(Typo.ui(11.5, .bold)).foregroundColor(p.ink2)
                    Spacer()
                    Button(action: { ui.go(.pickDay) }) {
                        HStack(spacing: 2) { Text(L("择日")); Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)) }
                            .font(Typo.ui(12, .bold)).foregroundColor(p.tint)
                    }.buttonStyle(.plain)
                }
                YiJiChips(a: a)
            }
            .padding(16)
            .glass(24, depth: 1)
        }
    }

    private func column(_ title: String, _ items: [String], sym: String, strong: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(Typo.ui(11, .bold)).foregroundColor(p.ink2)
            ForEach(items, id: \.self) { s in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: sym).font(.system(size: 11, weight: .bold))
                        .foregroundColor(strong ? p.ink : p.ink3)
                        .padding(.top, 1.5)
                    Text(s).font(Typo.ui(12, .medium)).foregroundColor(strong ? p.ink : p.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(p.glassFill2))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(p.hairline, lineWidth: 1))
    }
}

struct YiJiChips: View {
    @Environment(\.pal) private var p
    let a: DayAlmanac
    var prefix: String? = nil
    var body: some View {
        FlowLayout(spacing: 6) {
            Text((prefix.map { $0 + " " } ?? "") + L("宜")).font(Typo.ui(11.5, .heavy)).foregroundColor(p.ink).padding(.vertical, 5)
            ForEach(a.yi, id: \.self) { Chip(text: $0, strong: true) }
            Text(L("忌")).font(Typo.ui(11.5, .heavy)).foregroundColor(p.ink2).padding(.vertical, 5).padding(.leading, 4)
            ForEach(a.ji, id: \.self) { Chip(text: $0) }
        }
    }
}

// MARK: 快捷入口

struct QuickLinks: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    var body: some View {
        HStack(spacing: 10) {
            tile("mountain.2", L("问山人"), L("问今天的一件事"), .ask)
            tile("calendar.badge.checkmark", L("择日"), L("挑最宜的一天"), .pickDay)
            tile("rectangle.stack", L("签册"), LF("已收 %d 支", store.data.draws.count), .album)
        }
    }
    private func tile(_ sym: String, _ title: String, _ sub: String, _ page: Page) -> some View {
        Button(action: { ui.go(page) }) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: sym).font(.system(size: 14, weight: .semibold))
                    .foregroundColor(p.ink)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(p.glassFill2))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Typo.ui(13, .bold)).foregroundColor(p.ink)
                    Text(sub).font(Typo.ui(10.5)).foregroundColor(p.ink2).lineLimit(1)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(20, depth: 1)
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: 其他日子（过去可回看当天签，未来看黄历）

struct OtherDayCard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    let dayKey: String
    var body: some View {
        let d = Days.date(fromKey: dayKey) ?? Days.now
        let a = Almanac.of(d)
        let list = store.reminders(on: dayKey)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Days.relative(d)).font(Typo.ui(20, .heavy)).foregroundColor(p.ink)
                    Text(Days.md(d) + " " + Days.weekday(d) + " · " + a.lunarFull).font(Typo.ui(11.5)).foregroundColor(p.ink2)
                }
                Spacer()
                Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { ui.selectedDay = Days.todayKey } }) {
                    Text(L("回到今天")).font(Typo.ui(12, .bold)).foregroundColor(p.onAccent)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(p.accent))
                }.buttonStyle(PressStyle())
            }
            if let lot = store.lot(forDay: dayKey) {
                HStack(alignment: .top, spacing: 12) {
                    LotFace(lot: lot, date: d, compact: true).frame(width: 84, height: 120)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("那天的签") + " · " + lot.levelText).font(Typo.ui(11.5, .bold)).foregroundColor(p.ink2)
                        Text(lot.poem).font(Typo.song(14.5, bold: true)).foregroundColor(p.ink).fixedSize(horizontal: false, vertical: true)
                        Text(lot.displayNote).font(Typo.ui(12)).foregroundColor(p.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else if d < Days.startOfDay(Days.now) {
                Text(L("那天没有抽签")).font(Typo.ui(12.5)).foregroundColor(p.ink2)
            }
            YiJiChips(a: a, prefix: a.officerDisplay)
            if !list.isEmpty {
                Rectangle().fill(p.hairline).frame(height: 1)
                Text(L("那天的日程")).font(Typo.ui(11.5, .bold)).foregroundColor(p.ink2)
                VStack(spacing: 7) {
                    Collapsible(list) { r in
                        ReminderPill(r: r, ink: p.ink, ink2: p.ink2, chip: p.glassFill2, dotColor: p.ink)
                    }
                }
            }
        }
        .padding(16)
        .glass(24, depth: 1)
    }
}

// MARK: 底部提醒胶囊栏（像解锁条；在布局内，永远不挡内容）

struct ReminderDock: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p

    var body: some View {
        let list = store.todayReminders
        let pending = list.filter { !$0.done }
        let next = pending.first
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                if list.isEmpty {
                    Circle().strokeBorder(p.ink3, lineWidth: 1.5).frame(width: 9, height: 9)
                } else {
                    ForEach(list.prefix(5)) { r in
                        ZStack {
                            Circle().strokeBorder(r.done ? p.ink : p.ink2, lineWidth: 1.5)
                            if r.done { Circle().fill(p.ink) }
                        }
                        .frame(width: 9, height: 9)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(L("提醒事项")).font(Typo.ui(13, .bold)).foregroundColor(p.ink)
                Group {
                    if list.isEmpty { Text(L("今天没有提醒 · 点开添加")) }
                    else if let n = next { Text(LF("%d 项待办", pending.count) + " · " + (n.time.map(Days.hm) ?? "") + " " + n.title) }
                    else { Text(L("全部完成，干得漂亮")) }
                }
                .font(Typo.ui(11)).foregroundColor(p.ink2).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(p.onAccent)
                .frame(width: 40, height: 40)
                .background(Circle().fill(p.accent))
                .shadow(color: Color.black.opacity(p.dark ? 0.4 : 0.2), radius: 8, x: 0, y: 4)
        }
        .padding(.leading, 18).padding(.trailing, 7)
        .frame(height: 54)
        .background(LiquidCapsule())
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .contentShape(Rectangle())
        .onTapGesture { open() }
        .gesture(DragGesture(minimumDistance: 8).onEnded { v in if v.translation.height < -10 { open() } })
    }

    private func open() { withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { ui.dockOpen = true } }
}

/// 液态玻璃胶囊：底色 + 顶部强高光 + 底部反光 + 双层描边 + 双阴影
struct LiquidCapsule: View {
    @Environment(\.pal) private var p
    var body: some View {
        ZStack {
            Capsule().fill(p.dark ? Color.white.opacity(0.10) : Color.white.opacity(0.78))
            Capsule().fill(LinearGradient(colors: [Color.white.opacity(p.dark ? 0.16 : 0.9), .clear], startPoint: .top, endPoint: .center))
                .padding(1.5)
            Capsule().fill(LinearGradient(colors: [.clear, Color.white.opacity(p.dark ? 0.05 : 0.4)], startPoint: .center, endPoint: .bottom))
            Capsule().strokeBorder(LinearGradient(colors: [Color.white.opacity(p.dark ? 0.32 : 1), Color.white.opacity(p.dark ? 0.04 : 0.5)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            Capsule().strokeBorder(Color.black.opacity(p.dark ? 0.35 : 0.05), lineWidth: 0.5).padding(-0.5)
        }
        .shadow(color: Color.black.opacity(p.dark ? 0.5 : 0.08), radius: 2, x: 0, y: 1)
        .shadow(color: p.shadow, radius: 22, x: 0, y: 12)
    }
}

// MARK: 提醒面板（胶囊栏展开）

struct DockPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    @State private var draft = ""

    var body: some View {
        let list = store.todayReminders
        let done = list.filter { $0.done }.count
        VStack(alignment: .leading, spacing: 12) {
            Capsule().fill(p.ink3).frame(width: 40, height: 5).frame(maxWidth: .infinity)
            HStack(alignment: .firstTextBaseline) {
                Text(L("今日提醒")).font(Typo.ui(22, .heavy)).foregroundColor(p.ink)
                Text("\(done)/\(list.count)").font(Typo.num(15, .bold)).foregroundColor(p.ink2)
                Spacer()
                Button(action: close) {
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold))
                        .foregroundColor(p.onAccent)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(p.accent))
                }.buttonStyle(PressStyle())
            }
            Text(L("点一下切换：实心 = 已做，空心 = 未做")).font(Typo.ui(11)).foregroundColor(p.ink2)
            Scroller {
                VStack(spacing: 7) {
                    if list.isEmpty {
                        Text(L("今天还没有提醒")).font(Typo.ui(13)).foregroundColor(p.ink2).padding(.vertical, 20)
                    }
                    Collapsible(list) { r in
                        ReminderPill(r: r, ink: p.ink, ink2: p.ink2, chip: p.glassFill2, dotColor: p.ink)
                    }
                }
            }
            .frame(maxHeight: 210)
            NewTodoButton()
            HStack(spacing: 8) {
                panelButton(L("全部日程"), "list.bullet") { ui.go(.schedule) }
                panelButton(L("择日"), "calendar.badge.checkmark") { ui.go(.pickDay) }
            }
        }
        .padding(18)
        .glass(30, depth: 2, fill: p.dark ? Color(hex: 0x2A2A2D, alpha: 0.96) : Color.white.opacity(0.96))
        .padding(10)
    }

    private func panelButton(_ title: String, _ sym: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 6) {
                Image(systemName: sym).font(.system(size: 12, weight: .bold))
                Text(title).font(Typo.ui(12.5, .bold))
            }
            .foregroundColor(p.ink)
            .frame(maxWidth: .infinity).frame(height: 38)
            .background(Capsule().fill(p.glassFill2))
        }.buttonStyle(PressStyle())
    }

    private func close() { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { ui.dockOpen = false } }
}
