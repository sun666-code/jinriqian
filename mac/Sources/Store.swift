import Foundation
import SwiftUI

// MARK: - 数据模型（全部只存本机：~/Library/Application Support/今日签-山人/data.json）

struct DrawRecord: Codable, Hashable {
    var day: String
    var lotNo: Int
    var pick: Int
    var at: Date
}

struct Reminder: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var day: String          // 自然日 yyyy-MM-dd
    var time: Date?          // 有具体时间才发通知
    var done = false
    var createdAt = Date()
    var ekId: String? = nil       // 同步到系统「提醒事项」后的标识
    var alerted = false           // 是否已经弹过到点提醒
}

extension Reminder: Codable {
    enum CodingKeys: String, CodingKey { case id, title, day, time, done, createdAt, ekId, alerted }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        day = (try? c.decode(String.self, forKey: .day)) ?? Days.todayKey
        time = try? c.decode(Date.self, forKey: .time)
        done = (try? c.decode(Bool.self, forKey: .done)) ?? false
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        ekId = try? c.decode(String.self, forKey: .ekId)
        alerted = (try? c.decode(Bool.self, forKey: .alerted)) ?? false
    }
}

struct AskRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var question: String
    var at = Date()
}

/// 问山人的对话（只存本机）
struct ChatMsg: Codable, Identifiable, Hashable {
    var id = UUID()
    var fromUser: Bool
    var text: String
    var at = Date()
    var local = false        // 山人本地推算（未用 AI）
}

struct Note: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var tone: Int
    var day: String          // 写于哪个签日
    var createdAt = Date()
    var review = ""
}

struct Settings: Codable, Equatable {
    var appearance: AppearanceMode = .system
    var notifyOn = true
    var eveReminder = true
    var weatherOn = false
    var autoLocate = true
    var city = ""
    var lat: Double? = nil
    var lon: Double? = nil
    var birthOn = false
    var birthDate: Date? = nil
    var birthHour: Int = 12
    var aiOn = false
    var aiEndpoint = ""
    var aiModel = ""
    var aiVerified = false
    var aiVerifiedAt: Date? = nil
    var aiProvider = ""
    var syncReminders = true
    var language: Lang = .zh
    var tagCollapsed = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        appearance = (try? c.decode(AppearanceMode.self, forKey: .appearance)) ?? d.appearance
        notifyOn = (try? c.decode(Bool.self, forKey: .notifyOn)) ?? d.notifyOn
        eveReminder = (try? c.decode(Bool.self, forKey: .eveReminder)) ?? d.eveReminder
        weatherOn = (try? c.decode(Bool.self, forKey: .weatherOn)) ?? d.weatherOn
        city = (try? c.decode(String.self, forKey: .city)) ?? d.city
        autoLocate = (try? c.decode(Bool.self, forKey: .autoLocate)) ?? true
        lat = try? c.decode(Double.self, forKey: .lat)
        lon = try? c.decode(Double.self, forKey: .lon)
        birthOn = (try? c.decode(Bool.self, forKey: .birthOn)) ?? d.birthOn
        birthDate = try? c.decode(Date.self, forKey: .birthDate)
        birthHour = (try? c.decode(Int.self, forKey: .birthHour)) ?? d.birthHour
        aiOn = (try? c.decode(Bool.self, forKey: .aiOn)) ?? d.aiOn
        aiEndpoint = (try? c.decode(String.self, forKey: .aiEndpoint)) ?? d.aiEndpoint
        aiModel = (try? c.decode(String.self, forKey: .aiModel)) ?? d.aiModel
        tagCollapsed = (try? c.decode(Bool.self, forKey: .tagCollapsed)) ?? d.tagCollapsed
        aiVerified = (try? c.decode(Bool.self, forKey: .aiVerified)) ?? false
        aiVerifiedAt = try? c.decode(Date.self, forKey: .aiVerifiedAt)
        aiProvider = (try? c.decode(String.self, forKey: .aiProvider)) ?? ""
        syncReminders = (try? c.decode(Bool.self, forKey: .syncReminders)) ?? true
        language = (try? c.decode(Lang.self, forKey: .language)) ?? .zh
    }
}

struct AppData: Codable {
    var version = 1
    var userSeed = UUID().uuidString
    var draws: [String: DrawRecord] = [:]
    var reminders: [Reminder] = []
    var notes: [Note] = []
    var settings = Settings()
    var aiCache: [String: String] = [:]
    var asks: [AskRecord] = []
    var chat: [ChatMsg] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        userSeed = (try? c.decode(String.self, forKey: .userSeed)) ?? UUID().uuidString
        draws = (try? c.decode([String: DrawRecord].self, forKey: .draws)) ?? [:]
        reminders = (try? c.decode([Reminder].self, forKey: .reminders)) ?? []
        notes = (try? c.decode([Note].self, forKey: .notes)) ?? []
        settings = (try? c.decode(Settings.self, forKey: .settings)) ?? Settings()
        aiCache = (try? c.decode([String: String].self, forKey: .aiCache)) ?? [:]
        asks = (try? c.decode([AskRecord].self, forKey: .asks)) ?? []
        chat = (try? c.decode([ChatMsg].self, forKey: .chat)) ?? []
    }
}

