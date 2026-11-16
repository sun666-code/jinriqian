import SwiftUI
import AppKit
import Combine

// MARK: - 演示自动播放（只在 --demo 启动时生效，平时完全不参与）
// 用真实界面按剧本自己走一遍：先报生辰 → 抽签 → 时辰轮 → 侧栏 → 接入 AI → 问山人。
// 光标、点击波纹、镜头推近都在后期按这里记下的事件画上去，所以界面里不画假光标。
// 演示数据放在单独的「今日签-演示」文件夹，不碰你自己的数据；钥匙串只读不写。

enum Demo {
    static var active = false
    static var lang = "zh"
    static var outDir = URL(fileURLWithPath: NSTemporaryDirectory())
    static var hiddenByDemo: Set<pid_t> = []
}

enum DemoCmd {
    case text(String, String)   // 给某个输入框填字
    case act(String)            // 触发某个按钮
    case scroll(String)         // 滚动到某处
}

final class DemoBus {
    static let shared = DemoBus()
    var frames: [String: CGRect] = [:]
    let cmd = PassthroughSubject<DemoCmd, Never>()
}

// 记录界面元素在面板里的位置（演示时光标要移过去）
struct DemoTarget: ViewModifier {
    let id: String
    func body(content: Content) -> some View {
        if Demo.active {
            content.background(GeometryReader { g in
                let f = g.frame(in: .named("demoRoot"))
                Color.clear
                    .onAppear { DemoBus.shared.frames[id] = f }
                    .onChange(of: f) { DemoBus.shared.frames[id] = $0 }
            })
        } else {
            content
        }
    }
}

extension View {
    func demoTarget(_ id: String) -> some View { modifier(DemoTarget(id: id)) }

    /// 收到演示指令时执行（平时不挂任何东西）
    @ViewBuilder
    func onDemo(_ handle: @escaping (DemoCmd) -> Void) -> some View {
        if Demo.active { onReceive(DemoBus.shared.cmd.receive(on: RunLoop.main)) { handle($0) } } else { self }
    }
}

// MARK: - 同步闪块：开演那一刻在屏幕左下角闪一下白，后期用来对齐时间

final class DemoStage: ObservableObject {
    static let shared = DemoStage()
    @Published var flash = false
}

struct DemoFlashView: View {
    @ObservedObject var stage = DemoStage.shared
    var body: some View { Rectangle().fill(stage.flash ? Color.white : Color.black).ignoresSafeArea() }
}

// MARK: - 剧本

@MainActor
final class DemoDirector {
    let store: Store
    let ui: UIState
    private var t0: CFTimeInterval = 0
    private var events: [[String: Any]] = []
    private var cursor = CGPoint(x: 0, y: 0)
    private let zh: Bool

    /// 打开面板（和点菜单栏图标一样）
    var openPanel: () -> Void = {}
    /// 菜单栏图标在屏幕上的位置（左上角为原点）
    var statusPoint: () -> CGPoint = { .zero }
    /// 面板左上角在屏幕上的位置
    var panelOrigin: () -> CGPoint = { .zero }
    var screenSize: CGSize = .zero

    init(store: Store, ui: UIState) {
        self.store = store; self.ui = ui
        zh = Demo.lang != "en"
    }

    private var now: Double { CACurrentMediaTime() - t0 }

    private func log(_ type: String, _ extra: [String: Any] = [:]) {
        var e = extra
        e["type"] = type
        e["t"] = (now * 1000).rounded() / 1000
        events.append(e)
    }

    private func pause(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }

    private func center(_ id: String) -> CGPoint? {
        guard let f = DemoBus.shared.frames[id] else { NSLog("demo: no frame for \(id)"); return nil }
        let o = panelOrigin()
        return CGPoint(x: o.x + f.midX, y: o.y + f.midY)
    }

    private func spring(_ f: () -> Void) { withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { f() } }

    /// 光标平滑移到某处
    private func move(to p: CGPoint, _ dur: Double = 0.7) async {
        log("move", ["x0": cursor.x, "y0": cursor.y, "x": p.x, "y": p.y, "dur": dur])
        cursor = p
        await pause(dur)
    }

