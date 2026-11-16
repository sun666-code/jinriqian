import Foundation
import UserNotifications
import ServiceManagement
import CoreLocation
import Security
import EventKit
import AppKit

// MARK: - 系统通知：带「完成」「稍后」两个按钮；前一晚 21:00 预告（可关）

final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    weak var store: Store?
    private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    func setup(store: Store) {
        self.store = store
        center.delegate = self
        let done = UNNotificationAction(identifier: "DONE", title: L("完成"), options: [])
        let later = UNNotificationAction(identifier: "SNOOZE", title: L("稍后（10 分钟）"), options: [])
        let cat = UNNotificationCategory(identifier: "REMINDER", actions: [done, later], intentIdentifiers: [], options: [])
        center.setNotificationCategories([cat])
        // 只在「从没问过」时才弹系统授权；问过一次（允许或拒绝）以后就不再打扰
        center.getNotificationSettings { st in
            guard st.authorizationStatus == .notDetermined else { return }
            self.center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
        reschedule()
    }

    func reschedule() {
        guard let store = store else { return }
        center.removeAllPendingNotificationRequests()
        let s = store.data.settings
        guard s.notifyOn else { return }
        let now = Date()
        var eveDays: [String: [String]] = [:]
        for r in store.data.reminders where !r.done {
            if let t = r.time, t > now {
                add(id: r.id.uuidString, title: r.title, body: L("今日签") + " · " + Days.hm(t), at: t, userInfo: ["rid": r.id.uuidString])
            }
            eveDays[r.day, default: []].append(r.title)
        }
        if s.eveReminder {
            for (day, titles) in eveDays {
                guard let d = Days.date(fromKey: day) else { continue }
                let eve = Days.addDays(-1, to: Days.startOfDay(d))
                guard let at = Days.cal.date(bySettingHour: 21, minute: 0, second: 0, of: eve), at > now else { continue }
                let a = Almanac.of(d)
                let body = titles.prefix(3).joined(separator: "、") + "　" + L(a.officerName) + " · " + L("宜") + " " + a.yi.prefix(2).map(L).joined(separator: "·")
                add(id: "eve-" + day, title: LF("明天有 %d 件事", titles.count), body: body, at: at, userInfo: [:], category: false)
            }
        }
    }

    private func add(id: String, title: String, body: String, at: Date, userInfo: [String: String], category: Bool = true) {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        c.userInfo = userInfo
        if category { c.categoryIdentifier = "REMINDER" }
        let comps = Days.cal.dateComponents([.year, .month, .day, .hour, .minute], from: at)
        let trig = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: c, trigger: trig))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let rid = (info["rid"] as? String).flatMap(UUID.init(uuidString:))
        DispatchQueue.main.async {
            if let id = rid {
                if response.actionIdentifier == "DONE" {
                    self.store?.setDone(id: id)
                } else if response.actionIdentifier == "SNOOZE" {
                    self.store?.snooze(id: id)
                }
            }
            completionHandler()
        }
    }
}

// MARK: - 开机启动

enum LoginItem {
    static var enabled: Bool { SMAppService.mainApp.status == .enabled }
    static func set(_ on: Bool) {
        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch { NSLog("login item: \(error)") }
    }
}

// MARK: - 天气（Open-Meteo，免费无 key；默认关闭，打开才联网）

struct WeatherNow: Equatable {
    var temp: Double
    var feels: Double
    var code: Int
    var high: Double
    var low: Double
    var rain: Int
    var city: String

    var desc: String { WeatherNow.describe(code).0 }
    var symbol: String { WeatherNow.describe(code).1 }
    var tip: String {
        if rain >= 50 { return "可能有雨，宜带伞" }
        if high - low >= 9 { return "温差大，宜添衣" }
        if temp >= 30 { return "天热，多喝水" }
        if temp <= 5 { return "天冷，注意保暖" }
        return "天气平稳，宜出门走走"
    }

    static func describe(_ c: Int) -> (String, String) {
        switch c {
        case 0: return ("晴", "sun.max")
        case 1, 2: return ("少云", "cloud.sun")
        case 3: return ("阴", "cloud")
        case 45, 48: return ("雾", "cloud.fog")
        case 51...57: return ("毛毛雨", "cloud.drizzle")
        case 61...67, 80...82: return ("雨", "cloud.rain")
        case 71...77, 85, 86: return ("雪", "cloud.snow")
        case 95...99: return ("雷阵雨", "cloud.bolt.rain")
        default: return ("多云", "cloud.sun")
        }
    }
}