// MARK: - Store

final class Store: ObservableObject {
    @Published var data: AppData
    @Published var qianDay: String = Days.qianDay()
    private let persist: Bool
    private var saveWork: DispatchWorkItem?

    var onRemindersChanged: (() -> Void)?
    var onReminderAdded: ((Reminder) -> Void)?
    var onReminderUpdated: ((Reminder) -> Void)?
    var onReminderDeleted: ((Reminder) -> Void)?

    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(Demo.active ? "今日签-演示" : "今日签-山人", isDirectory: true)
        let fm = FileManager.default
        // 从开发期的「今日签-新版」文件夹自动搬过来（只复制一次，原文件夹保留不动）
        if !Demo.active, !fm.fileExists(atPath: dir.path) {
            let old = base.appendingPathComponent("今日签-新版", isDirectory: true)
            if fm.fileExists(atPath: old.appendingPathComponent("data.json").path) { try? fm.copyItem(at: old, to: dir) }
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }

    init(persist: Bool = true, data: AppData? = nil) {
        self.persist = persist
        if let d = data {
            self.data = d
        } else if persist, let raw = try? Data(contentsOf: Store.fileURL) {
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
            self.data = (try? dec.decode(AppData.self, from: raw)) ?? AppData()
        } else {
            self.data = AppData()
        }
        I18n.lang = self.data.settings.language
        if persist { saveNow() }
    }