    private func move(_ id: String, _ dur: Double = 0.7, dx: CGFloat = 0, dy: CGFloat = 0) async {
        guard let c = center(id) else { return }
        await move(to: CGPoint(x: c.x + dx, y: c.y + dy), dur)
    }

    /// 移过去 → 按下 → 执行
    private func click(_ id: String, dur: Double = 0.7, dx: CGFloat = 0, dy: CGFloat = 0, after: Double = 0.5, _ act: () -> Void) async {
        await move(id, dur, dx: dx, dy: dy)
        await pause(0.12)
        log("click", ["x": cursor.x, "y": cursor.y, "id": id])
        await pause(0.08)
        act()
        await pause(after)
    }

    private func scene(_ id: String) { log("scene", ["id": id]) }

    /// 逐字打字
    private func type(_ id: String, _ text: String, speed: Double = 0.085) async {
        var s = ""
        for ch in text {
            s.append(ch)
            DemoBus.shared.cmd.send(.text(id, s))
            log("key")
            await pause(speed * Double.random(in: 0.7...1.3))
        }
    }

    // MARK: 开演

    /// 先激活自己，再把别的应用都藏起来（不激活时系统可能不理会）
    private func clearDesktop() async {
        for _ in 0..<3 {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.hideOtherApplications(nil)
            for a in NSWorkspace.shared.runningApplications where a.activationPolicy == .regular && a != NSRunningApplication.current && !a.isHidden {
                _ = a.hide()
            }
            await pause(0.6)
            let vis = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0 != NSRunningApplication.current && !$0.isHidden }
            if vis.isEmpty { break }
        }
    }

    func run() async {
        await clearDesktop()
        let still = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0 != NSRunningApplication.current && !$0.isHidden }.map { $0.localizedName ?? "?" }
        t0 = CACurrentMediaTime()
        log("visible", ["apps": still])
        DemoStage.shared.flash = true
        log("sync")
        await pause(0.4)
        DemoStage.shared.flash = false
        cursor = CGPoint(x: screenSize.width * 0.5, y: screenSize.height * 0.55)
        log("pos", ["x": cursor.x, "y": cursor.y])
        scene("desktop")
        await pause(2.2)
        // 从桌面点菜单栏图标打开
        await move(to: statusPoint(), 1.5)
        await pause(0.15)
        log("click", ["x": cursor.x, "y": cursor.y, "id": "status"])
        openPanel()
        await pause(0.3)
        let po = panelOrigin()
        log("panel", ["x": po.x, "y": po.y, "w": panelSize.width, "h": panelSize.height])
        await pause(0.9)

        await birth()
        await draw()
        await home()
        await rail()
        await aiConnect()
        await chat()
        await appearance()

        scene("end")
        let pe = panelOrigin()
        await move(to: CGPoint(x: pe.x + 470, y: pe.y + 600), 1.0)
        await pause(1.5)
        log("end")
        finish()
    }

    // 1. 新用户：先报生辰
    private func birth() async {
        scene("birth")
        await pause(1.6)
        await move("birth.y", 0.9)
        log("click", ["x": cursor.x, "y": cursor.y, "id": "wheel"])
        for (id, v) in [("birth.y", "56"), ("birth.m", "7"), ("birth.d", "17"), ("birth.h", "4")] {
            await move(id, 0.45)
            DemoBus.shared.cmd.send(.text(id, v))
            log("wheel")
            await pause(0.7)
        }
        await pause(0.6)
        await click("birth.save", after: 1.6) {
            DemoBus.shared.cmd.send(.act("birth.save"))
        }
    }

    // 2. 抽签：拨牌 → 点中间 → 翻开
    private func draw() async {
        scene("draw")
        await pause(1.4)
        guard let fc = center("draw.fan") else { return }
        let c = CGPoint(x: fc.x, y: fc.y + 40)
        await move(to: c, 0.8)
        // 往左拨三下、往右拨一下
        for (sgn, n) in [(-1.0, 3), (-1.0, 2), (1.0, 4), (-1.0, 1)] {
            log("down", ["x": cursor.x, "y": cursor.y])
            let steps = 18
            for i in 1...steps {
                let k = Double(i) / Double(steps)
                let e = 1 - pow(1 - k, 2)
                ui.drawDrag = CGFloat(sgn * Double(n) * 0.9 * e)
                cursor = CGPoint(x: c.x + CGFloat(sgn * Double(n) * 0.9 * 64 * e), y: c.y)
                log("pos", ["x": cursor.x, "y": cursor.y])
                await pause(0.022)
            }
            log("up", ["x": cursor.x, "y": cursor.y])
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) { ui.drawIndex -= Int(sgn) * n; ui.drawDrag = 0 }
            log("swipe")
            await move(to: c, 0.35)
            await pause(0.5)
        }
        await pause(0.4)
        // 点正中那张
        await click("draw.fan", dy: 10, after: 0.1) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { ui.drawPulled = true }
        }
        log("pull")
        await pause(0.7)
        withAnimation(.easeIn(duration: 0.25)) { ui.drawAngle = 90 }
        await pause(0.25)
        ui.drawFlipped = true
        ui.drawAngle = -90
        log("flip")
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { ui.drawAngle = 0 }
        let po = panelOrigin()
        await move(to: CGPoint(x: po.x + 330, y: po.y + 640), 1.2)
        await pause(3.4)
        await click("draw.take", after: 2.0) {
            DemoBus.shared.cmd.send(.act("draw.take"))
        }
    }

    // 3. 首页：时辰轮
    private func home() async {
        scene("dial")
        await pause(1.0)
        // 悬停在签上
        await move("dial.center", 0.9)
        DemoBus.shared.cmd.send(.act("dial.hover"))
        await pause(1.2)
        DemoBus.shared.cmd.send(.act("dial.unhover"))
        // 沿着时辰轮转一圈看吉凶
        if let c = center("home.dial") {
            let nowM = DialMath.minuteOfDay(Days.now)
            let r: CGFloat = 104
            await move(to: DialMath.point(Double(nowM), radius: r, center: c), 0.6)
            log("down", ["x": cursor.x, "y": cursor.y])
            scene("probe")
            let total = 540, steps = 140
            for i in 0...steps {
                let k = Double(i) / Double(steps)
                let e = k < 0.5 ? 2 * k * k : 1 - pow(-2 * k + 2, 2) / 2
                let m = nowM + Int(Double(total) * e)
                ui.probeMinutes = ((m % 1440) + 1440) % 1440
                cursor = DialMath.point(Double(m), radius: r, center: c)
                log("pos", ["x": cursor.x, "y": cursor.y])
                await pause(0.03)
            }
            log("up", ["x": cursor.x, "y": cursor.y])
            await pause(1.8)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { ui.probeMinutes = nil }
            await pause(0.5)
        }
        // 明天、后天
        scene("days")
        await click("home.arrowR", after: 1.0) { spring { ui.dialDay = 1; ui.probeMinutes = nil } }
        // 连点：快速往后翻几天
        for d in 2...5 {
            await click("home.arrowR", dur: 0.08, after: 0.32) { spring { ui.dialDay = d } }
        }
        await pause(0.9)
        // 再快速翻回来
        for d in stride(from: 4, through: 0, by: -1) {
            await click("home.arrowL", dur: d == 4 ? 0.7 : 0.08, after: 0.3) { spring { ui.dialDay = d } }
        }
        await pause(1.0)
        // 黄历
        scene("calendar")
        await click("home.date", after: 2.6) { ui.selectedDay = Days.todayKey; ui.calMonth = Days.now; ui.go(.calendar) }
        await click("page.close", after: 0.9) { ui.go(.home) }
        // 点中间的签：翻看今日签 + 命盘
        scene("lot")
        await click("dial.center", after: 2.6) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { ui.lotOpen = true }
        }
        DemoBus.shared.cmd.send(.scroll("lot.reading"))
        log("scroll")
        await pause(3.0)
        await click("lot.close", after: 0.9) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { ui.lotOpen = false }
        }
    }

    // 4. 侧栏：签条、记事、天气
    private func rail() async {
        scene("strip")
        await move("rail.strip", 0.8)
        log("down", ["x": cursor.x, "y": cursor.y])
        DemoBus.shared.cmd.send(.act("strip.fling"))
        let s0 = cursor
        for i in 1...12 { cursor = CGPoint(x: s0.x, y: s0.y - CGFloat(i) * 5); log("pos", ["x": cursor.x, "y": cursor.y]); await pause(0.016) }
        log("up", ["x": cursor.x, "y": cursor.y])
        log("swipe")
        await pause(2.0)
        log("down", ["x": cursor.x, "y": cursor.y])
        DemoBus.shared.cmd.send(.act("strip.fling"))
        let s1 = cursor
        for i in 1...12 { cursor = CGPoint(x: s1.x, y: s1.y - CGFloat(i) * 5); log("pos", ["x": cursor.x, "y": cursor.y]); await pause(0.016) }
        log("up", ["x": cursor.x, "y": cursor.y])
        log("swipe")
        await pause(2.4)

        if store.data.settings.weatherOn {
            scene("weather")
            await click("rail.weather", after: 2.4) { spring { ui.weatherOpen = true } }
            await click("rail.weather", after: 0.6) { spring { ui.weatherOpen = false } }
        }

        scene("todo")
        await click("rail.plus", after: 0.9) { ui.scheduleDraft = ""; spring { ui.composerOpen = true } }
        await move("composer.title", 0.6)
        log("click", ["x": cursor.x, "y": cursor.y, "id": "composer.title"])
        await type("composer.title", zh ? "和小林喝咖啡" : "Coffee with Lin")
        await pause(0.4)
        await move("composer.wheel", 0.5)
        let tgt = Days.now.addingTimeInterval(2 * 3600)
        let tc = Days.cal.dateComponents([.hour], from: tgt)
        let off = Days.cal.isDate(tgt, inSameDayAs: Days.now) ? 0 : 1
        DemoBus.shared.cmd.send(.text("composer.time", "\(off):\(tc.hour ?? 15):30"))
        log("wheel")
        await pause(1.2)
        await click("composer.add", after: 1.6) { DemoBus.shared.cmd.send(.act("composer.add")) }
    }

    // 5. 接入 AI：三步
    private func aiConnect() async {
        scene("ai")
        await click("rail.gear", after: 1.0) { ui.go(.settings) }
        DemoBus.shared.cmd.send(.scroll("set.ai"))
        log("scroll")
        await pause(1.3)
        await click("set.aiToggle", after: 1.0) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { store.update { $0.aiOn = true } }
        }
        DemoBus.shared.cmd.send(.scroll("set.ai"))
        await pause(0.8)
        let pid = DemoDirector.realAI?.provider ?? "deepseek"
        await click("set.preset." + pid, after: 0.8) { DemoBus.shared.cmd.send(.act("set.preset." + pid)) }
        await click("set.key", after: 0.3) {}
        // “粘贴”：直接用钥匙串里已有的密钥（界面里只显示圆点）
        log("paste")
        DemoBus.shared.cmd.send(.act("set.paste"))
        await pause(1.0)
        await click("set.connect", after: 0.2) { DemoBus.shared.cmd.send(.act("set.connect")) }
        // 等连接结果（最多 25 秒）
        for _ in 0..<100 { if store.data.settings.aiVerified { break }; await pause(0.25) }
        log(store.data.settings.aiVerified ? "success" : "fail")
        if store.data.settings.aiVerified, let r = DemoDirector.realAI, !r.model.isEmpty, r.provider == store.data.settings.aiProvider {
            store.update { $0.aiModel = r.model }
        }
        await pause(2.4)
        await click("page.close", after: 1.0) { ui.go(.home) }
    }

    // 6. 问山人
    private func chat() async {
        scene("chat")
        await click("rail.orb", after: 1.2) { withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { ui.chatOpen = true } }
        await move("chat.input", 0.6)
        log("click", ["x": cursor.x, "y": cursor.y, "id": "chat.input"])
        await type("chat.input", zh ? "结合我的生辰八字，最近哪一天适合谈合作？" : "Based on my birth chart, which day soon is best for a business talk?")
        await pause(0.5)
        await click("chat.send", dur: 0.5, after: 0.2) { DemoBus.shared.cmd.send(.act("chat.send")) }
        log("answer.start")
        // 等回答写完（最多 40 秒）
        var idle = 0
        var last = ""
        for _ in 0..<400 {
            await pause(0.25)
            guard let m = store.data.chat.last, !m.fromUser else { continue }
            let cur = m.text
            if cur == last && !cur.isEmpty { idle += 1 } else { idle = 0 }
            last = cur
            if idle >= 10 { break }
        }
        log("answer.end")
        await pause(2.0)
        await click("chat.close", after: 0.8) { withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { ui.chatOpen = false } }
    }

    // 7. 深色 ↔ 浅色
    private func appearance() async {
        scene("dark")
        withAnimation(.easeInOut(duration: 0.6)) { store.update { $0.appearance = .dark } }
        log("theme")
        await pause(3.0)
        scene("lightagain")
        withAnimation(.easeInOut(duration: 0.6)) { store.update { $0.appearance = .light } }
        log("theme")
        await pause(2.0)
    }

    private func finish() {
        let url = Demo.outDir.appendingPathComponent("events-\(Demo.lang).json")
        let po = panelOrigin()
        let obj: [String: Any] = ["screen": ["w": screenSize.width, "h": screenSize.height],
                                  "panel": ["x": po.x, "y": po.y, "w": panelSize.width, "h": panelSize.height], "events": events]
        if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]) { try? d.write(to: url) }
        // 等录屏先停下再退出（不然退出后会录到你桌面上的东西）
        let quit = Demo.outDir.appendingPathComponent("quit")
        let started = Date()
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { t in
            if FileManager.default.fileExists(atPath: quit.path) || Date().timeIntervalSince(started) > 400 {
                t.invalidate()
                try? FileManager.default.removeItem(at: quit)
                NSWorkspace.shared.runningApplications.filter { Demo.hiddenByDemo.contains($0.processIdentifier) }.forEach { $0.unhide() }
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: 你真实设置里的 AI 服务商（只读地址和模型名，不读密钥）

    struct RealAI { let provider: String; let endpoint: String; let model: String }
    nonisolated(unsafe) static var realAI: RealAI? = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let f0 = base.appendingPathComponent("今日签-山人/data.json")
        let f = FileManager.default.fileExists(atPath: f0.path) ? f0 : base.appendingPathComponent("今日签-新版/data.json")
        guard let raw = try? Data(contentsOf: f),
              let j = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let s = j["settings"] as? [String: Any] else { return nil }
        let p = (s["aiProvider"] as? String) ?? ""
        let e = (s["aiEndpoint"] as? String) ?? ""
        let m = (s["aiModel"] as? String) ?? ""
        if e.isEmpty { return nil }
        return RealAI(provider: p.isEmpty ? "custom" : p, endpoint: e, model: m)
    }()

    nonisolated(unsafe) static var realCity: (String, Double, Double)? = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let f0 = base.appendingPathComponent("今日签-山人/data.json")
        let f = FileManager.default.fileExists(atPath: f0.path) ? f0 : base.appendingPathComponent("今日签-新版/data.json")
        guard let raw = try? Data(contentsOf: f),
              let j = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let s = j["settings"] as? [String: Any],
              let c = s["city"] as? String, !c.isEmpty,
              let la = (s["lat"] as? NSNumber)?.doubleValue, let lo = (s["lon"] as? NSNumber)?.doubleValue else { return nil }
        return (c, la, lo)
    }()
}
