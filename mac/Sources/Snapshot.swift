import AppKit
import SwiftUI

// MARK: - 截图模式：今日签.app/Contents/MacOS/JinRiQian --snapshots <输出目录>
// 用演示数据把每个界面在浅色、深色下各渲染一张 PNG（不读写用户真实数据）。

enum SnapshotRunner {
    struct Scene {
        let name: String
        let configure: (Store, UIState, WeatherService) -> Void
    }

    static func demoData(now: Date) -> AppData {
        var d = AppData()
        d.userSeed = "demo-seed-2026"
        let today = Days.startOfDay(now)
        func at(_ day: Date, _ h: Int, _ m: Int) -> Date { Days.cal.date(bySettingHour: h, minute: m, second: 0, of: day)! }
        let qd = Days.qianDay(at: now)
        // 过去的签
        for off in 1...9 {
            let day = Days.key(Days.addDays(-off, to: today))
            d.draws[day] = DrawRecord(day: day, lotNo: Draw.lotNo(seed: d.userSeed, day: day, index: 300 + off), pick: 300 + off, at: at(Days.addDays(-off, to: today), 9, 0))
        }
        d.draws[qd] = DrawRecord(day: qd, lotNo: Draw.lotNo(seed: d.userSeed, day: qd, index: 387), pick: 387, at: at(today, 8, 32))

        let t = Days.key(today)
        var r1 = Reminder(title: "周会", day: t, time: at(today, 10, 0)); r1.done = true
        let r2 = Reminder(title: "取快递", day: t, time: at(today, 18, 30))
        let r3 = Reminder(title: "给妈妈打电话", day: t, time: at(today, 20, 30))
        var r0 = Reminder(title: "喝一杯温水", day: t, time: at(today, 9, 30)); r0.done = true
        let tm = Days.addDays(1, to: today)
        let r4 = Reminder(title: "体检", day: Days.key(tm), time: at(tm, 9, 0))
        let r5 = Reminder(title: "交季度报告", day: Days.key(tm), time: at(tm, 15, 0))
        let d3 = Days.addDays(3, to: today)
        let r6 = Reminder(title: "和老同学聚餐", day: Days.key(d3), time: at(d3, 19, 0))
        // 找一个忌出行的日子放出差，演示“撞忌日换日”
        var clashDay = Days.addDays(5, to: today)
        for i in 2...12 where Almanac.of(Days.addDays(i, to: today)).ji.contains("出行") { clashDay = Days.addDays(i, to: today); break }
        let r7 = Reminder(title: "出差去杭州", day: Days.key(clashDay), time: at(clashDay, 8, 0))
        var old = Reminder(title: "整理书桌", day: Days.key(Days.addDays(-1, to: today)), time: nil); old.done = true
        d.reminders = [r0, r1, r2, r3, r4, r5, r6, r7, old]

        let notes: [(String, Int)] = [
            ("想做一个只属于自己的晨间仪式：一杯温水、一支签、一件小事。", 0),
            ("周末去看银杏，顺路买一束花。", 1),
            ("读完《置身事内》第三章，记三条笔记。", 2),
            ("今天被同事夸了一句，开心。", 3),
            ("年底前把旧照片整理成一本相册。", 4),
            ("少说一句反驳的话，多问一句为什么。", 5),
        ]
        d.notes = notes.enumerated().map { i, n in
            var note = Note(text: n.0, tone: n.1, day: Days.key(Days.addDays(-i, to: today)))
            if i == 0 { note.review = "坚持了一周，早上确实更从容了。" }
            return note
        }
        d.settings.city = "上海"
        d.settings.birthOn = true
        d.settings.birthDate = Days.cal.date(from: DateComponents(year: 1996, month: 3, day: 8, hour: 12))
        d.settings.birthHour = 10
        d.settings.lat = 31.23
        d.settings.lon = 121.47
        return d
    }

