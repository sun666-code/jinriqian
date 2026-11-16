import Foundation

// MARK: - 问事：问一件具体的事（如“下午3点去打麻将可以吗？”），本地起卦给出吉凶、原因、更好的时间和破解办法
// 推算依据：所问时辰的黄黑道 + 该时辰与命主日支/年支的冲合害 + 当日宜忌 + 当日与命主的冲合
// + 以问句字数与时辰起梅花易数卦。换了生辰，结果会跟着变。

struct OracleAnswer {
    enum Level { case great, good, even, bad, careful }
    let level: Level
    let question: String
    let when: Date
    let topic: String
    let title: String
    let reasons: [String]
    let remedies: [String]
    let better: HourSlot?
    let hexName: String
    let hexVerdict: String
    let personal: Bool
    var angles: [Angle] = []

    var levelText: String {
        switch level {
        case .great: return L("大吉")
        case .good: return L("吉")
        case .even: return L("平")
        case .bad: return L("凶")
        case .careful: return L("慎")
        }
    }
}

enum Oracle {
    struct Topic {
        let key: String
        let words: [String]
        let act: String?          // 对应黄历事项
        let goodGods: [String]
        let badGods: [String]
        let tipGood: String
        let tipBad: String
    }

    static let topics: [Topic] = [
        Topic(key: "博弈", words: ["麻将", "打牌", "斗地主", "德州", "赌", "彩票", "掼蛋", "牌局", "mahjong", "poker", "cards", "lottery"], act: "理财",
              goodGods: ["金匮", "天德", "青龙"], badGods: ["玄武", "白虎", "天牢"],
              tipGood: "手气在你这边，但赢到预期就收手，别恋战", tipBad: "先定好输赢上限，输到一半立刻离场"),
        Topic(key: "考试", words: ["考试", "面试", "答辩", "考", "笔试", "演讲", "汇报", "exam", "interview", "test", "presentation"], act: "求职",
              goodGods: ["司命", "玉堂", "明堂"], badGods: ["朱雀", "天刑", "勾陈"],
              tipGood: "文星照着你，第一题答好就稳了", tipBad: "提前 30 分钟到场，考前别跟人争论，先做最有把握的题"),
        Topic(key: "约会", words: ["约会", "表白", "相亲", "见面", "求婚", "约", "date", "confess", "meet"], act: "聚会",
              goodGods: ["玉堂", "青龙", "天德"], badGods: ["朱雀", "白虎", "勾陈"],
              tipGood: "气氛会很好，主动开口的人赢", tipBad: "别翻旧账、别聊前任，见面地点选安静一点的"),
        Topic(key: "出行", words: ["出差", "旅行", "开车", "出门", "飞", "高铁", "自驾", "回家", "trip", "drive", "travel", "flight"], act: "出行",
              goodGods: ["青龙", "明堂", "天德"], badGods: ["白虎", "天牢", "玄武"],
              tipGood: "一路顺，路上可能还有意外收获", tipBad: "提前出门、证件钱包检查两遍，开车别抢道"),
        Topic(key: "签约", words: ["签", "合同", "谈判", "谈", "报价", "contract", "sign", "negotiate", "deal"], act: "签约",
              goodGods: ["天德", "金匮", "明堂"], badGods: ["天牢", "天刑", "朱雀"],
              tipGood: "对方会让步，条件可以开高一点", tipBad: "条款逐条看完再签，口头承诺一律写进合同"),
        Topic(key: "投资", words: ["股票", "基金", "投资", "买币", "理财", "加仓", "买房", "stock", "invest", "crypto", "buy"], act: "理财",
              goodGods: ["金匮", "天德"], badGods: ["玄武", "白虎", "天牢"],
              tipGood: "可以小仓位试，别一把梭", tipBad: "今天只看不动，冲动下单最容易亏"),
        Topic(key: "就医", words: ["医院", "手术", "体检", "看病", "牙", "doctor", "hospital", "surgery"], act: "就医",
              goodGods: ["天德", "青龙", "司命"], badGods: ["白虎", "天刑"],
              tipGood: "遇到的医生靠谱，问题说清楚", tipBad: "能改期的检查改期，非做不可就提前把病历整理好"),
        Topic(key: "官司", words: ["官司", "起诉", "律师", "法院", "仲裁", "打官司", "lawsuit", "court", "lawyer", "sue"], act: nil,
              goodGods: ["天德", "明堂"], badGods: ["天刑", "天牢", "朱雀"],
              tipGood: "材料备齐、按律师意见走", tipBad: "先别情绪化表态，一切以律师意见为准"),
    ]

