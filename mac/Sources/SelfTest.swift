import Foundation

// MARK: - 自检（构建脚本会运行：JinRiQian --selftest）

enum SelfTest {
    static func run() -> Bool {
        var ok = true
        func check(_ name: String, _ cond: Bool) {
            print((cond ? "✅ " : "❌ ") + name)
            if !cond { ok = false }
        }
        let bj = Days.bjCal
        let d759 = bj.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 7, minute: 59))!
        let d800 = bj.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 8, minute: 0))!
        check("北京时间 7:59 仍是昨天的签日", Days.qianDay(at: d759) == "2026-11-04")
        check("北京时间 8:00 切到今天的签日", Days.qianDay(at: d800) == "2026-11-05")

        let a = Days.cal.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 12))!
        check("2000-01-01 为戊午日", Almanac.of(a).dayGZ == "戊午")
        let b = Days.cal.date(from: DateComponents(year: 1949, month: 10, day: 1, hour: 12))!
        check("1949-10-01 为甲子日", Almanac.of(b).dayGZ == "甲子")
        check("2026 立春为 2 月 4 日", Almanac.jieDay(year: 2026, month: 2) == 4)
        check("2026 立冬为 11 月 7 日", Almanac.jieDay(year: 2026, month: 11) == 7)
        let c = Days.cal.date(from: DateComponents(year: 2026, month: 2, day: 17, hour: 12))!
        let ca = Almanac.of(c)
        check("2026-02-17 为农历正月初一（\(ca.lunarText)，\(ca.yearGZ)\(ca.zodiac)年）", ca.lunarMonth == 1 && ca.lunarDay == 1 && ca.yearGZ == "丙午")

        let a1 = (0..<50).map { Draw.lotNo(seed: "u1", day: "2026-11-05", index: $0) }
        let a2 = (0..<50).map { Draw.lotNo(seed: "u1", day: "2026-11-05", index: $0) }
        check("同一用户同一签日同一张牌结果固定", a1 == a2)
        check("无限牌堆：前 50 张覆盖签库大部分签", Set(a1).count >= 15)
        check("不同签日会换牌", (0..<50).map { Draw.lotNo(seed: "u1", day: "2026-11-06", index: $0) } != a1)
        check("每支签都有英文", LotLibrary.builtin.allSatisfy { (LotLibrary.builtinEn[$0.no] ?? LotLibrary.hexEn[$0.no]) != nil })
        let missing = I18nTable.checkCoverage()
        check("界面文案英文覆盖（缺 \(missing.count) 条）" + (missing.isEmpty ? "" : "：" + missing.prefix(5).joined(separator: " / ")), missing.isEmpty)

        let now = Days.cal.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 10))!
        let p1 = NLParser.parse("明天下午3点 开会", now: now)
        check("识别「明天下午3点 开会」", p1.title == "开会" && Days.key(p1.day) == "2026-11-06" && p1.time.map(Days.hm) == "15:00")
        let p2 = NLParser.parse("周五晚上8点半 聚餐", now: now)
        check("识别「周五晚上8点半 聚餐」", p2.title == "聚餐" && Days.key(p2.day) == "2026-11-06" && p2.time.map(Days.hm) == "20:30")
        let p3 = NLParser.parse("11月20日 出差杭州", now: now)
        check("识别「11月20日 出差杭州」", Days.key(p3.day) == "2026-11-20" && p3.title == "出差杭州")
        let p4 = NLParser.parse("下周一 9:15 体检", now: now)
        check("识别「下周一 9:15 体检」", Days.key(p4.day) == "2026-11-09" && p4.time.map(Days.hm) == "09:15")

        let bz = Fortune.bazi(date: Days.cal.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 12))!, hour: 12)
        check("八字：2000-01-01 午时 = 己卯 丙子 戊午 戊午（\(bz.text)）", bz.text == "己卯 丙子 戊午 戊午")
        let r = Fortune.reading(for: now, birth: Days.cal.date(from: DateComponents(year: 1996, month: 3, day: 8, hour: 12)), birthHour: 10)
        check("今日断语：有一句话、吉凶时辰各 2 个、今日一卦", !r.headline.isEmpty && r.goodHours.count == 2 && r.badHours.count == 2 && !r.hexName.isEmpty)
        check("六十四卦断语齐全", HexVerdicts.zh.count == 64 && HexVerdicts.en.count == 64)
        // 大原则：换了生辰，推算必须跟着变
        let bA = Days.cal.date(from: DateComponents(year: 1990, month: 5, day: 20, hour: 12))!
        let bB = Days.cal.date(from: DateComponents(year: 1984, month: 11, day: 2, hour: 12))!
        var diffDays = 0
        for i in 0..<10 {
            let d = Days.addDays(i, to: now)
            let x = Fortune.reading(for: d, birth: bA, birthHour: 8), y = Fortune.reading(for: d, birth: bB, birthHour: 20)
            if x.headline != y.headline || x.hexName != y.hexName || x.goodHours.map({ $0.0.branch }) != y.goodHours.map({ $0.0.branch }) { diffDays += 1 }
        }
        check("换生辰后断语会变（10 天里 \(diffDays) 天不同）", diffDays >= 8)
        let qa = Oracle.ask("下午3点去打麻将可以吗？", now: now, birth: bA, birthHour: 8)
        let qb = Oracle.ask("下午3点去打麻将可以吗？", now: now, birth: bB, birthHour: 20)
        check("问事：识别时间与事项（\(qa.title)）", Days.hm(qa.when) == "15:00" && qa.topic == "博弈" && qa.title.contains("打牌") && !qa.remedies.isEmpty)
        check("问事：多角度合参 5 种方法（八字时辰/梅花/六爻/小六壬/塔罗）", qa.angles.count == 5)
        let ly1 = Methods.liuYao(question: "测试", when: now, seed: "a"), ly2 = Methods.liuYao(question: "测试", when: now, seed: "a")
        check("六爻同问同时同命结果固定", ly1.main == ly2.main && ly1.moving == ly2.moving)
        check("问事：换生辰后结论或理由不同", qa.level != qb.level || qa.reasons != qb.reasons)
        let s1 = (0..<30).map { Draw.lotNo(seed: "u|甲子 乙丑 丙寅 丁卯", day: "2026-11-05", index: $0) }
        let s2 = (0..<30).map { Draw.lotNo(seed: "u|庚午 辛未 壬申 癸酉", day: "2026-11-05", index: $0) }
        check("换生辰后牌堆不同", s1 != s2)
        let best = Almanac.bestDays(for: "搬家", from: now)
        check("择日给出 5 天且都不是忌日", best.count == 5 && best.allSatisfy { !$0.ji.contains("搬家") })
        check("内置签库 88 支（原创 24 + 六十四卦签），编号连续", LotLibrary.builtin.count == 88 && LotLibrary.builtin.enumerated().allSatisfy { $0.element.no == $0.offset + 1 && $0.element.todo.count == 3 && $0.element.avoid.count == 3 })
        // v10 山人
        let qi = Oracle.ask("明天上午买基金可以吗？", now: now, birth: bA, birthHour: 8)
        let qh = Oracle.ask("下周去医院做手术行吗", now: now, birth: bA, birthHour: 8)
        check("问山人：钱、病只说「慎」，并提示以专业意见为准", qi.level == .careful && qh.level == .careful && qi.remedies.first?.contains("专业") == true)
        check("时辰轮：时间换算（11:20 = 午时，23:30 = 子时，0 点在正上方）", DialMath.branch(11 * 60 + 20) == 6 && DialMath.branch(23 * 60 + 30) == 0 && abs(DialMath.deg(0)) < 0.001)
        let ts = Store(persist: false)
        let tr = ts.addReminder(title: "测试", day: Days.todayKey, time: Days.now)
        ts.retime(id: tr.id, minuteOfDay: 17 * 60 + 35)
        let rt = ts.data.reminders.first!.time!
        check("时辰轮：拖动待办改时间（→ 17:35，日期不变）", Days.hm(rt) == "17:35" && ts.data.reminders.first!.day == Days.todayKey)
        // 第二轮：AI 一键接入、命理总批
        let dp = AIPresets.find("deepseek")!
        check("AI 一键接入：DeepSeek 自动选 flash，过滤掉向量模型", AIPresets.pick(["deepseek-v4-pro", "deepseek-flash", "text-embedding"], preset: dp) == "deepseek-flash"
              && AIPresets.chatModels(["bge-m3", "qwen-plus"]) == ["qwen-plus"])
        var st = Settings(); st.aiEndpoint = "https://api.moonshot.cn/v1"
        check("AI 一键接入：按地址认出服务商（Kimi）", AIPresets.current(st).id == "kimi" && AIPresets.current(Settings()).id == "deepseek")
        let lc = LifeChart(date: bA, hour: 8), lc2 = LifeChart(date: bB, hour: 20)
        check("命理总批：五行共 8 个字、有 5 条批语、换生辰结论不同", lc.counts.reduce(0, +) == 8 && lc.verdicts.count == 5 && lc.verdicts != lc2.verdicts)
        check("命理总批：发给 AI 的内容不含出生日期", !lc.aiPrompt.contains(Days.key(bA)) && !lc.aiPrompt.contains(String(Days.cal.component(.year, from: bA))))
        // 第三轮：问山人对话、择日
        var cs = Settings(); cs.birthOn = true; cs.birthDate = bA; cs.birthHour = 8
        let now2026 = Days.cal.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 21))!
        let (wa, _, wp) = DayPicker.best("按照我的生辰八字，今年适合结婚的日子有哪些？", me: Fortune.bazi(date: bA, hour: 8), now: now2026)
        let meB = Fortune.bazi(date: bA, hour: 8)
        check("问山人：「今年适合结婚的日子」识别为择日，给出日子且都不冲命主", DayPicker.isDateQuestion("今年适合结婚的日子有哪些") && wa.key == "嫁娶" && !wp.isEmpty
              && wp.allSatisfy { let db = ((Fortune.dayIndex($0.date) % 12) + 12) % 12; return !Fortune.clash(db, meB.yearBranch) && !Fortune.clash(db, meB.dayBranch) })
        let notes = HermitBrain.notes("今年适合结婚的日子有哪些", cs, now: now2026)
        check("问山人：给 AI 的笔记带择日候选与今日时辰，系统提示不含出生日期", notes.contains("择日候选") && notes.contains("十二时辰")
              && !HermitBrain.system(cs).contains(Days.key(bA)) && HermitBrain.system(cs).contains(meB.text))
        check("问山人：本机回答「打麻将」给出吉凶与多法合参", HermitBrain.localAnswer("下午3点去打麻将可以吗？", cs, now: now2026).contains("梅花易数"))
        return ok
    }
}