    static var scenes: [Scene] {
        let wx: (Store, WeatherService) -> Void = { s, w in
            s.data.settings.weatherOn = true
            w.now = WeatherNow(temp: 14, feels: 13, code: 1, high: 19, low: 10, rain: 20, city: "上海")
        }
        return [
            Scene(name: "00-新用户-先报生辰") { s, _, _ in s.data.settings.birthOn = false; s.data.draws[s.qianDay] = nil },
            Scene(name: "01-向山人求签") { s, u, _ in s.data.draws[s.qianDay] = nil; u.drawIndex = 386 },
            Scene(name: "02-抽出一张") { s, u, _ in s.data.draws[s.qianDay] = nil; u.drawIndex = 387; u.drawPulled = true; u.drawAngle = 0 },
            Scene(name: "03-翻开签文") { s, u, _ in s.data.draws[s.qianDay] = nil; u.drawIndex = 387; u.drawPulled = true; u.drawFlipped = true },
            Scene(name: "04-首页-时辰轮") { s, _, w in wx(s, w) },
            Scene(name: "05-首页-拨到傍晚") { s, u, w in wx(s, w); u.probeMinutes = 17 * 60 + 40 },
            Scene(name: "06-首页-拨到冲时") { s, u, w in
                wx(s, w)
                let r = Fortune.reading(for: Days.now, birth: s.data.settings.birthDate, birthHour: s.data.settings.birthHour)
                let slot = r.slots.first { $0.personalClash } ?? r.slots.first { !$0.good }!
                u.probeMinutes = (slot.start * 60 + 30) % 1440
            },
            Scene(name: "07-首页-翻到前天") { s, u, w in wx(s, w); u.dialDay = -2 },
            Scene(name: "08-首页-翻到明天") { s, u, w in wx(s, w); u.dialDay = 1 },
            Scene(name: "09-万年历-老黄历") { _, u, _ in u.page = .calendar },
            Scene(name: "09b-万年历-老黄历-下半") { _, u, _ in u.page = .calendar; Snap.scroll = 330 },
            Scene(name: "10-看签") { _, u, _ in u.lotOpen = true },
            Scene(name: "10b-看签-命理总批") { _, u, _ in u.lotOpen = true; Snap.scroll = 470 },
            Scene(name: "11-山人细说") { _, u, _ in u.page = .fortune },
            Scene(name: "12-山人细说-下半") { _, u, _ in u.page = .fortune; Snap.scroll = 520 },
            Scene(name: "13-问山人-空") { s, u, _ in s.data.chat = []; u.chatOpen = true },
            Scene(name: "14-问山人-择日") { s, u, _ in
                let q1 = "按照我的生辰八字，今年适合结婚的日子有哪些？"
                let q2 = "下午3点去打麻将可以吗？"
                s.data.chat = [ChatMsg(fromUser: true, text: q1), ChatMsg(fromUser: false, text: HermitBrain.localAnswer(q1, s.data.settings), local: true),
                               ChatMsg(fromUser: true, text: q2), ChatMsg(fromUser: false, text: HermitBrain.localAnswer(q2, s.data.settings), local: true)]
                u.chatOpen = true
            },
            Scene(name: "15-问山人-只看择日") { s, u, _ in
                let q1 = "按照我的生辰八字，今年适合结婚的日子有哪些？"
                s.data.chat = [ChatMsg(fromUser: true, text: q1), ChatMsg(fromUser: false, text: HermitBrain.localAnswer(q1, s.data.settings), local: true)]
                u.chatOpen = true
            },
            Scene(name: "16-侧栏-拨签条") { _, u, _ in u.railLotDrag = -34 },
            Scene(name: "17-天气") { s, u, w in
                s.data.settings.weatherOn = true; u.weatherOpen = true
                w.now = WeatherNow(temp: 14, feels: 13, code: 1, high: 19, low: 10, rain: 20, city: "上海")
            },
            Scene(name: "18-今日提醒-盖印") { _, u, _ in u.dockOpen = true },
            Scene(name: "19-新建待办") { _, u, _ in u.composerOpen = true },
            Scene(name: "20-日程") { _, u, _ in u.page = .schedule },
            Scene(name: "21-择日") { _, u, _ in u.page = .pickDay; u.pickAct = "搬家" },
            Scene(name: "22-设置-命盘") { _, u, _ in u.page = .settings; Snap.scroll = 300 },
            Scene(name: "22b-设置-AI三步接入") { s, u, _ in
                u.page = .settings
                s.data.settings.aiOn = true; s.data.settings.aiVerified = true; s.data.settings.aiProvider = "deepseek"
                s.data.settings.aiEndpoint = "https://api.deepseek.com"; s.data.settings.aiModel = "deepseek-flash"
                Snap.scroll = 560
            },
            Scene(name: "23-到点弹窗") { _, _, _ in },
            Scene(name: "24-分享今日签") { _, u, _ in u.shareOpen = true },
        ]
    }

