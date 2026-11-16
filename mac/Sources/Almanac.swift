import Foundation

// MARK: - 日期工具
// 签日：北京时间早上 8:00 切换。7:59 仍算昨天的签日。
// 日程/提醒：按自然日（本机时区）。

enum Days {
    static let beijing = TimeZone(identifier: "Asia/Shanghai")!

    static var bjCal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = beijing
        c.firstWeekday = 2
        return c
    }

    static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }

    /// 可注入的“现在”（截图模式使用固定时间）
    static var nowOverride: Date? = nil
    static var now: Date { nowOverride ?? Date() }

    static func key(_ d: Date, cal c: Calendar = Days.cal) -> String {
        let x = c.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", x.year!, x.month!, x.day!)
    }

    static func date(fromKey k: String) -> Date? {
        let parts = k.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    /// 当前签日（北京时间减 8 小时取日期）
    static func qianDay(at d: Date = Days.now) -> String {
        key(d.addingTimeInterval(-8 * 3600), cal: bjCal)
    }

    static var todayKey: String { key(now) }

    static func startOfDay(_ d: Date) -> Date { cal.startOfDay(for: d) }

    static func addDays(_ n: Int, to d: Date) -> Date { cal.date(byAdding: .day, value: n, to: d)! }

    static let weekNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    static func weekday(_ d: Date) -> String {
        let i = cal.component(.weekday, from: d) - 1
        return I18n.en ? weekNamesEn[i] : weekNames[i]
    }

    static func md(_ d: Date) -> String {
        let c = cal.dateComponents([.month, .day], from: d)
        return I18n.en ? "\(monthNamesEn[c.month! - 1]) \(c.day!)" : "\(c.month!)月\(c.day!)日"
    }

    static func hm(_ d: Date) -> String {
        let c = cal.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour!, c.minute!)
    }

    static func relative(_ d: Date) -> String {
        let diff = cal.dateComponents([.day], from: startOfDay(now), to: startOfDay(d)).day ?? 0
        switch diff {
        case 0: return L("今天")
        case 1: return L("明天")
        case 2: return L("后天")
        case -1: return L("昨天")
        default: return md(d) + " " + weekday(d)
        }
    }
}

// MARK: - 黄历（本地推算，原创实现）
// · 农历日期：系统自带中国农历（Foundation .chinese）
// · 日干支：以 2000-01-01（戊午日）为基准推算
// · 月建：按“节”（立春、惊蛰……）近似公式（21 世纪误差 ≤1 天）
// · 建除十二值星：日支与月建相对位置，配合传统宜忌（生活化表述）

struct DayAlmanac {
    let date: Date
    let lunarMonth: Int
    let lunarDay: Int
    let isLeap: Bool
    let yearGZ: String
    let zodiac: String
    let dayGZ: String
    let officer: Int
    let yi: [String]
    let ji: [String]
    let score: Int

    var officerName: String { Almanac.officers[officer] + "日" }
    var lunarText: String { (isLeap ? "闰" : "") + Almanac.monthName(lunarMonth) + Almanac.dayName(lunarDay) }
    var lunarDayText: String { lunarDay == 1 ? Almanac.monthName(lunarMonth) : Almanac.dayName(lunarDay) }
}