    /// 钱、病、官司：山人不打包票，最多说「慎」
    static let cautiousTopics: Set<String> = ["投资", "就医", "官司"]

    static let general = Topic(key: "办事", words: [], act: nil, goodGods: ["青龙", "天德", "金匮"], badGods: ["白虎", "天牢", "玄武"],
                               tipGood: "放手去做，时机站在你这边", tipBad: "能推就推，不能推就带上可靠的人一起")

    static let topicPhrase = ["博弈": "打牌", "考试": "考试", "约会": "约会", "出行": "出门", "签约": "签约谈判", "投资": "投资", "就医": "看病", "官司": "打官司", "办事": "办这件事"]

    static func topic(for q: String) -> Topic {
        let lower = q.lowercased()
        return topics.first { t in t.words.contains { lower.contains($0) } } ?? general
    }

    static let auspicious: Set<String> = ["乾为天", "地天泰", "火天大有", "雷地豫", "风雷益", "地风升", "火地晋", "泽地萃", "水地比", "地泽临", "雷水解", "兑为泽", "地雷复", "风火家人", "风山渐"]
    static let ominous: Set<String> = ["天地否", "天水讼", "泽水困", "坎为水", "水山蹇", "山地剥", "地火明夷", "水雷屯", "泽风大过", "火水未济", "山风蛊", "雷山小过"]

