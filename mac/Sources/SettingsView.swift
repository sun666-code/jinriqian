import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @EnvironmentObject var weather: WeatherService
    @Environment(\.pal) private var p
    @State private var cityQuery = ""
    @State private var keyDraft = Snap.active ? "sk-••••••••" : (Demo.active ? "" : Keychain.load())
    @State private var showKey = false
    @State private var loginOn = Snap.active ? false : LoginItem.enabled
    @State private var confirmClear = false
    @State private var testing = false
    @State private var testMsg: String? = nil
    @State private var testOK = false
    @State private var models: [String] = Snap.active ? ["deepseek-flash", "deepseek-v4-pro"] : []
        @State private var lotsCount = LotLibrary.all.count

    /// 截图模式下演示“测试成功”
    var demoVerified = false
    var demoEditBirth = false

    private func bind<T>(_ kp: WritableKeyPath<Settings, T>, after: @escaping () -> Void = {}) -> Binding<T> {
        Binding(get: { store.data.settings[keyPath: kp] }, set: { v in store.update { $0[keyPath: kp] = v }; after() })
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: L("设置"), subtitle: L("所有数据只存在这台 Mac 上"), back: { ui.go(.home) },
                       trailing: AnyView(LangToggle()))
            Scroller {
                VStack(spacing: 12) {
                    group(L("外观"), "circle.lefthalf.filled") {
                        Segmented(items: AppearanceMode.allCases.map { ($0, L($0.label)) }, selection: bind(\.appearance))
                    }
                    group(L("提醒"), "bell") {
                        row(L("系统通知 + 到点弹窗"), L("时间到了会在屏幕右上角弹出，可点「完成 / 稍后」")) {
                            GlassToggle(isOn: bind(\.notifyOn, after: { Notifier.shared.reschedule() }))
                        }
                        row(L("同步到系统「提醒事项」"), L("新建的待办会带时间写入 iPhone / Mac 的提醒事项")) {
                            GlassToggle(isOn: bind(\.syncReminders, after: {
                                if store.data.settings.syncReminders && !Snap.active {
                                    SystemReminders.shared.requestAccess { _ in store.data.reminders.filter { !$0.done }.forEach { SystemReminders.shared.upsert($0) } }
                                }
                            }))
                        }
                        row(L("前一晚 21:00 预告"), L("明天要做的事 + 宜忌")) {
                            GlassToggle(isOn: bind(\.eveReminder, after: { Notifier.shared.reschedule() }))
                        }
                    }
                    group(L("天气"), "cloud.sun") {
                        row(L("显示天气"), L("默认关闭；打开后自动定位，显示在顶栏")) {
                            GlassToggle(isOn: bind(\.weatherOn, after: {
                                if store.data.settings.weatherOn && !Snap.active { weather.locateAndFetch(store: store) }
                            }))
                        }
                        if store.data.settings.weatherOn { weatherSetup }
                    }
                    group(L("命盘（生辰八字）"), "person.crop.circle") {
                        MingPan(startEditing: demoEditBirth)
                    }
                    group(L("AI（可选，三步接入）"), "wand.and.stars") {
                        row(L("启用 AI"), L("用于问山人「细说」和看签页「命理总批」；默认关闭")) {
                            GlassToggle(isOn: bind(\.aiOn)).demoTarget("set.aiToggle")
                        }
                        if store.data.settings.aiOn { aiSetup }
                    }
                    .id("set.ai")
                    group(L("通用"), "gearshape") {
                        row(L("开机启动"), L("登录后自动出现在菜单栏")) {
                            GlassToggle(isOn: Binding(get: { loginOn }, set: { v in loginOn = v; if !Snap.active { LoginItem.set(v) } }))
                        }
                        row(L("清除今日数据"), L("删除今天的签，重新抽一次")) {
                            Button(action: {
                                if confirmClear {
                                    store.clearToday(); confirmClear = false
                                    ui.drawFlipped = false; ui.drawPulled = false; ui.drawAngle = 0; ui.page = .home
                                } else { confirmClear = true }
                            }) {
                                Text(L(confirmClear ? "确认清除" : "清除")).font(Typo.ui(12, .bold))
                                    .foregroundColor(confirmClear ? p.onAccent : p.ink)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Capsule().fill(confirmClear ? p.accent : p.glassFill2))
                                    .overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
                            }.buttonStyle(PressStyle())
                        }
                    }
                    VStack(spacing: 6) {
                        Text(L("今日签 1.1 · MIT 开源协议")).font(Typo.ui(11.5, .bold)).foregroundColor(p.ink2)
                        Text(L("签文为原创内容；黄历宜忌由传统建除法在本机推算。全部内容仅供娱乐参考，请勿据此做重大决定。"))
                            .font(Typo.ui(10.5)).foregroundColor(p.ink3).multilineTextAlignment(.center).lineSpacing(2)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 16)
            }
            .edgeFade()
        }
        .onAppear {
            if demoVerified { testOK = true; testMsg = L("连接成功") + " · deepseek-flash · 812 ms"; models = ["deepseek-flash", "deepseek-v4-pro"] }
        }
    }

    // MARK: 组件

    private func group<C: View>(_ title: String, _ sym: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: sym).font(.system(size: 12, weight: .bold)).foregroundColor(p.ink)
                Text(title).font(Typo.ui(12.5, .bold)).foregroundColor(p.ink2)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(22, depth: 1)
    }

    private func row<C: View>(_ title: String, _ sub: String, @ViewBuilder _ trailing: () -> C) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typo.ui(13, .semibold)).foregroundColor(p.ink)
                Text(sub).font(Typo.ui(10.5)).foregroundColor(p.ink2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            trailing()
        }
    }

    private func smallButton(_ t: String, _ sym: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 5) { Image(systemName: sym).font(.system(size: 11, weight: .bold)); Text(t).font(Typo.ui(12, .bold)) }
                .foregroundColor(p.ink)
                .padding(.horizontal, 12).frame(height: 32)
                .background(Capsule().fill(p.glassFill2))
                .overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
        }.buttonStyle(PressStyle())
    }

    private func labeled<C: View>(_ label: String?, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let label = label { Text(label).font(Typo.ui(11, .bold)).foregroundColor(p.ink2) }
            HStack(spacing: 8) { c() }
                .padding(.horizontal, 12).frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(p.glassFill2))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(p.hairline, lineWidth: 1))
        }
    }

    // MARK: 天气

    private var weatherSetup: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: store.data.settings.autoLocate ? "location.fill" : "mappin.and.ellipse").foregroundColor(p.tint)
                Text(store.data.settings.city.isEmpty ? L(weather.status.isEmpty ? "正在定位…" : weather.status)
                     : (L(store.data.settings.autoLocate ? "自动定位：" : "手动城市：") + store.data.settings.city))
                    .font(Typo.ui(12, .semibold)).foregroundColor(p.ink)
                Spacer()
                if !store.data.settings.autoLocate {
                    Button(L("改回自动定位")) { store.update { $0.autoLocate = true }; weather.locateAndFetch(store: store) }
                        .buttonStyle(.plain).font(Typo.ui(11.5, .bold)).foregroundColor(p.tint)
                }
            }
            labeled(L("定位不了？手动输入城市")) {
                Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .bold)).foregroundColor(p.ink3)
                Field(placeholder: L("如 上海、杭州、Tokyo，回车搜索"), text: $cityQuery, size: 12.5, onSubmit: { weather.search(cityQuery) })
            }
            ForEach(weather.results) { c in
                Button(action: {
                    store.update { $0.city = c.name; $0.lat = c.lat; $0.lon = c.lon; $0.autoLocate = false }
                    weather.results = []; cityQuery = ""
                    weather.fetch(lat: c.lat, lon: c.lon, city: c.name)
                }) {
                    HStack {
                        Text(c.name).font(Typo.ui(12.5, .semibold)).foregroundColor(p.ink)
                        Text(c.admin).font(Typo.ui(11)).foregroundColor(p.ink2)
                        Spacer()
                        Image(systemName: "plus.circle").foregroundColor(p.ink2)
                    }
                    .padding(.vertical, 3)
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: AI 一键接入：选服务商 → 粘贴密钥 → 连接（自动拉模型 + 自动选 + 自动测试）

    private var aiSetup: some View {
        let s = store.data.settings
        let cur = AIPresets.current(s)
        let ok = s.aiVerified || testOK
        return VStack(alignment: .leading, spacing: 12) {
            stepTitle("1", L("选服务商"))
            FlowLayout(spacing: 6) {
                ForEach(AIPresets.all) { pr in
                    Button(action: { choose(pr) }) { Chip(text: pr.name, strong: pr.id == cur.id) }.buttonStyle(PressStyle())
                        .demoTarget("set.preset." + pr.id)
                }
            }
            if cur.id == "custom" {
                labeled(L("Base URL")) {
                    Field(placeholder: L("填完整地址，如 https://xxx.com/v1"), text: bind(\.aiEndpoint, after: { store.update { $0.aiVerified = false } }), size: 12.5)
                }
                labeled(L("模型")) {
                    Field(placeholder: L("模型名（连接时会自动获取）"), text: bind(\.aiModel, after: { store.update { $0.aiVerified = false } }), size: 12.5)
                }
            }
            HStack {
                stepTitle("2", L("粘贴密钥"))
                Spacer()
                if let u = URL(string: cur.keyURL), !cur.keyURL.isEmpty {
                    Button(action: { NSWorkspace.shared.open(u) }) {
                        HStack(spacing: 3) { Text(LF("去 %@ 拿密钥", L(cur.name))); Image(systemName: "arrow.up.right") }
                            .font(Typo.ui(11, .bold)).foregroundColor(p.tint)
                    }.buttonStyle(.plain)
                }
            }
            labeled(nil) {
                if showKey || Snap.active {
                    Field(placeholder: L("sk- 开头的一串字符"), text: $keyDraft, size: 12.5, onSubmit: { connect() })
                } else {
                    SecretField(placeholder: L("sk- 开头的一串字符"), text: $keyDraft)
                }
                Button(action: { showKey.toggle() }) {
                    Image(systemName: showKey ? "eye.slash" : "eye").font(.system(size: 12, weight: .semibold)).foregroundColor(p.ink2)
                }.buttonStyle(.plain)
            }
            .demoTarget("set.key")
            stepTitle("3", L("一键连接"))
            Button(action: { connect() }) {
                HStack(spacing: 6) {
                    Image(systemName: testing ? "hourglass" : (ok ? "checkmark.seal.fill" : "bolt.fill")).font(.system(size: 12, weight: .bold))
                    Text(testing ? L("正在连接…") : (ok ? LF("已连接 %@ · 点此重新测试", L(cur.name)) : LF("连接 %@", L(cur.name)))).font(Typo.ui(13, .bold))
                }
                .foregroundColor(p.onAccent)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(Capsule().fill(p.accent))
            }.buttonStyle(PressStyle()).disabled(testing)
            .demoTarget("set.connect")
            .onDemo { c in
                guard case .act(let a) = c else { return }
                if a.hasPrefix("set.preset."), let pr = AIPresets.all.first(where: { "set.preset." + $0.id == a }) { choose(pr) }
                if a == "set.paste" { keyDraft = Keychain.load() }
                if a == "set.connect" { connect() }
            }
            if let m = testMsg {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: testOK ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(testOK ? Color(hex: 0x30B35A) : p.ink2)
                    Text(m).font(Typo.ui(11.5)).foregroundColor(p.ink).fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(p.glassFill2))
            }
            if !models.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("模型（已自动选好，点别的会自动重新测试）")).font(Typo.ui(11, .bold)).foregroundColor(p.ink2)
                    FlowLayout(spacing: 6) {
                        ForEach(models.prefix(10), id: \.self) { m in
                            Button(action: { store.update { $0.aiModel = m; $0.aiVerified = false }; connect(keepModel: true) }) {
                                Chip(text: m, strong: m == s.aiModel)
                            }.buttonStyle(PressStyle())
                        }
                    }
                }
            } else if ok && !s.aiModel.isEmpty {
                Text(L("当前模型：") + s.aiModel).font(Typo.ui(11)).foregroundColor(p.ink2)
            }
            Text(L("地址和模型都会自动填好，你只需要粘贴密钥。密钥只存在 macOS 钥匙串，本应用不内置任何后端与密钥。"))
                .font(Typo.ui(10.5)).foregroundColor(p.ink2).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stepTitle(_ n: String, _ t: String) -> some View {
        HStack(spacing: 6) {
            Text(n).font(Typo.num(10, .heavy)).foregroundColor(p.onAccent)
                .frame(width: 17, height: 17).background(Circle().fill(p.accent))
            Text(t).font(Typo.ui(12, .bold)).foregroundColor(p.ink)
        }
    }

    private func choose(_ pr: AIPreset) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            store.update {
                $0.aiProvider = pr.id
                if pr.id != "custom" { $0.aiEndpoint = pr.base; $0.aiModel = "" }
                $0.aiVerified = false
            }
            models = []; testMsg = nil; testOK = false
        }
    }

    /// 连接：存密钥 → 拉模型列表并自动选一个 → 发一句测试 → 成功即保存
    private func connect(keepModel: Bool = false) {
        let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { testOK = false; testMsg = L("先粘贴密钥"); return }
        let pr = AIPresets.current(store.data.settings)
        store.update {
            $0.aiProvider = pr.id
            if pr.id != "custom" { $0.aiEndpoint = pr.base }
        }
        let base = store.data.settings.aiEndpoint
        guard base.lowercased().hasPrefix("http") else { testOK = false; testMsg = L("自定义地址要以 https:// 开头"); return }
        Keychain.save(key)
        testing = true; testMsg = nil
        let finish: (String) -> Void = { model in
            store.update { $0.aiModel = model }
            AIClient.test(base: base, model: model) { r in
                testing = false
                testOK = r.ok
                testMsg = r.ok ? r.message + (r.reply.isEmpty ? "" : "　“\(r.reply.prefix(20))”") : r.message
                store.update { $0.aiVerified = r.ok; $0.aiVerifiedAt = r.ok ? Date() : nil }
            }
        }
        if keepModel && !store.data.settings.aiModel.isEmpty { finish(store.data.settings.aiModel); return }
        AIClient.models(base: base) { list, err in
            let chat = AIPresets.chatModels(list)
            models = chat
            if let m = AIPresets.pick(list, preset: pr) {
                finish(m)
            } else if !store.data.settings.aiModel.isEmpty || !pr.model.isEmpty {
                finish(store.data.settings.aiModel.isEmpty ? pr.model : store.data.settings.aiModel)
            } else {
                testing = false; testOK = false
                testMsg = err ?? L("没有获取到模型，请在上面手动填写模型名")
            }
        }
    }
}

/// 中 / EN 切换键
struct LangToggle: View {
    @EnvironmentObject var store: Store
    @Environment(\.pal) private var p
    var body: some View {
        let en = store.data.settings.language == .en
        Button(action: { store.update { $0.language = en ? .zh : .en } }) {
            HStack(spacing: 0) {
                Text(L("中")).frame(width: 26, height: 24).background(Capsule().fill(en ? Color.clear : p.accent)).foregroundColor(en ? p.ink2 : p.onAccent)
                Text("EN").frame(width: 30, height: 24).background(Capsule().fill(en ? p.accent : Color.clear)).foregroundColor(en ? p.onAccent : p.ink2)
            }
            .font(Typo.ui(11.5, .bold))
            .padding(3)
            .background(Capsule().fill(p.glassFill2))
            .overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
        }.buttonStyle(PressStyle())
    }
}