struct GeoCity: Identifiable, Hashable {
    var id: String { "\(name)\(lat)\(lon)" }
    let name: String
    let admin: String
    let lat: Double
    let lon: Double
}

final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var now: WeatherNow?
    @Published var results: [GeoCity] = []
    @Published var status = ""
    @Published var locating = false
    private var lm: CLLocationManager?
    var onLocated: ((Double, Double) -> Void)?

    func fetch(lat: Double, lon: Double, city: String) {
        var u = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        u.queryItems = [
            .init(name: "latitude", value: String(lat)), .init(name: "longitude", value: String(lon)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,weather_code"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            .init(name: "timezone", value: "auto"), .init(name: "forecast_days", value: "1"),
        ]
        URLSession.shared.dataTask(with: u.url!) { data, _, _ in
            guard let data = data,
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let cur = j["current"] as? [String: Any],
                  let daily = j["daily"] as? [String: Any] else {
                DispatchQueue.main.async { self.status = "天气获取失败" }
                return
            }
            func first(_ k: String) -> Double { ((daily[k] as? [Any])?.first as? NSNumber)?.doubleValue ?? 0 }
            let w = WeatherNow(temp: (cur["temperature_2m"] as? NSNumber)?.doubleValue ?? 0,
                               feels: (cur["apparent_temperature"] as? NSNumber)?.doubleValue ?? 0,
                               code: (cur["weather_code"] as? NSNumber)?.intValue ?? 0,
                               high: first("temperature_2m_max"), low: first("temperature_2m_min"),
                               rain: Int(first("precipitation_probability_max")), city: city)
            DispatchQueue.main.async { self.now = w; self.status = "" }
        }.resume()
    }

    func search(_ q: String) {
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else { results = []; return }
        var u = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        u.queryItems = [.init(name: "name", value: q), .init(name: "count", value: "5"), .init(name: "language", value: "zh")]
        URLSession.shared.dataTask(with: u.url!) { data, _, _ in
            var out: [GeoCity] = []
            if let data = data, let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let arr = j["results"] as? [[String: Any]] {
                for r in arr {
                    if let n = r["name"] as? String, let la = (r["latitude"] as? NSNumber)?.doubleValue,
                       let lo = (r["longitude"] as? NSNumber)?.doubleValue {
                        out.append(GeoCity(name: n, admin: (r["admin1"] as? String) ?? (r["country"] as? String) ?? "", lat: la, lon: lo))
                    }
                }
            }
            DispatchQueue.main.async { self.results = out; self.status = out.isEmpty ? "没有找到这个城市" : "" }
        }.resume()
    }

    /// 自动定位 → 反查城市名 → 拉天气；定位失败时提示手动输入
    func locateAndFetch(store: Store, force: Bool = false) {
        let s = store.data.settings
        if !force, !s.autoLocate, let la = s.lat, let lo = s.lon { fetch(lat: la, lon: lo, city: s.city); return }
        onLocatedCity = { [weak self, weak store] la, lo, name in
            store?.update { $0.lat = la; $0.lon = lo; $0.city = name }
            self?.fetch(lat: la, lon: lo, city: name)
        }
        if !force, let la = s.lat, let lo = s.lon, !s.city.isEmpty { fetch(lat: la, lon: lo, city: s.city) }
        locate()
    }

    func locate() {
        let m = CLLocationManager()
        m.delegate = self
        m.desiredAccuracy = kCLLocationAccuracyKilometer
        lm = m
        status = "正在定位…"
        locating = true
        switch m.authorizationStatus {
        case .notDetermined: m.requestWhenInUseAuthorization()   // 授权后在回调里再定位
        case .denied, .restricted: ipFallback()
        default: m.requestLocation()
        }
        // 10 秒还没结果，就按网络位置大致定位
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.locating == true { self?.ipFallback() }
        }
    }

    /// 系统定位不可用时：按网络（IP）大致定位到城市
    private func ipFallback() {
        guard locating else { return }
        URLSession.shared.dataTask(with: URL(string: "https://ipwho.is/?lang=zh-CN")!) { data, _, _ in
            if let d = data, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
               let la = (j["latitude"] as? NSNumber)?.doubleValue, let lo = (j["longitude"] as? NSNumber)?.doubleValue {
                let name = (j["city"] as? String) ?? L("当前位置")
                DispatchQueue.main.async {
                    self.locating = false
                    self.status = "系统定位不可用，已按网络位置大致定位"
                    self.onLocatedCity?(la, lo, name)
                }
            } else {
                DispatchQueue.main.async { self.locating = false; self.status = "定位失败，手动输入城市即可" }
            }
        }.resume()
    }

    var onLocatedCity: ((Double, Double, String) -> Void)?

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }
        CLGeocoder().reverseGeocodeLocation(l, preferredLocale: Locale(identifier: "zh_CN")) { marks, _ in
            let p = marks?.first
            let name = p?.locality ?? p?.subAdministrativeArea ?? p?.administrativeArea ?? L("当前位置")
            DispatchQueue.main.async {
                self.status = ""
                self.locating = false
                self.onLocated?(l.coordinate.latitude, l.coordinate.longitude)
                self.onLocatedCity?(l.coordinate.latitude, l.coordinate.longitude, name)
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let st = manager.authorizationStatus
        if st == .denied || st == .restricted {
            DispatchQueue.main.async { self.ipFallback() }
        } else if st != .notDetermined, locating {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { self.ipFallback() }
    }
}

// MARK: - 钥匙串（AI 密钥只存这里，不写入任何文件）

enum Keychain {
    static let service = "今日签新版.ai"
    static let account = "api-key"

    /// 读过一次就记在内存里，同一次打开里不再反复去钥匙串取（反复取会让系统反复问）
    private static var cache: String?

    static func save(_ value: String) {
        cache = value
        if Demo.active { return }   // 演示时只读不写，不动你钥匙串里的密钥
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load() -> String {
        if let c = cache { return c }
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service, kSecAttrAccount as String: account,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        let rc = SecItemCopyMatching(q as CFDictionary, &out)
        if rc == errSecItemNotFound { cache = ""; return "" }
        guard rc == errSecSuccess, let d = out as? Data else { return "" }
        let v = String(data: d, encoding: .utf8) ?? ""
        cache = v
        return v
    }

    static var hasKey: Bool { !load().isEmpty }
}

// MARK: - 自接 AI 解读（默认关闭；兼容 OpenAI 格式）
// 只需填 Base URL（如 https://api.deepseek.com 或 https://api.openai.com/v1），
// 程序会自动补全 /chat/completions，404 时再试 /v1/chat/completions。

enum AIClient {
    struct TestResult { let ok: Bool; let message: String; let reply: String }

    static func candidates(_ base: String, path: String) -> [URL] {
        var b = base.trimmingCharacters(in: .whitespacesAndNewlines)
        while b.hasSuffix("/") { b.removeLast() }
        if b.hasSuffix("/chat/completions") {
            if path == "/chat/completions" { return [URL(string: b)].compactMap { $0 } }
            b = String(b.dropLast("/chat/completions".count))
        }
        var list = [b + path]
        if !b.hasSuffix("/v1") { list.append(b + "/v1" + path) }
        return list.compactMap { URL(string: $0) }.filter { $0.scheme?.hasPrefix("http") == true }
    }

    static func request(_ url: URL, body: [String: Any]?, timeout: Double = 60) -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = body == nil ? "GET" : "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = Keychain.load()
        if !key.isEmpty { req.setValue("Bearer " + key, forHTTPHeaderField: "Authorization") }
        if let b = body { req.httpBody = try? JSONSerialization.data(withJSONObject: b) }
        return req
    }

    /// 依次尝试候选地址，返回第一个非 404 的结果
    private static func send(_ urls: [URL], body: [String: Any]?, completion: @escaping (Data?, Int, Error?) -> Void) {
        guard let u = urls.first else { completion(nil, 0, NSError(domain: "今日签", code: 1, userInfo: [NSLocalizedDescriptionKey: L("Base URL 无效，应以 https:// 开头")])); return }
        URLSession.shared.dataTask(with: request(u, body: body)) { data, resp, err in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if (code == 404 || code == 405) && urls.count > 1 {
                send(Array(urls.dropFirst()), body: body, completion: completion)
            } else {
                completion(data, code, err)
            }
        }.resume()
    }

    static func errorText(_ data: Data?, code: Int, err: Error?) -> String {
        if let e = err { return L("网络错误：") + e.localizedDescription }
        var detail = ""
        if let d = data, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            if let e = j["error"] as? [String: Any], let m = e["message"] as? String { detail = m }
            else if let m = j["message"] as? String { detail = m }
        }
        let hint: String
        switch code {
        case 401, 403: hint = "密钥无效或没有权限"
        case 404: hint = "地址不对，检查 Base URL"
        case 400, 422: hint = "请求被拒绝，多半是模型名不对"
        case 402: hint = "账户余额不足"
        case 429: hint = "请求太频繁或额度用完"
        default: hint = code == 0 ? "接口没有响应" : LF("接口返回 %d", code)
        }
        return detail.isEmpty ? L(hint) : L(hint) + ": " + String(detail.prefix(80))
    }

    static func chat(_ prompt: String, base: String, model: String, maxTokens: Int = 400,
                     completion: @escaping (Result<String, Error>) -> Void) {
        chatMessages([["role": "user", "content": prompt]], base: base, model: model, maxTokens: maxTokens, temperature: 0.8, completion: completion)
    }

    /// 多轮对话（system + 历史 + 本次提问）
    static func chatMessages(_ messages: [[String: String]], base: String, model: String, maxTokens: Int = 700, temperature: Double = 0.7,
                             completion: @escaping (Result<String, Error>) -> Void) {
        let body: [String: Any] = ["model": model, "messages": messages,
                                   "temperature": temperature, "max_tokens": maxTokens, "stream": false]
        send(candidates(base, path: "/chat/completions"), body: body) { data, code, err in
            DispatchQueue.main.async {
                if (200..<300).contains(code), let d = data,
                   let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                   let choices = j["choices"] as? [[String: Any]],
                   let msg = choices.first?["message"] as? [String: Any],
                   let text = msg["content"] as? String {
                    completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    completion(.failure(NSError(domain: "今日签", code: code, userInfo: [NSLocalizedDescriptionKey: errorText(data, code: code, err: err)])))
                }
            }
        }
    }

    /// 流式对话：边生成边回调（onText 收到目前为止的全部正文；onThinking 表示模型还在「思考」）
    /// 兼容 DeepSeek 等推理模型：思考内容（reasoning_content）不展示，只用来提示「推演中」。
    static func stream(_ messages: [[String: String]], base: String, model: String, maxTokens: Int = 4000, temperature: Double = 0.7,
                       onThinking: @escaping () -> Void = {}, onText: @escaping (String) -> Void,
                       completion: @escaping (Result<String, Error>) -> Void) {
        let body: [String: Any] = ["model": model, "messages": messages, "temperature": temperature,
                                   "max_tokens": maxTokens, "stream": true]
        let urls = candidates(base, path: "/chat/completions")
        Task {
            var text = "", thinking = false, lastPush = Date.distantPast
            func fail(_ msg: String, _ code: Int) {
                DispatchQueue.main.async { completion(.failure(NSError(domain: "今日签", code: code, userInfo: [NSLocalizedDescriptionKey: msg]))) }
            }
            guard !urls.isEmpty else { fail(L("Base URL 无效，应以 https:// 开头"), 1); return }
            for (i, u) in urls.enumerated() {
                var req = request(u, body: body, timeout: 120)
                req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                do {
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                    if (code == 404 || code == 405) && i < urls.count - 1 { continue }
                    if !(200..<300).contains(code) {
                        var raw = Data()
                        for try await b in bytes { raw.append(b); if raw.count > 4000 { break } }
                        fail(errorText(raw, code: code, err: nil), code); return
                    }
                    for try await line in bytes.lines {
                        var l = line.trimmingCharacters(in: .whitespaces)
                        if l.hasPrefix("data:") { l = String(l.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
                        if l.isEmpty || l == "[DONE]" { continue }
                        guard let d = l.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                              let ch = (j["choices"] as? [[String: Any]])?.first else { continue }
                        let delta = (ch["delta"] as? [String: Any]) ?? (ch["message"] as? [String: Any]) ?? [:]
                        if let r = delta["reasoning_content"] as? String, !r.isEmpty, text.isEmpty, !thinking {
                            thinking = true
                            DispatchQueue.main.async { onThinking() }
                        }
                        if let c = delta["content"] as? String, !c.isEmpty {
                            text += c
                            if Date().timeIntervalSince(lastPush) > 0.05 {
                                lastPush = Date()
                                let snap = text
                                DispatchQueue.main.async { onText(snap) }
                            }
                        }
                    }
                    let final = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if final.isEmpty { fail(L("模型没有给出正文（可能只输出了思考过程），换一个模型试试"), 0); return }
                    DispatchQueue.main.async { onText(final); completion(.success(final)) }
                    return
                } catch {
                    if i < urls.count - 1 { continue }
                    fail(L("网络错误：") + error.localizedDescription, 0); return
                }
            }
        }
    }

    /// 测试连接：发一句极短的请求，返回成功与否 + 耗时
    static func test(base: String, model: String, completion: @escaping (TestResult) -> Void) {
        guard !model.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion(TestResult(ok: false, message: L("请先填写模型名称（如 deepseek-chat）"), reply: "")); return
        }
        let t0 = Date()
        chat("只回复两个字：你好", base: base, model: model, maxTokens: 10) { r in
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            switch r {
            case .success(let t): completion(TestResult(ok: true, message: L("连接成功") + " · \(model) · \(ms) ms", reply: t))
            case .failure(let e): completion(TestResult(ok: false, message: e.localizedDescription, reply: ""))
            }
        }
    }

    /// 拉取模型列表（GET /models）
    static func models(base: String, completion: @escaping ([String], String?) -> Void) {
        send(candidates(base, path: "/models"), body: nil) { data, code, err in
            DispatchQueue.main.async {
                if (200..<300).contains(code), let d = data,
                   let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                   let arr = j["data"] as? [[String: Any]] {
                    completion(arr.compactMap { $0["id"] as? String }.sorted(), nil)
                } else {
                    completion([], errorText(data, code: code, err: err))
                }
            }
        }
    }

    static func interpret(lot: Lot, almanac: DayAlmanac, endpoint: String, model: String,
                          completion: @escaping (Result<String, Error>) -> Void) {
        let prompt = """
        你是温和的生活顾问。用户今天抽到「\(lot.levelText) \(lot.name)」，签诗：\(lot.poem)。
        今日黄历：\(almanac.officerName)，宜 \(almanac.yi.joined(separator: "、"))，忌 \(almanac.ji.joined(separator: "、"))。
        请用不超过 120 字的简体中文，给出今天的一句解读和两条可执行的小建议。语气轻松，不要恐吓，结尾注明“仅供娱乐参考”。
        """
        chat(prompt, base: endpoint, model: model, completion: completion)
    }
}

// MARK: - 同步到系统「提醒事项」（EventKit，可关）

final class SystemReminders {
    static let shared = SystemReminders()
    private let ek = EKEventStore()
    private(set) var granted = false
    weak var store: Store?

    /// 系统里是否已经授权过（不弹窗）
    var alreadyGranted: Bool {
        let st = EKEventStore.authorizationStatus(for: .reminder)
        if #available(macOS 14.0, *) { return st == .fullAccess }
        return st == .authorized
    }

    func requestAccess(_ done: @escaping (Bool) -> Void) {
        // 已经授权过：直接用，不再弹窗；已经拒绝过：也不再弹（系统本来就不会再问）
        if alreadyGranted { granted = true; DispatchQueue.main.async { done(true) }; return }
        if EKEventStore.authorizationStatus(for: .reminder) != .notDetermined {
            granted = false; DispatchQueue.main.async { done(false) }; return
        }
        let finish: (Bool, Error?) -> Void = { ok, _ in
            DispatchQueue.main.async { self.granted = ok; done(ok) }
        }
        if #available(macOS 14.0, *) {
            ek.requestFullAccessToReminders(completion: finish)
        } else {
            ek.requestAccess(to: .reminder, completion: finish)
        }
    }

    private var enabled: Bool { store?.data.settings.syncReminders ?? false }

    func upsert(_ r: Reminder) {
        guard enabled else { return }
        let go = {
            guard self.granted else { return }
            let item: EKReminder
            if let id = r.ekId, let ex = self.ek.calendarItem(withIdentifier: id) as? EKReminder {
                item = ex
            } else {
                item = EKReminder(eventStore: self.ek)
                guard let cal = self.ek.defaultCalendarForNewReminders() else { return }
                item.calendar = cal
            }
            item.title = r.title
            item.notes = "来自 今日签"
            item.isCompleted = r.done
            item.alarms?.forEach { item.removeAlarm($0) }
            if let t = r.time {
                item.dueDateComponents = Days.cal.dateComponents([.year, .month, .day, .hour, .minute], from: t)
                item.addAlarm(EKAlarm(absoluteDate: t))
            } else if let d = Days.date(fromKey: r.day) {
                item.dueDateComponents = Days.cal.dateComponents([.year, .month, .day], from: d)
            }
            do {
                try self.ek.save(item, commit: true)
                if r.ekId != item.calendarItemIdentifier { self.store?.setEkId(r.id, item.calendarItemIdentifier) }
            } catch { NSLog("reminder save: \(error)") }
        }
        if granted { go() } else { requestAccess { _ in go() } }
    }

    func remove(_ r: Reminder) {
        guard enabled, granted, let id = r.ekId, let item = ek.calendarItem(withIdentifier: id) as? EKReminder else { return }
        try? ek.remove(item, commit: true)
    }
}