enum Almanac {
    static let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    static let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    static let animals = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]
    static let officers = ["建", "除", "满", "平", "定", "执", "破", "危", "成", "收", "开", "闭"]

    /// 择日可选事项
    static let activities = ["出行", "签约", "搬家", "开业", "求职", "聚会", "理发", "就医", "学习", "扫除", "理财", "装修"]

    static let officerYi: [[String]] = [
        ["出行", "求职", "学习"],          // 建
        ["扫除", "就医", "理发"],          // 除
        ["聚会", "开业", "理财"],          // 满
        ["扫除", "理发", "学习"],          // 平
        ["签约", "求职", "学习", "聚会"],  // 定
        ["扫除", "学习", "签约"],          // 执
        ["就医", "扫除"],                  // 破
        ["学习", "静心"],                  // 危
        ["开业", "签约", "搬家", "出行", "聚会"], // 成
        ["理财", "学习", "扫除"],          // 收
        ["开业", "求职", "出行", "搬家", "学习"], // 开
        ["扫除", "理财", "休息"],          // 闭
    ]
    static let officerJi: [[String]] = [
        ["搬家", "装修"],
        ["签约", "聚会"],
        ["就医", "装修"],
        ["开业", "搬家"],
        ["出行", "争执"],
        ["搬家", "出行", "开业"],
        ["签约", "开业", "搬家", "聚会", "出行"],
        ["出行", "冒险", "搬家"],
        ["争执"],
        ["出行", "就医"],
        ["装修"],
        ["开业", "出行", "就医"],
    ]
    static let officerBase = [1, 1, 1, 0, 2, 0, -2, -1, 3, 1, 3, -1]
    static let extraYi = ["沐浴", "会友", "读书", "整理", "运动", "种植", "早睡", "写字", "散步", "做饭"]

    static func monthName(_ m: Int) -> String {
        ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"][max(0, min(11, m - 1))]
    }

    static func dayName(_ d: Int) -> String {
        let n = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        if d == 10 { return "初十" }
        if d == 20 { return "二十" }
        if d == 30 { return "三十" }
        let pre = d < 10 ? "初" : (d < 20 ? "十" : (d < 30 ? "廿" : "三"))
        return pre + n[(d - 1) % 10]
    }

    private static let jieC: [Double] = [5.4055, 3.87, 5.63, 4.81, 5.52, 5.678, 7.108, 7.5, 7.646, 8.318, 7.438, 7.18]

    static func jieDay(year: Int, month: Int) -> Int {
        let y = year % 100
        let y4 = month <= 2 ? (y - 1) / 4 : y / 4
        return Int(floor(Double(y) * 0.2422 + jieC[month - 1])) - y4
    }

    private static var cache: [String: DayAlmanac] = [:]

    static func of(_ date: Date) -> DayAlmanac {
        let k = Days.key(date, cal: Days.bjCal)
        if let c = cache[k] { return c }
        let bj = Days.bjCal
        let g = bj.dateComponents([.year, .month, .day], from: date)
        let (y, m, d) = (g.year!, g.month!, g.day!)

        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = Days.beijing
        let noon = bj.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
        let lc = chinese.dateComponents([.year, .month, .day], from: noon)
        let leap = lc.isLeapMonth ?? false
        let cyc = ((lc.year ?? 1) - 1) % 60
        let yearGZ = stems[cyc % 10] + branches[cyc % 12]
        let zodiac = animals[cyc % 12]

        // 日干支
        let base = bj.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 12))!
        let days = bj.dateComponents([.day], from: base, to: noon).day ?? 0
        let idx = ((54 + days) % 60 + 60) % 60
        let dayGZ = stems[idx % 10] + branches[idx % 12]
        let dayBranch = idx % 12

        // 月建
        let monthBranch = d >= jieDay(year: y, month: m) ? m % 12 : (m - 1) % 12
        let officer = ((dayBranch - monthBranch) % 12 + 12) % 12

        var yi = officerYi[officer]
        let extra = extraYi[idx % extraYi.count]
        if !yi.contains(extra) { yi.append(extra) }
        let ji = officerJi[officer]

        let a = DayAlmanac(date: noon, lunarMonth: lc.month ?? 1, lunarDay: lc.day ?? 1, isLeap: leap,
                           yearGZ: yearGZ, zodiac: zodiac, dayGZ: dayGZ, officer: officer,
                           yi: yi, ji: ji, score: officerBase[officer])
        cache[k] = a
        return a
    }

    /// 某事项在某天的分数（宜 +3、忌 -4，再叠加值星基础分）
    static func score(_ a: DayAlmanac, for act: String) -> Int {
        var s = a.score
        if a.yi.contains(act) { s += 3 }
        if a.ji.contains(act) { s -= 4 }
        return s
    }

    /// 未来 n 天里最适合某事项的 top 天
    static func bestDays(for act: String, from: Date = Days.now, within n: Int = 30, top: Int = 5) -> [DayAlmanac] {
        let start = Days.startOfDay(from)
        let all = (0..<n).map { of(Days.addDays($0, to: start)) }
        return all
            .filter { !$0.ji.contains(act) }
            .sorted { (score($0, for: act), -$0.date.timeIntervalSince1970) > (score($1, for: act), -$1.date.timeIntervalSince1970) }
            .prefix(top)
            .sorted { $0.date < $1.date }
    }

    /// 从日程标题猜事项，用于“撞上忌日”提醒
    static func guessActivity(_ title: String) -> String? {
        let map: [(String, [String])] = [
            ("出行", ["出差", "旅行", "旅游", "出发", "飞", "高铁", "自驾", "出行", "回家"]),
            ("签约", ["签约", "合同", "签字", "签合"]),
            ("搬家", ["搬家", "搬"]),
            ("开业", ["开业", "上线", "发布", "开张", "开店"]),
            ("求职", ["面试", "求职", "入职", "述职"]),
            ("聚会", ["聚会", "聚餐", "饭局", "约饭", "派对", "生日"]),
            ("理发", ["理发", "剪头", "剪发", "烫发"]),
            ("就医", ["医院", "体检", "看病", "牙医", "复查"]),
            ("装修", ["装修", "动工"]),
            ("理财", ["理财", "买基金", "存钱"]),
        ]
        for (act, kws) in map where kws.contains(where: { title.contains($0) }) { return act }
        return nil
    }
}
