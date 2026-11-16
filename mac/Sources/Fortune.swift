import Foundation

// MARK: - 今日断语引擎（本地推算，娱乐用途）
// 依据：生辰八字（年/月/日/时柱）、日支与命主年支/日支的冲·合·害、
// 十二时辰黄黑道（青龙、白虎……）、冲煞方位、喜神/财神方位、日主五行与当日天干的生克（十神简化）、
// 梅花易数起每日一卦（年支+农历月+日 → 上卦；再加命主数 → 下卦与动爻）。
// 结论刻意写得具体、直接（几点、做什么、别做什么），并始终标注“仅供娱乐参考”。

struct BaZi {
    let year: Int, month: Int, day: Int, hour: Int   // 六十甲子序号（甲子 = 0）
    var pillars: [String] { [year, month, day, hour].map(Fortune.gz) }
    var text: String { pillars.joined(separator: " ") }
    var yearBranch: Int { year % 12 }
    var dayBranch: Int { day % 12 }
    var dayStem: Int { day % 10 }
    var zodiac: String { Almanac.animals[yearBranch] }
    /// 日主五行
    var element: Int { Fortune.stemElement(dayStem) }
}

struct HourSlot: Identifiable {
    let branch: Int
    let god: String
    let good: Bool
    let personalClash: Bool
    var personal: Int = 0            // 与命主日支/年支的合冲害（正 = 合你，负 = 克你）
    var id: Int { branch }
    var start: Int { (branch * 2 + 23) % 24 }
    var range: String { String(format: "%02d:00–%02d:00", start, (start + 2) % 24) }
    var name: String { L(Almanac.branches[branch] + "时") }
}

struct Reading {
    enum Tone { case good, mixed, bad }
    let tone: Tone
    let headline: String
    let reasons: [String]          // 依据（短句）
    let doNow: [String]            // 大胆的“去做”
    let dont: [String]             // 大胆的“别做”
    let goodHours: [(HourSlot, String)]
    let badHours: [(HourSlot, String)]
    let slots: [HourSlot]
    let luckyDir: String
    let wealthDir: String
    let shaDir: String
    let clashZodiac: String
    let hexName: String
    let hexVerdict: String
    let hexLine: String
    let period: [String]           // 这段时间（流年 / 流月）
    let personal: Bool
}

enum Fortune {
    static let elements = ["木", "火", "土", "金", "水"]
    static func gz(_ i: Int) -> String { Almanac.stems[((i % 10) + 10) % 10] + Almanac.branches[((i % 12) + 12) % 12] }
    static func stemElement(_ s: Int) -> Int { s / 2 }
    static func branchElement(_ b: Int) -> Int { [4, 2, 0, 0, 2, 1, 1, 2, 3, 3, 2, 4][b] }

    static func clash(_ a: Int, _ b: Int) -> Bool { (a - b + 12) % 12 == 6 }
    static func harmony(_ a: Int, _ b: Int) -> Bool { (a + b) % 12 == 1 }
    static func trine(_ a: Int, _ b: Int) -> Bool { a != b && a % 4 == b % 4 }
    static func harm(_ a: Int, _ b: Int) -> Bool { (a + b) % 12 == 7 }

