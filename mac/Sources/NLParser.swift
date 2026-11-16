import Foundation

// MARK: - 一行自然语言识别：「明天下午3点 开会」→ 日期 + 时间 + 标题，并返回需高亮的片段

struct ParsedEntry {
    var title: String
    var day: Date
    var time: Date?
    var ranges: [NSRange]      // 识别出的日期/时间片段（高亮用）
    var dayText: String {
        Days.relative(day) + (time.map { " " + Days.hm($0) } ?? "")
    }
}

enum NLParser {
    private static let numMap: [Character: Int] = ["零": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "十": 10]

    static func cnNumber(_ s: String) -> Int? {
        if let n = Int(s) { return n }
        var total = 0, cur = 0
        for ch in s {
            guard let v = numMap[ch] else { return nil }
            if v == 10 { total += (cur == 0 ? 1 : cur) * 10; cur = 0 } else { cur = v }
        }
        return total + cur
    }

    private static func re(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }

    static let dayRe = re("(大后天|后天|明天|明早|明晚|今天|今晚|今早|(下下|下)?(周|星期|礼拜)([一二三四五六日天])|(\\d{1,2})月(\\d{1,2})[日号]?|(\\d{1,2})[日号])")
    static let periodRe = re("(凌晨|早上|早晨|上午|中午|下午|傍晚|晚上|夜里)")
    static let timeRe = re("(\\d{1,2})[:：](\\d{2})|([0-9一二两三四五六七八九十]{1,3})点(半|一刻|三刻|([0-9一二三四五六七八九十]{1,3})分?)?")

    static func parse(_ raw: String, now: Date = Days.now) -> ParsedEntry {
        let text = raw as NSString
        let full = NSRange(location: 0, length: text.length)
        let cal = Days.cal
        let today = cal.startOfDay(for: now)
        var day = today
        var hasDay = false
        var ranges: [NSRange] = []
        var hour: Int? = nil, minute = 0
        var period: String? = nil

        if let m = dayRe.firstMatch(in: raw, range: full) {
            ranges.append(m.range)
            let s = text.substring(with: m.range)
            hasDay = true
            switch s {
            case "今天", "今早": day = today
            case "今晚": day = today; period = "晚上"
            case "明天", "明早": day = Days.addDays(1, to: today); if s == "明早" { period = "早上" }
            case "明晚": day = Days.addDays(1, to: today); period = "晚上"
            case "后天": day = Days.addDays(2, to: today)
            case "大后天": day = Days.addDays(3, to: today)
            default:
                if m.range(at: 4).location != NSNotFound {
                    let w = text.substring(with: m.range(at: 4))
                    let target = ["一": 2, "二": 3, "三": 4, "四": 5, "五": 6, "六": 7, "日": 1, "天": 1][w] ?? 2
                    let curW = cal.component(.weekday, from: today)
                    // 以周一为一周开始
                    func idx(_ wd: Int) -> Int { (wd + 5) % 7 }
                    var diff = idx(target) - idx(curW)
                    let prefix = m.range(at: 2).location != NSNotFound ? text.substring(with: m.range(at: 2)) : ""
                    if prefix == "下" { diff += 7 } else if prefix == "下下" { diff += 14 } else if diff < 0 { diff += 7 }
                    day = Days.addDays(diff, to: today)
                } else if m.range(at: 5).location != NSNotFound {
                    let mo = Int(text.substring(with: m.range(at: 5))) ?? 1
                    let d = Int(text.substring(with: m.range(at: 6))) ?? 1
                    var y = cal.component(.year, from: today)
                    if let c = cal.date(from: DateComponents(year: y, month: mo, day: d)), c < today { y += 1 }
                    day = cal.date(from: DateComponents(year: y, month: mo, day: d)) ?? today
                } else if m.range(at: 7).location != NSNotFound {
                    let d = Int(text.substring(with: m.range(at: 7))) ?? 1
                    var comps = cal.dateComponents([.year, .month], from: today)
                    comps.day = d
                    var c = cal.date(from: comps) ?? today
                    if c < today { c = cal.date(byAdding: .month, value: 1, to: c) ?? c }
                    day = c
                }
            }
        }

        if let m = periodRe.firstMatch(in: raw, range: full) {
            ranges.append(m.range)
            period = text.substring(with: m.range)
        }

        if let m = timeRe.firstMatch(in: raw, range: full) {
            ranges.append(m.range)
            if m.range(at: 1).location != NSNotFound {
                hour = Int(text.substring(with: m.range(at: 1)))
                minute = Int(text.substring(with: m.range(at: 2))) ?? 0
            } else {
                hour = cnNumber(text.substring(with: m.range(at: 3)))
                if m.range(at: 4).location != NSNotFound {
                    let tail = text.substring(with: m.range(at: 4))
                    if tail == "半" { minute = 30 }
                    else if tail == "一刻" { minute = 15 }
                    else if tail == "三刻" { minute = 45 }
                    else if m.range(at: 5).location != NSNotFound { minute = cnNumber(text.substring(with: m.range(at: 5))) ?? 0 }
                }
            }
        }

        if hour == nil, let p = period {
            hour = ["凌晨": 6, "早上": 8, "早晨": 8, "上午": 9, "中午": 12, "下午": 15, "傍晚": 18, "晚上": 20, "夜里": 22][p]
        }
        if var h = hour, let p = period {
            if ["下午", "傍晚", "晚上", "夜里"].contains(p), h < 12 { h += 12 }
            if p == "中午", h < 6 { h += 12 }
            hour = h
        }

        var time: Date? = nil
        if let h = hour, h >= 0, h < 24 {
            time = cal.date(bySettingHour: h, minute: min(59, max(0, minute)), second: 0, of: day)
            if !hasDay, let t = time, t < now { // 只说了时间且已过 → 默认明天
                day = Days.addDays(1, to: day)
                time = cal.date(byAdding: .day, value: 1, to: t)
            }
        }

        // 去掉识别片段得到标题
        var title = raw
        for r in ranges.sorted(by: { $0.location > $1.location }) {
            if let rr = Range(r, in: title) { title.replaceSubrange(rr, with: " ") }
        }
        title = title.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "，,。的在")))
        if title.isEmpty { title = raw.trimmingCharacters(in: .whitespaces) }

        return ParsedEntry(title: title, day: day, time: time, ranges: ranges)
    }

    /// 生成带高亮的富文本
    static func highlighted(_ raw: String, ranges: [NSRange]) -> [(String, Bool)] {
        let ns = raw as NSString
        var out: [(String, Bool)] = []
        var cursor = 0
        for r in ranges.sorted(by: { $0.location < $1.location }) where r.location >= cursor {
            if r.location > cursor { out.append((ns.substring(with: NSRange(location: cursor, length: r.location - cursor)), false)) }
            out.append((ns.substring(with: r), true))
            cursor = r.location + r.length
        }
        if cursor < ns.length { out.append((ns.substring(from: cursor), false)) }
        return out
    }
}