    func save() {
        guard persist else { return }
        saveWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: w)
    }

    private func saveNow() {
        guard persist else { return }
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let raw = try? enc.encode(data) {
            try? raw.write(to: Store.fileURL, options: .atomic)
        }
    }

    // MARK: 签日

    func refreshDay() {
        let d = Days.qianDay()
        if d != qianDay { qianDay = d }
    }

    var todayDraw: DrawRecord? { data.draws[qianDay] }
    var needsDraw: Bool { todayDraw == nil }
    var todayLot: Lot? { todayDraw.map { LotLibrary.lot($0.lotNo) } }

    /// 抽签种子 = 本机随机种子 + 八字（换了生辰，牌堆就不同）
    var drawSeed: String {
        let s = data.settings
        guard s.birthOn, let b = s.birthDate else { return data.userSeed }
        return data.userSeed + "|" + Fortune.bazi(date: b, hour: s.birthHour).text
    }
    func lotNo(at index: Int) -> Int { Draw.lotNo(seed: drawSeed, day: qianDay, index: index) }
    var startIndex: Int { Draw.startIndex(seed: data.userSeed, day: qianDay) }

    func commitDraw(pick: Int) {
        guard data.draws[qianDay] == nil else { return }
        let no = lotNo(at: pick)
        data.draws[qianDay] = DrawRecord(day: qianDay, lotNo: no, pick: pick, at: Days.now)
        save()
    }

    func clearToday() {
        data.draws[qianDay] = nil
        data.aiCache[qianDay] = nil
        save()
    }

    func lot(forDay key: String) -> Lot? { data.draws[key].map { LotLibrary.lot($0.lotNo) } }

    var drawHistory: [DrawRecord] { data.draws.values.sorted { $0.day > $1.day } }

    // MARK: 提醒 / 日程

    func reminders(on day: String) -> [Reminder] {
        data.reminders.filter { $0.day == day }.sorted(by: Store.order)
    }

    static func order(_ a: Reminder, _ b: Reminder) -> Bool {
        switch (a.time, b.time) {
        case let (x?, y?): return x < y
        case (nil, _?): return false
        case (_?, nil): return true
        default: return a.createdAt < b.createdAt
        }
    }

    var todayReminders: [Reminder] { reminders(on: Days.todayKey) }
    var pendingToday: Int { todayReminders.filter { !$0.done }.count }

    var upcoming: [Reminder] {
        let t = Days.todayKey
        return data.reminders.filter { $0.day > t && !$0.done }.sorted { ($0.day, $0.time ?? .distantFuture) < ($1.day, $1.time ?? .distantFuture) }
    }

    @discardableResult
    func addReminder(title: String, day: String, time: Date?) -> Reminder {
        let r = Reminder(title: title, day: day, time: time)
        data.reminders.append(r)
        save(); onRemindersChanged?(); onReminderAdded?(r)
        return r
    }

    func toggle(_ r: Reminder) {
        guard let i = data.reminders.firstIndex(where: { $0.id == r.id }) else { return }
        data.reminders[i].done.toggle()
        save(); onRemindersChanged?(); onReminderUpdated?(data.reminders[i])
    }

    func setDone(id: UUID) {
        guard let i = data.reminders.firstIndex(where: { $0.id == id }) else { return }
        data.reminders[i].done = true
        save(); onRemindersChanged?(); onReminderUpdated?(data.reminders[i])
    }

    func delete(_ r: Reminder) {
        data.reminders.removeAll { $0.id == r.id }
        save(); onRemindersChanged?(); onReminderDeleted?(r)
    }

    func move(_ r: Reminder, toDay day: String) {
        guard let i = data.reminders.firstIndex(where: { $0.id == r.id }) else { return }
        data.reminders[i].day = day
        if let t = data.reminders[i].time, let d = Days.date(fromKey: day) {
            let hm = Days.cal.dateComponents([.hour, .minute], from: t)
            data.reminders[i].time = Days.cal.date(bySettingHour: hm.hour!, minute: hm.minute!, second: 0, of: d)
        }
        data.reminders[i].alerted = false
        save(); onRemindersChanged?(); onReminderUpdated?(data.reminders[i])
    }

    func snooze(id: UUID, minutes: Int = 10) {
        guard let i = data.reminders.firstIndex(where: { $0.id == id }) else { return }
        let t = Date().addingTimeInterval(Double(minutes * 60))
        data.reminders[i].time = t
        data.reminders[i].day = Days.key(t)
        data.reminders[i].alerted = false
        save(); onRemindersChanged?(); onReminderUpdated?(data.reminders[i])
    }

    /// 时辰轮上拖动待办圆点：只改钟点，日期不变
    func retime(id: UUID, minuteOfDay: Int) {
        guard let i = data.reminders.firstIndex(where: { $0.id == id }) else { return }
        let day = Days.date(fromKey: data.reminders[i].day) ?? Days.startOfDay(Days.now)
        let m = ((minuteOfDay % 1440) + 1440) % 1440
        data.reminders[i].time = Days.cal.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: day)
        data.reminders[i].alerted = false
        save(); onRemindersChanged?(); onReminderUpdated?(data.reminders[i])
    }

    func setEkId(_ id: UUID, _ ek: String?) {
        guard let i = data.reminders.firstIndex(where: { $0.id == id }) else { return }
        data.reminders[i].ekId = ek
        save()
    }

    func markAlerted(_ id: UUID) {
        guard let i = data.reminders.firstIndex(where: { $0.id == id }) else { return }
        data.reminders[i].alerted = true
        save()
    }

    /// 已到点、未完成、未弹过的提醒
    func dueReminders(now: Date = Date()) -> [Reminder] {
        data.reminders.filter { r in
            guard !r.done, !r.alerted, let t = r.time else { return false }
            return t <= now && now.timeIntervalSince(t) < 6 * 3600
        }
    }

    // MARK: 便签

    func addNote(_ text: String) {
        let n = Note(text: text, tone: data.notes.count % 6, day: qianDay)
        data.notes.insert(n, at: 0)
        save()
    }

    func updateNote(_ n: Note) {
        guard let i = data.notes.firstIndex(where: { $0.id == n.id }) else { return }
        data.notes[i] = n
        save()
    }

    func deleteNote(_ n: Note) {
        data.notes.removeAll { $0.id == n.id }
        save()
    }

    /// 某天是否有记录（日历小黑点 / 日期条小点）
    func hasRecord(_ key: String) -> Bool {
        data.draws[key] != nil || data.reminders.contains { $0.day == key } || data.notes.contains { $0.day == key }
    }

    func update(_ f: (inout Settings) -> Void) {
        var s = data.settings
        f(&s)
        I18n.lang = s.language
        if s != data.settings { data.settings = s; save() }
    }
}

// MARK: - 界面状态

enum Page: Equatable {
    case home, schedule, pickDay, notes, note(UUID), calendar, album, settings, ask, fortune
}

final class UIState: ObservableObject {
    @Published var page: Page = .home
    @Published var dockOpen = false
    @Published var lotOpen = false
    @Published var selectedDay: String = Days.todayKey
    @Published var drawIndex = 300
    @Published var drawPulled = false
    @Published var weatherOpen = false
    @Published var noteIndex = 0
    @Published var birthEditing = false
    @Published var composerOpen = false
    @Published var shareOpen = false
    @Published var askDraft = ""
    @Published var pickAct = "出行"
    @Published var scheduleDraft = ""
    @Published var calMonth: Date = Days.now
    @Published var albumIndex = 0
    // 抽卡阶段
    @Published var drawFlipped = false
    @Published var drawAngle: Double = 0
    @Published var drawDrag: CGFloat = 0
    @Published var tagDropped = true
    // v10 时辰轮
    @Published var probeMinutes: Int? = nil
    @Published var dialDay = 0
    @Published var tossing = false
    @Published var chatOpen = false
    @Published var railLotDrag: CGFloat = 0

    func go(_ p: Page) {
        if p == .ask { withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { chatOpen = true; dockOpen = false; lotOpen = false }; return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { page = p; dockOpen = false; lotOpen = false; chatOpen = false }
    }
}