    static func dayIndex(_ date: Date) -> Int {
        let bj = Days.bjCal
        let g = bj.dateComponents([.year, .month, .day], from: date)
        let noon = bj.date(from: DateComponents(year: g.year, month: g.month, day: g.day, hour: 12))!
        let base = bj.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 12))!
        let days = bj.dateComponents([.day], from: base, to: noon).day ?? 0
        return ((54 + days) % 60 + 60) % 60
    }

    /// 年柱以立春为界；月柱按节气月建 + 五虎遁；时柱按五鼠遁
    static func bazi(date: Date, hour: Int) -> BaZi {
        let bj = Days.bjCal
        let g = bj.dateComponents([.year, .month, .day], from: date)
        var y = g.year!
        let m = g.month!, d = g.day!
        if m < 2 || (m == 2 && d < Almanac.jieDay(year: y, month: 2)) { y -= 1 }
        let yi = ((y - 4) % 60 + 60) % 60
        let mb = d >= Almanac.jieDay(year: g.year!, month: m) ? m % 12 : (m - 1 + 12) % 12
        let firstStem = ((yi % 10) % 5 * 2 + 2) % 10
        let ms = (firstStem + (mb - 2 + 12) % 12) % 10
        let mi = sixty(stem: ms, branch: mb)
        let di = dayIndex(date)
        let hb = ((hour + 1) / 2) % 12
        let hs = ((di % 10) % 5 * 2 + hb) % 10
        return BaZi(year: yi, month: mi, day: di, hour: sixty(stem: hs, branch: hb))
    }

    static func sixty(stem: Int, branch: Int) -> Int {
        for i in 0..<60 where i % 10 == stem && i % 12 == branch { return i }
        return 0
    }

    // 时辰黄黑道
    static let gods = ["青龙", "明堂", "天刑", "朱雀", "金匮", "天德", "白虎", "玉堂", "天牢", "玄武", "司命", "勾陈"]
    static let godGood = [true, true, false, false, true, true, false, true, false, false, true, false]
    static let godDo = ["谈判、求人办事", "见领导、汇报", "", "", "收钱、谈薪、理财", "签约、做决定", "", "面试、表白、见重要的人", "", "", "处理文书、写方案", ""]
    static let godDont = ["", "", "吵架、打官司", "发言、发朋友圈、口头承诺", "", "", "开车远行、剧烈运动、动刀", "", "签字、担保、借钱给人", "投资、网购大件、轻信陌生人", "", "拖延、临时改计划"]

    static func slots(dayBranch: Int, me: BaZi?) -> [HourSlot] {
        let start = (8 + 2 * (dayBranch % 6)) % 12
        return (0..<12).map { b in
            let k = (b - start + 12) % 12
            var pv = 0
            if let me = me {
                if harmony(b, me.dayBranch) || trine(b, me.dayBranch) { pv += 2 }
                if harmony(b, me.yearBranch) { pv += 1 }
                if clash(b, me.dayBranch) { pv -= 2 }
                if harm(b, me.dayBranch) || harm(b, me.yearBranch) { pv -= 1 }
            }
            return HourSlot(branch: b, god: gods[k], good: godGood[k],
                            personalClash: me.map { clash(b, $0.yearBranch) } ?? false, personal: pv)
        }
    }

    // 喜用（简化：生扶日主的五行）→ 幸运色、幸运数字
    static let elementColor = ["绿色", "紫色", "米黄色", "白色", "深蓝色"]
    static let elementNumber = [[3, 8], [2, 7], [5, 0], [4, 9], [1, 6]]
    static func luckyElement(_ me: BaZi?, dayStem: Int) -> Int {
        let base = me?.element ?? stemElement(dayStem)
        return (base + 4) % 5
    }

    static let dirs = ["东北", "西北", "西南", "正南", "东南"]
    static func luckyDir(_ stem: Int) -> String { dirs[stem % 5] }
    static func wealthDir(_ stem: Int) -> String { ["东北", "东北", "西南", "西南", "正北", "正北", "正东", "正东", "正南", "正南"][stem] }
    static func shaDir(_ branch: Int) -> String { ["正南", "正东", "正北", "正西"][branch % 4] }

    // 梅花易数：先天八卦数 1乾 2兑 3离 4震 5巽 6坎 7艮 8坤
    static let trigrams = ["乾", "兑", "离", "震", "巽", "坎", "艮", "坤"]
    static let hexNames: [[String]] = [
        ["乾为天", "天泽履", "天火同人", "天雷无妄", "天风姤", "天水讼", "天山遁", "天地否"],
        ["泽天夬", "兑为泽", "泽火革", "泽雷随", "泽风大过", "泽水困", "泽山咸", "泽地萃"],
        ["火天大有", "火泽睽", "离为火", "火雷噬嗑", "火风鼎", "火水未济", "火山旅", "火地晋"],
        ["雷天大壮", "雷泽归妹", "雷火丰", "震为雷", "雷风恒", "雷水解", "雷山小过", "雷地豫"],
        ["风天小畜", "风泽中孚", "风火家人", "风雷益", "巽为风", "风水涣", "风山渐", "风地观"],
        ["水天需", "水泽节", "水火既济", "水雷屯", "水风井", "坎为水", "水山蹇", "水地比"],
        ["山天大畜", "山泽损", "山火贲", "山雷颐", "山风蛊", "山水蒙", "艮为山", "山地剥"],
        ["地天泰", "地泽临", "地火明夷", "地雷复", "地风升", "地水师", "地山谦", "坤为地"],
    ]

    static func hexagram(date: Date, personal: Int) -> (name: String, verdict: String, line: String) {
        let a = Almanac.of(date)
        let yb = Almanac.branches.firstIndex(of: String(a.yearGZ.suffix(1))) ?? 0
        let s1 = (yb + 1) + a.lunarMonth + a.lunarDay
        let s2 = s1 + personal
        let up = (s1 - 1) % 8, low = (s2 - 1) % 8
        let line = (s2 - 1) % 6
        let name = hexNames[up][low]
        let v = HexVerdicts.zh[name] ?? ""
        return (name, I18n.en ? (HexVerdicts.en[name] ?? v) : v, L(lineHints[line]))
    }

    static let lineHints = ["动在初爻：事情刚起头，先别声张", "动在二爻：靠身边人，找搭档一起做", "动在三爻：最容易出错的一步，慢一点",
                            "动在四爻：上面有人盯着，按规矩来", "动在五爻：今天你说了算，敢拍板", "动在上爻：见好就收，别贪最后一口"]

    // MARK: 生成断语

    static func reading(for date: Date, birth: Date?, birthHour: Int) -> Reading {
        let di = dayIndex(date)
        let db = di % 12, ds = di % 10
        let me: BaZi? = birth.map { bazi(date: $0, hour: birthHour) }
        let slotsAll = slots(dayBranch: db, me: me)
        let waking = slotsAll.filter { (7...22).contains($0.start) || $0.start == 23 }
        var reasons: [String] = []
        var doNow: [String] = []
        var dont: [String] = []
        var headline = ""
        var tone: Reading.Tone = .mixed
        let clashZ = Almanac.animals[(db + 6) % 12]
        let worst = waking.filter { !$0.good || $0.personalClash || $0.personal <= -2 }.sorted { score($0) < score($1) }
        let best = waking.filter { $0.good && !$0.personalClash && $0.personal > -2 }.sorted { score($0) > score($1) }

        if let me = me {
            let yb = me.yearBranch, mdb = me.dayBranch
            if clash(db, yb) {
                tone = .bad
                headline = LF("今天冲你的属相（%@），能不出门就别出门；必须出门，避开 %@。", L(me.zodiac), worst.first?.range ?? "")
                reasons.append(LF("日支%@冲你的年支%@", Almanac.branches[db], Almanac.branches[yb]))
                dont += [L("签合同、做大额付款"), L("开车远行、走夜路"), L("跟家人或伴侣翻旧账")]
                doNow += [L("把今天的计划砍掉一半"), L("重要的事改到明天")]
            } else if clash(db, mdb) {
                tone = .bad
                headline = L("今天冲你的日柱：最容易在亲近的人身上起冲突，重要的话留到明天说。")
                reasons.append(LF("日支%@冲你的日支%@", Almanac.branches[db], Almanac.branches[mdb]))
                dont += [L("跟伴侣、合伙人摊牌"), L("在群里发长语音"), L("冲动辞职或提分手")]
                doNow += [L("一个人把手头的活做完"), L("晚上早点睡")]
            } else if harm(db, yb) {
                tone = .bad
                headline = L("今天与你相害：小人多、口舌多。别替人担保，别借钱，别背锅。")
                reasons.append(LF("日支%@与你的年支%@相害", Almanac.branches[db], Almanac.branches[yb]))
                dont += [L("替别人作保、借钱出去"), L("在背后议论同事"), L("答应模糊的请求")]
                doNow += [L("所有承诺留文字记录"), L("跟可靠的老朋友待在一起")]
            } else if harmony(db, yb) || trine(db, yb) {
                tone = .good
                headline = LF("今天与你相合：贵人在%@。适合主动开口——谈加薪、约见、表白都选今天。", L(luckyDir(ds)))
                reasons.append(LF("日支%@与你的年支%@%@", Almanac.branches[db], Almanac.branches[yb], L(harmony(db, yb) ? "六合" : "三合")))
                doNow += [L("主动找人要资源"), L("把拖着的事一口气推进"), L("见一个重要的人")]
                dont += [L("客气推辞送上门的机会")]
            } else {
                let rel = relation(me.element, stemElement(ds))
                headline = L(relHeadline[rel])
                reasons.append(LF("你的日主%@，今日天干%@（%@）", Almanac.stems[me.dayStem] + L(elements[me.element]), Almanac.stems[ds] + L(elements[stemElement(ds)]), L(relName[rel])))
                doNow += relDo[rel].map(L)
                dont += relDont[rel].map(L)
                tone = rel == 1 || rel == 3 ? .good : (rel == 4 ? .bad : .mixed)
            }
            if let ph = slotsAll.first(where: { $0.personalClash && (7...22).contains($0.start) }) {
                dont.append(LF("%@（%@）是你的冲时，别做决定", ph.range, ph.name))
            }
        } else {
            let a = Almanac.of(date)
            tone = a.score >= 2 ? .good : (a.score < 0 ? .bad : .mixed)
            headline = a.score >= 2 ? LF("今天是%@，诸事可推进：最好的时间在 %@。", L(a.officerName), best.first?.range ?? "")
                : a.score < 0 ? LF("今天是%@，不宜开新局：%@ 前别做任何重大决定。", L(a.officerName), worst.first.map { String(format: "%02d:00", ($0.start + 2) % 24) } ?? "")
                : LF("今天是%@，平稳但别冒进：%@ 最容易出岔子。", L(a.officerName), worst.first?.range ?? "")
            reasons.append(LF("今日冲%@，属%@的人今天别做大决定", L(clashZ), L(clashZ)))
            doNow += a.yi.prefix(2).map { LF("宜%@", L($0)) }
            dont += a.ji.prefix(2).map { LF("忌%@", L($0)) }
        }

        let le = luckyElement(me, dayStem: ds)
        let nums = elementNumber[le]
        doNow.insert(LF("穿%@，幸运数字 %d、%d", L(elementColor[le]), nums[0], nums[1]), at: min(doNow.count, 2))
        let good = best.prefix(2).map { ($0, LF("宜%@", L(godDo[gods.firstIndex(of: $0.god)!]))) }
        let bad = worst.prefix(2).map { s -> (HourSlot, String) in
            let k = gods.firstIndex(of: s.god)!
            return (s, s.personalClash && godDont[k].isEmpty ? L("你的冲时：别拍板、别签字") : LF("忌%@", L(godDont[k])))
        }
        let hx = hexagram(date: date, personal: me.map { $0.yearBranch + $0.dayBranch + 2 } ?? (db + 1))
        var period: [String] = []
        if let me = me {
            let now = bazi(date: date, hour: 12)
            let ly = now.yearBranch, lm = now.month % 12
            if ly == me.yearBranch { period.append(LF("今年%@年是你的本命年：变动多，换工作、搬家、投资都多留一步。", gz(now.year))) }
            else if clash(ly, me.yearBranch) { period.append(LF("今年%@冲你的太岁：上半年容易有突发变动，大额支出提前留出预算。", gz(now.year))) }
            else if harm(ly, me.yearBranch) { period.append(LF("今年%@与你相害：人际上容易被误会，合作先小后大。", gz(now.year))) }
            else if harmony(ly, me.yearBranch) || trine(ly, me.yearBranch) { period.append(LF("今年%@与你相合：是往上走的一年，该争取的别客气。", gz(now.year))) }
            else { period.append(LF("今年%@对你影响平稳：成绩靠积累，别指望一夜翻身。", gz(now.year))) }
            if clash(lm, me.dayBranch) { period.append(L("本月月建冲你的日柱：这个月情绪和感情容易起伏，少熬夜、少吵架。")) }
            else if clash(lm, me.yearBranch) { period.append(L("本月冲你的年支：这个月出行、搬动的事多，证件和钱包看紧。")) }
            else if harmony(lm, me.dayBranch) || trine(lm, me.dayBranch) { period.append(L("本月与你日柱相合：这个月适合谈合作、谈感情，主动一点。")) }
            else { period.append(L("本月平稳：适合把一件长期的事往前推一大步。")) }
        }
        return Reading(tone: tone, headline: headline, reasons: reasons, doNow: Array(doNow.prefix(3)), dont: Array(dont.prefix(3)),
                       goodHours: Array(good), badHours: Array(bad), slots: slotsAll,
                       luckyDir: L(luckyDir(ds)), wealthDir: L(wealthDir(ds)), shaDir: L(shaDir(db)), clashZodiac: L(clashZ),
                       hexName: hx.name, hexVerdict: hx.verdict, hexLine: hx.line, period: period, personal: me != nil)
    }

    private static func score(_ s: HourSlot) -> Int {
        var v = s.good ? 2 : -2
        if s.personalClash { v -= 3 }
        v += s.personal
        if ["白虎", "天牢", "玄武"].contains(s.god) { v -= 1 }
        if ["金匮", "天德", "玉堂"].contains(s.god) { v += 1 }
        return v
    }

    /// 0 比劫 1 印（生我）2 食伤（我生）3 财（我克）4 官杀（克我）
    static func relation(_ me: Int, _ other: Int) -> Int {
        if me == other { return 0 }
        if (other + 1) % 5 == me { return 1 }
        if (me + 1) % 5 == other { return 2 }
        if (me + 2) % 5 == other { return 3 }
        return 4
    }
    static let relName = ["比劫", "印星", "食伤", "财星", "官杀"]
    static let relHeadline = [
        "今天比劫当令：有人跟你抢，钱也容易出去。别借钱、别凑单、别跟人比。",
        "今天印星护身：有贵人、有靠山。卡住的事今天去问人，答案就在别人嘴里。",
        "今天食伤旺：嘴快、手快。适合写东西、做表达；但开口前数三秒，别顶撞上级。",
        "今天财星到：钱跟着行动来。适合谈价、收款、做副业，但别冲动消费。",
        "今天官杀压身：压力大、被人管。别跟领导硬碰，把该交的交掉，晚上别加戏。",
    ]
    static let relDo = [["独立把一件事做完", "健身出汗泄掉火气"], ["请教前辈、找人帮忙", "读书、考证、学新东西"],
                        ["写方案、发作品", "做创意类工作"], ["谈价、催款、谈薪", "把账算清楚"], ["按时交差、守规矩", "早点下班回家"]]
    static let relDont = [["借钱给人、合伙投资", "跟人比较收入"], ["事事靠别人拍板"], ["当众顶撞上级", "在网上跟人争论"],
                          ["冲动下单大件", "借贷投机"], ["跟领导硬碰", "接下额外的活"]]
}
