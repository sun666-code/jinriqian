import AppKit
import SwiftUI
import Combine

// MARK: - 菜单栏 + 弹出面板
// 不用 MenuBarExtra：它不支持右键菜单，也不能精细控制面板外观。
// 这里用 NSStatusItem + 无边框 NSPanel（系统磨砂底 NSVisualEffectView）承载 SwiftUI。

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// 菜单栏应用没有「编辑」菜单，⌘C / ⌘V / ⌘X / ⌘A / ⌘Z 默认不生效；这里手动转给正在输入的文本框
    override func performKeyEquivalent(with e: NSEvent) -> Bool {
        let mods = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if let ch = e.charactersIgnoringModifiers?.lowercased(), mods == .command || mods == [.command, .shift] {
            let sel: Selector?
            switch (ch, mods == .command) {
            case ("x", true): sel = #selector(NSText.cut(_:))
            case ("c", true): sel = #selector(NSText.copy(_:))
            case ("v", true): sel = #selector(NSText.paste(_:))
            case ("a", true): sel = #selector(NSText.selectAll(_:))
            case ("z", true): sel = Selector(("undo:"))
            case ("z", false): sel = Selector(("redo:"))
            default: sel = nil
            }
            if let s = sel, NSApp.sendAction(s, to: nil, from: self) { return true }
        }
        return super.performKeyEquivalent(with: e)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = Store()
    let ui = UIState()
    let weather = WeatherService()
    private var statusItem: NSStatusItem!
    private var panel: KeyPanel!
    private var bag = Set<AnyCancellable>()
    private var timer: Timer?
    private var ticks = 0

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        LotLibrary.load()
        SystemReminders.shared.store = store
        AlertPresenter.shared.store = store
        store.onReminderAdded = { r in SystemReminders.shared.upsert(r) }
        store.onReminderUpdated = { r in SystemReminders.shared.upsert(r) }
        store.onReminderDeleted = { r in SystemReminders.shared.remove(r) }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = statusItem.button {
            b.target = self
            b.action = #selector(clicked(_:))
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
            b.imagePosition = .imageLeading
        }
        buildPanel()
        Notifier.shared.setup(store: store)
        store.onRemindersChanged = { [weak self] in
            Notifier.shared.reschedule()
            self?.refreshIcon()
        }
        store.$data.receive(on: RunLoop.main).sink { [weak self] _ in self?.refreshIcon(); self?.applyAppearance() }.store(in: &bag)
        store.$qianDay.receive(on: RunLoop.main).sink { [weak self] _ in self?.refreshIcon() }.store(in: &bag)
        // 每秒一次：番茄钟读秒；每 5 秒：签日切换、到点提醒检查
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.ticks += 1
            if self.ticks % 5 == 0 {
                self.store.refreshDay()
                self.checkDue()
                self.refreshIcon()
            }
        }
        timer?.tolerance = 0.3
        if store.data.settings.syncReminders {
            SystemReminders.shared.requestAccess { _ in }
        }
        checkDue()
        refreshIcon()
        applyAppearance()
        refreshWeather()
        if Demo.active { startDemo() }
    }

    private func buildPanel() {
        let p = KeyPanel(contentRect: NSRect(origin: .zero, size: panelSize),
                         styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                         backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .popUpMenu
        p.isMovable = false
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.delegate = self

        let fx = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        fx.material = .popover
        fx.blendingMode = .behindWindow
        fx.state = .active
        fx.wantsLayer = true
        fx.layer?.cornerRadius = 24
        fx.layer?.masksToBounds = true
        fx.maskImage = AppDelegate.roundedMask(size: panelSize, radius: 24)

        let root = RootView()
            .environmentObject(store)
            .environmentObject(ui)
            .environmentObject(weather)
        let host = NSHostingView(rootView: root)
        host.frame = fx.bounds
        host.autoresizingMask = [.width, .height]
        fx.addSubview(host)
        p.contentView = fx
        panel = p
    }

    static func roundedMask(size: CGSize, radius: CGFloat) -> NSImage {
        let img = NSImage(size: size, flipped: false) { r in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill()
            return true
        }
        img.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        img.resizingMode = .stretch
        return img
    }

    // MARK: 点击

    @objc private func clicked(_ sender: NSStatusBarButton) {
        guard let e = NSApp.currentEvent else { return }
        if e.type == .rightMouseUp || e.modifierFlags.contains(.control) {
            showMenu()
        } else {
            panel.isVisible ? hidePanel() : showPanel()
        }
    }

    private func checkDue() {
        guard store.data.settings.notifyOn else { return }
        for r in store.dueReminders() {
            store.markAlerted(r.id)
            AlertPresenter.shared.show(AlertItem(id: r.id, title: r.title, time: r.time ?? Date(), isFocus: false))
        }
    }

    private func showPanel() {
        store.refreshDay()
        if store.needsDraw { ui.drawFlipped = false; ui.drawPulled = false; ui.drawAngle = 0; ui.drawIndex = store.startIndex }
        ui.selectedDay = Days.todayKey
        guard let b = statusItem.button, let w = b.window else { return }
        let r = w.convertToScreen(b.convert(b.bounds, to: nil))
        let screen = w.screen ?? NSScreen.main!
        var x = r.midX - panelSize.width / 2
        x = max(screen.visibleFrame.minX + 8, min(x, screen.visibleFrame.maxX - panelSize.width - 8))
        let y = r.minY - panelSize.height - 6
        panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { c in c.duration = 0.16; panel.animator().alphaValue = 1 }
        b.highlight(true)
        refreshWeather()
    }

    private func hidePanel() {
        NSAnimationContext.runAnimationGroup({ c in c.duration = 0.12; panel.animator().alphaValue = 0 },
                                             completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
            self?.ui.dockOpen = false
            self?.ui.lotOpen = false
        })
        statusItem.button?.highlight(false)
    }

    func windowDidResignKey(_ notification: Notification) {
        if Demo.active { return }
        hidePanel()
    }

    // MARK: 演示自动播放

    private var stageWindow: NSWindow?
    private var goTimer: Timer?

    private func startDemo() {
        store.update {
            $0.language = Demo.lang == "en" ? .en : .zh
            $0.appearance = .light
            $0.notifyOn = false
            $0.syncReminders = false
            $0.weatherOn = true
            $0.autoLocate = false
            if let c = DemoDirector.realCity { $0.city = c.0; $0.lat = c.1; $0.lon = c.2 }
            else { $0.city = Demo.lang == "en" ? "Shanghai" : "上海"; $0.lat = 31.23; $0.lon = 121.47 }
            if let r = DemoDirector.realAI { $0.aiProvider = r.provider; $0.aiEndpoint = r.endpoint; $0.aiModel = r.model }
            $0.aiOn = false
        }
        I18n.lang = store.data.settings.language
        refreshWeather()

        // 先把别的应用窗口都藏起来（等同 ⌥⌘H），露出干净的桌面；结束时再恢复
        Demo.hiddenByDemo = Set(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && !$0.isHidden }.map { $0.processIdentifier })

        let screen = NSScreen.main!
        let sf = screen.frame
        // 左下角同步闪块
        let w = NSWindow(contentRect: NSRect(x: sf.minX, y: sf.minY, width: 16, height: 16), styleMask: [.borderless], backing: .buffered, defer: false)
        w.level = .screenSaver
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.contentView = NSHostingView(rootView: DemoFlashView())
        w.orderFrontRegardless()
        stageWindow = w

        try? FileManager.default.createDirectory(at: Demo.outDir, withIntermediateDirectories: true)
        try? "\(Int(sf.width)),\(Int(sf.height))".write(to: Demo.outDir.appendingPathComponent("frame.txt"), atomically: true, encoding: .utf8)
        let go = Demo.outDir.appendingPathComponent("go")
        let started = Date()
        goTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] t in
            guard let self = self else { return }
            if FileManager.default.fileExists(atPath: go.path) {
                t.invalidate()
                try? FileManager.default.removeItem(at: go)
                let d = DemoDirector(store: self.store, ui: self.ui)
                d.screenSize = sf.size
                d.openPanel = { [weak self] in self?.showPanel() }
                d.statusPoint = { [weak self] in
                    guard let b = self?.statusItem.button, let bw = b.window else { return CGPoint(x: sf.width - 200, y: 12) }
                    let r = bw.convertToScreen(b.convert(b.bounds, to: nil))
                    return CGPoint(x: r.midX - sf.minX, y: sf.maxY - r.midY)
                }
                d.panelOrigin = { [weak self] in
                    guard let f = self?.panel.frame else { return .zero }
                    return CGPoint(x: f.minX - sf.minX, y: sf.maxY - f.maxY)
                }
                Task { @MainActor in await d.run() }
            } else if Date().timeIntervalSince(started) > 90 {
                t.invalidate(); NSApp.terminate(nil)
            }
        }
        // 演示里关掉自动收起：面板要一直开着
        _ = w
    }

    private func showMenu() {
        let m = NSMenu()
        let open = NSMenuItem(title: L("打开今日签"), action: #selector(openFromMenu), keyEquivalent: "")
        open.target = self
        m.addItem(open)
        m.addItem(.separator())
        let ask = NSMenuItem(title: L("问山人"), action: #selector(openAsk), keyEquivalent: "")
        ask.target = self
        m.addItem(ask)
        let lang = NSMenuItem(title: store.data.settings.language == .en ? "切换到中文" : "Switch to English", action: #selector(toggleLang), keyEquivalent: "")
        lang.target = self
        m.addItem(lang)
        m.addItem(.separator())
        let login = NSMenuItem(title: L("开机启动"), action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.enabled ? .on : .off
        m.addItem(login)
        let look = NSMenuItem(title: L("外观"), action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for mode in AppearanceMode.allCases {
            let it = NSMenuItem(title: L(mode.label), action: #selector(setAppearance(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = mode.rawValue
            it.state = store.data.settings.appearance == mode ? .on : .off
            sub.addItem(it)
        }
        look.submenu = sub
        m.addItem(look)
        m.addItem(.separator())
        let quit = NSMenuItem(title: L("退出今日签"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        m.addItem(quit)
        statusItem.menu = m
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openFromMenu() { showPanel() }
    @objc private func openAsk() { showPanel(); if !store.needsDraw { ui.page = .ask } }
    @objc private func toggleLang() { store.update { $0.language = $0.language == .en ? .zh : .en }; lastIconKey = ""; refreshIcon() }
    @objc private func toggleLogin() { LoginItem.set(!LoginItem.enabled) }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func setAppearance(_ s: NSMenuItem) {
        if let raw = s.representedObject as? String, let m = AppearanceMode(rawValue: raw) {
            store.update { $0.appearance = m }
        }
    }

    private var lastAppearance: AppearanceMode? = nil
    private func applyAppearance() {
        // 只在外观设置真的变了时才改窗口外观；以前每次数据变化都重设，切换深浅色或语言后界面会被反复重绘、点不动
        guard store.data.settings.appearance != lastAppearance else { return }
        lastAppearance = store.data.settings.appearance
        switch store.data.settings.appearance {
        case .system: panel?.appearance = nil
        case .light: panel?.appearance = NSAppearance(named: .aqua)
        case .dark: panel?.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func refreshWeather() {
        let s = store.data.settings
        if s.weatherOn, let la = s.lat, let lo = s.lon { weather.fetch(lat: la, lon: lo, city: s.city) }
    }

    // MARK: 菜单栏图标：未抽 = 实心签牌；已抽 = 空心签牌（旁边显示待办数）

    private var lastIconKey = ""
    private func refreshIcon() {
        guard let b = statusItem?.button else { return }
        let drawn = !store.needsDraw
        let pending = store.pendingToday
        let branch = ((Days.cal.component(.hour, from: Days.now) + 1) / 2) % 12
        let key = "\(drawn)-\(pending)-\(branch)-\(I18n.lang.rawValue)"
        guard key != lastIconKey else { return }
        lastIconKey = key
        b.image = AppDelegate.dialIcon(branch: branch, drawn: drawn)
        b.title = drawn && pending > 0 ? " \(pending)" : ""
        b.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        b.toolTip = drawn ? L("今日签 · 已抽签") + (pending > 0 ? " · " + LF("%d 项待办", pending) : "") : L("今日签 · 今天还没抽签")
    }

    /// 菜单栏小表盘：一圈 = 一天，实心扇形 = 现在所在的时辰；没抽签时圆心是实心点
    static func dialIcon(branch: Int, drawn: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { _ in
            let c = NSPoint(x: 9, y: 9)
            NSColor.black.setStroke(); NSColor.black.setFill()
            let ring = NSBezierPath(ovalIn: NSRect(x: 1.6, y: 1.6, width: 14.8, height: 14.8))
            ring.lineWidth = 1.3; ring.stroke()
            for k in 0..<12 where k % 3 == 0 {
                let a = (90 - Double(k) * 30) * .pi / 180
                let t = NSBezierPath()
                t.move(to: NSPoint(x: c.x + cos(a) * 5.6, y: c.y + sin(a) * 5.6))
                t.line(to: NSPoint(x: c.x + cos(a) * 7.4, y: c.y + sin(a) * 7.4))
                t.lineWidth = 0.9; t.stroke()
            }
            let mid = Double(branch) * 30
            let w = NSBezierPath()
            w.move(to: c)
            w.appendArc(withCenter: c, radius: 7.4, startAngle: CGFloat(90 - (mid - 15)), endAngle: CGFloat(90 - (mid + 15)), clockwise: true)
            w.close(); w.fill()
            if !drawn {
                NSBezierPath(ovalIn: NSRect(x: 6, y: 6, width: 6, height: 6)).fill()
            } else {
                NSBezierPath(ovalIn: NSRect(x: 7.6, y: 7.6, width: 2.8, height: 2.8)).fill()
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    static func tagIcon(filled: Bool) -> NSImage {
        let size = NSSize(width: 16, height: 18)
        let img = NSImage(size: size, flipped: false) { _ in
            let body = NSRect(x: 2.5, y: 0.8, width: 11, height: 14.2)
            let path = NSBezierPath(roundedRect: body, xRadius: 3, yRadius: 3)
            // 绳
            let rope = NSBezierPath()
            rope.move(to: NSPoint(x: 8, y: 15)); rope.line(to: NSPoint(x: 8, y: 17.6))
            rope.lineWidth = 1.3
            NSColor.black.setStroke(); rope.stroke()
            let hole = NSBezierPath(ovalIn: NSRect(x: 6.6, y: 11, width: 2.8, height: 2.8))
            if filled {
                NSColor.black.setFill()
                let combined = NSBezierPath()
                combined.append(path)
                combined.append(hole)
                combined.windingRule = .evenOdd
                combined.fill()
            } else {
                path.lineWidth = 1.4
                NSColor.black.setStroke(); path.stroke()
                hole.lineWidth = 1.1; hole.stroke()
                let line = NSBezierPath()
                line.move(to: NSPoint(x: 5.5, y: 7.2)); line.line(to: NSPoint(x: 10.5, y: 7.2))
                line.move(to: NSPoint(x: 5.5, y: 4.4)); line.line(to: NSPoint(x: 9, y: 4.4))
                line.lineWidth = 1.2; line.lineCapStyle = .round; line.stroke()
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}