    static func ask(_ q: String, now: Date = Days.now, birth: Date?, birthHour: Int) -> OracleAnswer {
        let parsed = NLParser.parse(q, now: now)
        let when = parsed.time ?? (parsed.ranges.isEmpty ? now : Days.cal.date(bySettingHour: 12, minute: 0, second: 0, of: parsed.day)!)
        let t = topic(for: q)
        let me: BaZi? = birth.map { Fortune.bazi(date: $0, hour: birthHour) }
        let di = Fortune.dayIndex(when)
        let db = di % 12, ds = di % 10
        let a = Almanac.of(when)
        let slots = Fortune.slots(dayBranch: db, me: me)
        let hb = ((Days.cal.component(.hour, from: when) + 1) / 2) % 12
        let slot = slots.first { $0.branch == hb }!

        var score = 0
        var reasons: [String] = []
        // 时辰神煞
        if t.goodGods.contains(slot.god) { score += 3; reasons.append(LF("%@（%@）正逢%@，最利%@", slot.range, slot.name, L(slot.god), L(t.key))) }
        else if t.badGods.contains(slot.god) { score -= 3; reasons.append(LF("%@（%@）撞上%@，%@最怕这个时辰", slot.range, slot.name, L(slot.god), L(t.key))) }
        else { score += slot.good ? 1 : -1; reasons.append(LF("%@（%@）是%@，%@", slot.range, slot.name, L(slot.god), L(slot.good ? "黄道吉时" : "黑道时辰"))) }
        // 当日宜忌
        if let act = t.act {
            if a.ji.contains(act) { score -= 2; reasons.append(LF("%@ %@忌%@", Days.md(when), a.officerDisplay, L(act))) }
            else if a.yi.contains(act) { score += 2; reasons.append(LF("%@ %@宜%@", Days.md(when), a.officerDisplay, L(act))) }
        }
        // 命主
        if let me = me {
            if slot.personalClash { score -= 3; reasons.append(LF("这个时辰冲你的属相（%@），是你今天最弱的时候", L(me.zodiac))) }
            if Fortune.harmony(hb, me.dayBranch) || Fortune.trine(hb, me.dayBranch) { score += 2; reasons.append(LF("时支%@与你的日支%@相合，状态在线", Almanac.branches[hb], Almanac.branches[me.dayBranch])) }
            if Fortune.clash(hb, me.dayBranch) { score -= 2; reasons.append(LF("时支%@冲你的日支%@，容易心浮气躁", Almanac.branches[hb], Almanac.branches[me.dayBranch])) }
            if Fortune.clash(db, me.yearBranch) { score -= 1; reasons.append(L("当天冲你的属相，整体运势偏弱")) }
            let rel = Fortune.relation(me.element, Fortune.stemElement(ds))
            if t.key == "博弈" || t.key == "投资" {
                if rel == 3 { score += 2; reasons.append(L("今天财星到你，偏财有戏")) }
                if rel == 0 { score -= 2; reasons.append(L("今天比劫夺财，钱容易被别人赢走")) }
            }
            if t.key == "考试" && rel == 1 { score += 2; reasons.append(L("今天印星护身，适合考试和面试")) }
        }
        // 起卦：问句字数 + 时辰
        let n = q.count
        let up = (n - 1 + 8) % 8, low = (n + hb) % 8
        let hex = Fortune.hexNames[up][low]
        let hv = I18n.en ? (HexVerdicts.en[hex] ?? "") : (HexVerdicts.zh[hex] ?? "")

        // 多角度合参：八字时辰（上面）+ 梅花易数 + 六爻 + 小六壬 + 塔罗
        let seed = me?.text ?? "nobirth"
        let bz = max(-2, min(2, score / 2))
        var angles: [Angle] = [Angle(method: L("八字·时辰"), symbol: "clock", result: slot.name + " · " + L(slot.god),
                                     verdict: reasons.first ?? "", score: bz)]
        let mh = auspicious.contains(hex) ? 1 : (ominous.contains(hex) ? -1 : 0)
        angles.append(Angle(method: L("梅花易数"), symbol: "leaf", result: hex, verdict: hv, score: mh))
        let ly = Methods.liuYao(question: q, when: when, seed: seed)
        angles.append(ly.angle)
        let xl = Methods.xiaoLiuRen(when: when)
        angles.append(xl)
        let tr = Methods.tarotCard(question: q, when: when, seed: seed)
        angles.append(tr)
        score += mh + ly.angle.score + xl.score + tr.score

        let raw: OracleAnswer.Level = score >= 4 ? .great : (score >= 1 ? .good : (score >= -1 ? .even : .bad))
        let cautious = cautiousTopics.contains(t.key)
        let level: OracleAnswer.Level = cautious ? .careful : raw

        // 更好的时辰（同一天，7 点到 23 点）
        func s2(_ s: HourSlot) -> Int {
            var v = t.goodGods.contains(s.god) ? 3 : (t.badGods.contains(s.god) ? -3 : (s.good ? 1 : -1))
            if s.personalClash { v -= 3 }
            return v + s.personal
        }
        let waking = slots.filter { (7...22).contains($0.start) }
        let better = waking.filter { $0.branch != hb }.max { s2($0) < s2($1) }

        var remedies: [String] = []
        let le = Fortune.luckyElement(me, dayStem: ds)
        if level == .bad || level == .even || (cautious && (raw == .bad || raw == .even)) {
            if let b = better, s2(b) > s2(slot) { remedies.append(LF("改到 %@（%@·%@）更好", b.range, b.name, L(b.god))) }
            remedies.append(LF("出门先朝%@（喜神方）走一段，坐的时候面朝%@", L(Fortune.luckyDir(ds)), L(Fortune.luckyDir(ds))))
            remedies.append(LF("穿%@，身上带个数字 %d 的小物件", L(Fortune.elementColor[le]), Fortune.elementNumber[le][0]))
            remedies.append(L(t.tipBad))
            remedies.append(LF("避开%@方向（今日煞方）", L(Fortune.shaDir(db))))
        } else {
            remedies.append(L(t.tipGood))
            remedies.append(LF("坐位面朝%@（财神方），穿%@更旺", L(Fortune.wealthDir(ds)), L(Fortune.elementColor[le])))
        }

        let whenText = Days.relative(when) + (parsed.time != nil ? " " + Days.hm(when) : "")
        let what = L(topicPhrase[t.key] ?? "办这件事")
        let title: String
        switch level {
        case .great: title = LF("%@ %@：大吉，放心去。", whenText, what)
        case .good: title = LF("%@ %@：吉，可以去。", whenText, what)
        case .even: title = LF("%@ %@：平，能去但别贪。", whenText, what)
        case .bad: title = LF("%@ %@：凶，不建议。", whenText, what)
        case .careful: title = LF("%@ %@：宜谨慎。山人只看时辰，不替你拿主意。", whenText, what)
        }
        if cautious { remedies.insert(L("钱、病、官司这类事，请以专业人士的意见为准"), at: 0) }
        return OracleAnswer(level: level, question: q, when: when, topic: t.key, title: title, reasons: Array(reasons.prefix(4)),
                            remedies: Array(remedies.prefix(4)), better: better, hexName: hex, hexVerdict: hv, personal: me != nil, angles: angles)
    }
}