    @MainActor
    static func run(outDir: String) {
        Snap.active = true
        let now = Days.cal.date(bySettingHour: 11, minute: 20, second: 0, of: Date())!
        Days.nowOverride = now
        let dir = URL(fileURLWithPath: outDir, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let english: Set<String> = ["00-新用户-先报生辰", "10b-看签-命理总批", "09-万年历-老黄历", "01-向山人求签", "04-首页-时辰轮", "05-首页-拨到傍晚", "11-山人细说", "14-问山人-择日", "16-侧栏-拨签条", "18-今日提醒-盖印"]
        gallery(outDir: dir, now: now)
        let runs: [(ColorScheme, String, Lang)] = [(.light, "浅色", .zh), (.dark, "深色", .zh), (.light, "英文-浅色", .en), (.dark, "英文-深色", .en)]
        for (scheme, tag, lang) in runs {
            for sc in scenes {
                if lang == .en && !english.contains(sc.name) { continue }
                Snap.scroll = 0
                var demo = demoData(now: now)
                demo.settings.language = lang
                let store = Store(persist: false, data: demo)
                let ui = UIState()
                ui.selectedDay = Days.todayKey
                ui.calMonth = now
                let weather = WeatherService()
                sc.configure(store, ui, weather)
                let isAlert = sc.name == "23-到点弹窗"
                let view = canvas(scheme: scheme) {
                    ZStack(alignment: .top) {
                        RootView(forcedScheme: scheme, translucent: true)
                            .environmentObject(store)
                            .environmentObject(ui)
                            .environmentObject(weather)
                            .blur(radius: isAlert ? 2 : 0)
                            .opacity(isAlert ? 0.7 : 1)
                        if isAlert {
                            PaletteProvider {
                                AlertCard(item: AlertItem(id: UUID(), title: "取快递", time: Days.cal.date(bySettingHour: 18, minute: 30, second: 0, of: now)!, isFocus: false),
                                          onDone: {}, onSnooze: {}, onClose: {})
                            }
                            .environment(\.colorScheme, scheme)
                            .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 16)
                            .padding(.top, 40)
                        }
                    }
                }
                let r = ImageRenderer(content: view)
                r.scale = 2
                guard let img = r.nsImage, let tiff = img.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else {
                    print("render failed: \(sc.name)"); continue
                }
                let url = dir.appendingPathComponent("\(sc.name)-\(tag).png")
                try? png.write(to: url)
                print("ok \(url.lastPathComponent)")
            }
        }
    }

    /// 签图一览：24 支签的牌面拼成一张图，方便检查每张是否都不一样
    @MainActor
    static func gallery(outDir: URL, now: Date) {
        let picks = (0..<24).map { 1 + ($0 * 11 + $0 / 3) % 88 }
        let v = PaletteProvider {
            VStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 14) {
                        ForEach(0..<6, id: \.self) { c in
                            MysticFace(lot: LotLibrary.lot(picks[row * 6 + c]), date: now).frame(width: 150, height: 244)
                        }
                    }
                }
            }
            .padding(24)
            .background(Color(hex: 0x16161A))
        }
        .environment(\.colorScheme, .dark)
        let r = ImageRenderer(content: v)
        r.scale = 2
        if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: outDir.appendingPathComponent("40-签图一览.png"))
            print("ok 40-签图一览.png")
        }
    }

    /// 截图画布：面板放在柔和的桌面色上，带投影
    static func canvas<V: View>(scheme: ColorScheme, @ViewBuilder _ v: () -> V) -> some View {
        let dark = scheme == .dark
        // 模拟 macOS 桌面：面板半透明，透出后面被柔化的桌面
        return ZStack {
            LinearGradient(colors: dark ? [Color(hex: 0x2C2C30), Color(hex: 0x0E0E10)] : [Color(hex: 0xE4E6EB), Color(hex: 0xF4F4F6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(RadialGradient(colors: [Color(hex: dark ? 0x5A6378 : 0xB9C3D6).opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 240))
                .frame(width: 480, height: 480).offset(x: 150, y: -200)
            Circle().fill(RadialGradient(colors: [Color(hex: dark ? 0x3E3E46 : 0xFFFFFF).opacity(0.8), .clear], center: .center, startRadius: 0, endRadius: 220))
                .frame(width: 440, height: 440).offset(x: -170, y: 220)
            v()
                .shadow(color: Color.black.opacity(dark ? 0.6 : 0.18), radius: 30, x: 0, y: 18)
        }
        .frame(width: panelSize.width + 60, height: panelSize.height + 60)
        .environment(\.colorScheme, scheme)
    }
}
