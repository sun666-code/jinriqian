import SwiftUI
import AppKit

// MARK: - 问山人：随时可问的命理对话
// 接了 AI：本机先把你的命盘（四柱等，不含出生日期）、今天的黄历与时辰、以及这个问题需要的推算
// （比如择日候选、某个时辰的吉凶）算好，作为「山人的笔记」一起交给模型，模型据此灵活回答、可多轮追问。
// 没接 AI：山人用本机算法直接回答（择日 / 问某个时辰能不能做某事）。

// MARK: 择日

enum DayPicker {
    struct Act { let key: String; let label: String; let words: [String]; let officers: Set<Int>; let yi: String? }
    struct Pick { let date: Date; let score: Int; let why: [String] }

    // 建除序：建0 除1 满2 平3 定4 执5 破6 危7 成8 收9 开10 闭11
    static let acts: [Act] = [
        Act(key: "嫁娶", label: "结婚", words: ["结婚", "婚", "嫁", "娶", "领证", "订婚", "摆酒", "wedding", "marry", "marriage"], officers: [2, 4, 8, 10], yi: "聚会"),
        Act(key: "搬家", label: "搬家", words: ["搬家", "入宅", "乔迁", "搬", "move house", "moving"], officers: [1, 4, 8, 10], yi: "搬家"),
        Act(key: "开业", label: "开业", words: ["开业", "开张", "开店", "开工", "open a shop", "launch"], officers: [2, 8, 10], yi: "开业"),
        Act(key: "出行", label: "出行", words: ["出行", "旅行", "出差", "出门", "远行", "travel", "trip"], officers: [0, 8, 10], yi: "出行"),
        Act(key: "签约", label: "签约", words: ["签约", "合同", "签合同", "谈判", "contract", "sign"], officers: [4, 8], yi: "签约"),
        Act(key: "求职", label: "面试求职", words: ["面试", "求职", "入职", "跳槽", "interview", "job"], officers: [0, 4, 10], yi: "求职"),
        Act(key: "就医", label: "看病体检", words: ["手术", "体检", "看病", "就医", "surgery", "doctor"], officers: [1, 6], yi: "就医"),
        Act(key: "装修", label: "装修动土", words: ["装修", "动土", "renovat"], officers: [4, 8], yi: "装修"),
        Act(key: "理发", label: "理发", words: ["理发", "剪头", "haircut"], officers: [1, 3], yi: "理发"),
    ]
    static let general = Act(key: "办事", label: "办事", words: [], officers: [4, 8, 10], yi: nil)

    static func isDateQuestion(_ q: String) -> Bool {
        let l = q.lowercased()
        return ["哪天", "哪几天", "哪些日子", "什么日子", "哪个日子", "几号", "日子", "择日", "吉日", "良辰", "黄道吉日", "哪一天", "什么时候适合", "which day", "what day", "dates", "when should", "best day"].contains { l.contains($0) }
    }

    static func act(for q: String) -> Act {
        let l = q.lowercased()
        return acts.first { a in a.words.contains { l.contains($0) } } ?? general
    }

    static func range(for q: String, now: Date) -> (Date, Date, String) {
        let cal = Days.cal
        let today = Days.startOfDay(now)
        let y = cal.component(.year, from: today)
        func ymd(_ yy: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: yy, month: m, day: d))! }
        if q.contains("明年") || q.lowercased().contains("next year") { return (ymd(y + 1, 1, 1), ymd(y + 1, 12, 31), L("明年")) }
        if q.contains("今年") || q.contains("年内") || q.lowercased().contains("this year") {
            let end = ymd(y, 12, 31)
            let days = cal.dateComponents([.day], from: today, to: end).day ?? 0
            return (today, days < 30 ? Days.addDays(60, to: today) : end, L(days < 30 ? "今年剩下的日子（及往后两个月）" : "今年剩下的日子"))
        }
        if q.contains("下个月") || q.contains("下月") || q.lowercased().contains("next month") {
            let s = cal.date(byAdding: .month, value: 1, to: cal.date(from: cal.dateComponents([.year, .month], from: today))!)!
            return (s, Days.addDays(-1, to: cal.date(byAdding: .month, value: 1, to: s)!), L("下个月"))
        }
        if q.contains("这个月") || q.contains("本月") || q.lowercased().contains("this month") {
            let s = cal.date(from: cal.dateComponents([.year, .month], from: today))!
            return (today, Days.addDays(-1, to: cal.date(byAdding: .month, value: 1, to: s)!), L("这个月"))
        }
        if q.contains("下周") || q.contains("下星期") || q.lowercased().contains("next week") {
            let wd = (cal.component(.weekday, from: today) + 5) % 7
            let mon = Days.addDays(7 - wd, to: today)
            return (mon, Days.addDays(6, to: mon), L("下周"))
        }
        if q.contains("这周") || q.contains("本周") || q.lowercased().contains("this week") {
            let wd = (cal.component(.weekday, from: today) + 5) % 7
            return (today, Days.addDays(6 - wd, to: today), L("这周"))
        }
        return (today, Days.addDays(60, to: today), L("往后两个月"))
    }

    static func best(_ q: String, me: BaZi?, now: Date = Days.now, top: Int = 6) -> (Act, String, [Pick]) {
        let a = act(for: q)
        let (s, e, label) = range(for: q, now: now)
        var picks: [Pick] = []
        var d = s
        while d <= e {
            let al = Almanac.of(d)
            let di = Fortune.dayIndex(d)
            let db = ((di % 12) + 12) % 12
            var sc = al.score, why: [String] = [al.officerDisplay]
            if let yi = a.yi { if al.yi.contains(yi) { sc += 3; why.append(LF("宜%@", L(yi))) }; if al.ji.contains(yi) { sc -= 6 } }
            if a.officers.contains(al.officer) { sc += 3 }
            if al.officer == 6 || al.officer == 7 { sc -= 4 }               // 破日、危日不取
            if let me = me {
                if Fortune.clash(db, me.yearBranch) { sc -= 8 }
                if Fortune.clash(db, me.dayBranch) { sc -= 5 }
                if Fortune.harmony(db, me.dayBranch) { sc += 3; why.append(L("日支与你六合")) }
                else if Fortune.trine(db, me.dayBranch) { sc += 2; why.append(L("日支与你三合")) }
            }
            if a.key == "嫁娶" {
                let wd = Days.cal.component(.weekday, from: d)
                if wd == 1 || wd == 7 { sc += 1; why.append(L("周末")) }
            }
            if sc > 0 { picks.append(Pick(date: d, score: sc, why: why)) }
            d = Days.addDays(1, to: d)
        }
        let topPicks = picks.sorted { $0.score > $1.score }.prefix(top).sorted { $0.date < $1.date }
        return (a, label, Array(topPicks))
    }

    static func line(_ p: Pick) -> String {
        let al = Almanac.of(p.date)
        return Days.md(p.date) + " " + Days.weekday(p.date) + "（" + (I18n.en ? al.lunarFull : al.lunarText) + " " + al.dayGZ + L("日") + "）· " + p.why.joined(separator: L("、"))
    }
}

// MARK: 山人的笔记（给 AI 的上下文）与本地回答

enum HermitBrain {
    static func chart(_ s: Settings) -> BaZi? { s.birthOn ? s.birthDate.map { Fortune.bazi(date: $0, hour: s.birthHour) } : nil }

    static func system(_ s: Settings) -> String {
        var t = """
        你是「山人」——一位隐居山中、精通命理的老先生。你熟读：八字（四柱、十神、五行生克、旺衰、喜用、冲合刑害）、建除十二神与黄道黑道、\
        周易六十四卦与梅花易数、六爻纳甲、小六壬、紫微斗数基础、择日之法（避冲日、避破日危日，取成开定满等日，以日支与命主相合为佳）、塔罗大阿卡纳。
        回答方式：像面对面聊天一样灵活、具体。先给结论，再说依据，最后给一两条能做的建议。依据要引用下面「山人的笔记」里本机算好的数据，\
        不要自己编造日期、干支或节气；需要推荐日期时，只能从笔记里的「择日候选」中挑，并说明为什么。
        投资、医疗、法律类的事，只说「宜谨慎」并建议听专业人士的意见，不替人拍板。语气沉稳、有分寸、不吓人、不说绝对的话。
        用\(I18n.en ? "英文" : "简体中文")回答，一般 80～300 字；用户追问时可以展开。不要输出 Markdown 标题和表格，可以用「·」分条。
        """
        t += "\n\n" + HermitKnowledge.primer
        if let me = chart(s) {
            let c = LifeChart(date: s.birthDate!, hour: s.birthHour)
            t += "\n\n【求问者命盘】四柱：\(me.text)；属\(me.zodiac)；日主\(Almanac.stems[me.dayStem])\(Fortune.elements[me.element])，\(c.strong ? "身强" : "身弱")；"
            t += "五行：木\(c.counts[0]) 火\(c.counts[1]) 土\(c.counts[2]) 金\(c.counts[3]) 水\(c.counts[4])；喜用：\(c.likes.map { Fortune.elements[$0] }.joined(separator: "、"))；"
            t += "本命卦：\(c.hexName)；本命四象：\(c.symbol)。（出生日期不提供）"
        } else {
            t += "\n\n【求问者命盘】未提供生辰，只能按当日黄历推算，可以提醒对方去设置里填生辰。"
        }
        return t
    }

    /// 今天的黄历与时辰 + 这个问题需要的本地推算
    static func notes(_ q: String, _ s: Settings, now: Date = Days.now) -> String {
        let m = chart(s)
        let a = Almanac.of(now)
        let di = Fortune.dayIndex(now)
        let db = ((di % 12) + 12) % 12
        let r = Fortune.reading(for: now, birth: s.birthOn ? s.birthDate : nil, birthHour: s.birthHour)
        var t = "【山人的笔记】\n今天：\(Days.key(now)) \(Days.weekday(now))，农历\(a.lunarText)，\(a.yearGZ)年 \(a.dayGZ)日，\(a.officerName)，宜：\(a.yi.joined(separator: "、"))，忌：\(a.ji.joined(separator: "、"))，冲\(Almanac.animals[(db + 6) % 12])。现在 \(Days.hm(now))。\n"
        t += "今日断语：\(r.headline)\n十二时辰："
        t += r.slots.map { "\($0.range)\(Almanac.branches[$0.branch])时\($0.god)\($0.good ? "吉" : "凶")\($0.personalClash ? "（冲命主）" : "")" }.joined(separator: "；")
        if DayPicker.isDateQuestion(q) {
            let (act, label, picks) = DayPicker.best(q, me: m, now: now, top: 8)
            t += "\n择日候选（\(label)·\(act.label)，已按命主排除冲日、破日、危日，按得分排序取前 8 个）：\n"
            t += picks.isEmpty ? "这个范围内没有合适的日子。" : picks.map { "· " + DayPicker.line($0) }.joined(separator: "\n")
        } else {
            let o = Oracle.ask(q, now: now, birth: s.birthOn ? s.birthDate : nil, birthHour: s.birthHour)
            t += "\n本机起课（供参考）：\(o.title) 依据：\(o.reasons.joined(separator: "；"))。"
            t += "多法合参：" + o.angles.map { "\($0.method)【\($0.result)】\($0.verdict)" }.joined(separator: "；")
            if let b = o.better { t += "。同日更好的时辰：\(b.range)（\(b.name)·\(b.god)）" }
        }
        return t
    }

    /// 没接 AI 时，山人用本机算法回答
    static func localAnswer(_ q: String, _ s: Settings, now: Date = Days.now) -> String {
        if DayPicker.isDateQuestion(q) {
            let (act, label, picks) = DayPicker.best(q, me: chart(s), now: now)
            if picks.isEmpty { return LF("%@里，适合%@的日子山人没挑出来。换个时间段再问我。", label, L(act.label)) }
            var t = LF("%@里，按你的八字，%@可以看这几天：", label, L(act.label)) + "\n"
            t += picks.map { "· " + DayPicker.line($0) }.joined(separator: "\n")
            t += "\n" + L(chart(s) == nil ? "（还没填生辰，只按黄历挑；填了生辰会避开冲你的日子。）" : "已避开冲你属相、冲你日柱的日子，以及破日、危日。")
            return t
        }
        let o = Oracle.ask(q, now: now, birth: s.birthOn ? s.birthDate : nil, birthHour: s.birthHour)
        var t = o.title + "\n"
        t += L("依据：") + o.reasons.prefix(3).joined(separator: L("；")) + "\n"
        t += o.angles.prefix(3).map { "· " + $0.method + "【" + $0.result + "】" + $0.verdict }.joined(separator: "\n")
        if let r = o.remedies.first { t += "\n" + L("山人建议：") + r }
        return t
    }
}

// MARK: 山人（侧栏上那颗墨珠）

struct HermitOrb: View {
    var size: CGFloat = 46
    var active = false
    @Environment(\.pal) private var p
    @State private var breathe = false
    @State private var spin = false
    var body: some View {
        ZStack {
            Circle().fill(Mystic.brass.opacity(breathe ? 0.30 : 0.10)).frame(width: size + 12, height: size + 12).blur(radius: 6)
            Circle().fill(RadialGradient(colors: [Color(hex: 0x2A2C38), Color(hex: 0x0B0C12)], center: .init(x: 0.35, y: 0.3), startRadius: 1, endRadius: size * 0.7))
                .frame(width: size, height: size)
            Circle().strokeBorder(Mystic.brass.opacity(0.85), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .frame(width: size - 4, height: size - 4)
                .rotationEffect(.degrees(spin ? 360 : 0))
            Text(I18n.en ? "Ask" : "山").font(I18n.en ? Typo.ui(size * 0.26, .heavy) : Typo.song(size * 0.42, bold: true))
                .foregroundColor(Color(hex: 0xEDE6D3))
        }
        .scaleEffect(active ? 1.08 : 1)
        .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
        .onAppear {
            guard !Snap.active else { breathe = true; return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { breathe = true }
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) { spin = true }
        }
    }
}

// MARK: 对话抽屉

struct HermitChat: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    @State private var draft = ""
    @State private var busy = false
    @State private var thinking = false

    private var aiReady: Bool {
        let s = store.data.settings
        return s.aiOn && !s.aiEndpoint.isEmpty && !s.aiModel.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HermitOrb(size: 34)
                Text(L("问山人")).font(Typo.song(17, bold: true)).foregroundColor(p.ink)
                Spacer()
                if !store.data.chat.isEmpty {
                    Button(action: { withAnimation { store.data.chat = []; store.save() } }) {
                        Image(systemName: "trash").font(.system(size: 11, weight: .semibold)).foregroundColor(p.ink2)
                            .frame(width: 28, height: 28).background(Circle().fill(p.glassFill2))
                    }.buttonStyle(PressStyle())
                }
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundColor(p.ink)
                        .frame(width: 28, height: 28).background(Circle().fill(p.glassFill2))
                }.buttonStyle(PressStyle()).demoTarget("chat.close")
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 8)

            messages

            HStack(spacing: 8) {
                Field(placeholder: L("有事问山人，直说"), text: $draft, size: 13, onSubmit: send)
                    .demoTarget("chat.input")
                    .onDemo { c in
                        if case .text("chat.input", let v) = c { draft = v }
                        if case .act("chat.send") = c { send() }
                    }
                Button(action: send) {
                    Image(systemName: busy ? "ellipsis" : "arrow.up").font(.system(size: 12, weight: .bold)).foregroundColor(p.onAccent)
                        .frame(width: 30, height: 30).background(Circle().fill(p.accent))
                        .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                }.buttonStyle(PressStyle()).disabled(busy).demoTarget("chat.send")
            }
            .padding(.leading, 14).padding(.trailing, 6).frame(height: 44)
            .background(Capsule().fill(p.glassFill2))
            .overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
            .padding(12)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous).fill(p.dark ? Color(hex: 0x232326, alpha: 0.98) : Color.white.opacity(0.98))
                RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(p.hairline, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(p.dark ? 0.45 : 0.12), radius: 20, x: 0, y: 8)
        )
        .padding(8)
    }

    @ViewBuilder
    private var messages: some View {
        let list = store.data.chat
        if list.isEmpty && !busy {
            VStack(spacing: 10) {
                Spacer()
                HermitOrb(size: 64)
                Text(L("山人在。有事直说。")).font(Typo.song(16, bold: true)).foregroundColor(p.ink)
                Text(L(store.data.settings.birthOn ? "山人已看过你的八字。" : "还没填生辰，山人只能按黄历说。")).font(Typo.ui(11)).foregroundColor(p.ink3)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if Snap.active {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    VStack(spacing: 10) { ForEach(list.suffix(4)) { m in bubble(m) } }
                        .padding(.horizontal, 12)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .clipped()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(list) { m in bubble(m).id(m.id) }
                        if busy {
                            HStack(spacing: 6) {
                                HermitOrb(size: 22)
                                Text(L(thinking ? "山人在推演…" : "山人掐指一算…")).font(Typo.song(12.5)).foregroundColor(p.ink2)
                                Spacer()
                            }
                            .id("busy")
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 12).padding(.bottom, 6)
                }
                .onAppear { DispatchQueue.main.async { proxy.scrollTo("bottom", anchor: .bottom) } }
                .onChange(of: list.count) { _ in DispatchQueue.main.async { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } } }
                .onChange(of: list.last?.text.count ?? 0) { _ in proxy.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: busy) { _ in DispatchQueue.main.async { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } } }
            }
        }
    }

    private func bubble(_ m: ChatMsg) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if m.fromUser { Spacer(minLength: 40) } else { HermitOrb(size: 24).padding(.top, 2) }
            VStack(alignment: .leading, spacing: 4) {
                Text(m.text)
                    .font(m.fromUser ? Typo.ui(12.5, .medium) : Typo.ui(12.5))
                    .foregroundColor(m.fromUser ? p.onAccent : p.ink)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 11).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(m.fromUser ? p.accent : p.glassFill2)
            )
            if !m.fromUser { Spacer(minLength: 24) }
        }
        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
    }

    private func send() {
        let q = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !busy else { return }
        draft = ""
        let s = store.data.settings
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { store.data.chat.append(ChatMsg(fromUser: true, text: q)) }
        busy = true
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        if aiReady && Keychain.hasKey {
            var msgs: [[String: String]] = [["role": "system", "content": HermitBrain.system(s)],
                                            ["role": "system", "content": HermitBrain.notes(q, s)]]
            for m in store.data.chat.dropLast().suffix(10) where !m.text.isEmpty {
                msgs.append(["role": m.fromUser ? "user" : "assistant", "content": m.text])
            }
            msgs.append(["role": "user", "content": q])
            let reply = ChatMsg(fromUser: false, text: "")
            var placed = false
            thinking = false
            AIClient.stream(msgs, base: s.aiEndpoint, model: s.aiModel, maxTokens: 4000, onThinking: { thinking = true }, onText: { t in
                if !placed { placed = true; busy = false; thinking = false; add(reply, haptic: false) }
                if let i = store.data.chat.firstIndex(where: { $0.id == reply.id }) { store.data.chat[i].text = t }
            }) { r in
                busy = false; thinking = false
                switch r {
                case .success: store.save(); NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                case .failure(let e):
                    if let i = store.data.chat.firstIndex(where: { $0.id == reply.id }) { store.data.chat.remove(at: i) }
                    add(ChatMsg(fromUser: false, text: HermitBrain.localAnswer(q, s) + "\n\n" + L("（AI 暂时连不上：") + e.localizedDescription + L("。先用本机推算回答。）"), local: true))
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                busy = false
                add(ChatMsg(fromUser: false, text: HermitBrain.localAnswer(q, s), local: true))
            }
        }
    }

    private func add(_ m: ChatMsg, haptic: Bool = true) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            store.data.chat.append(m)
            if store.data.chat.count > 60 { store.data.chat.removeFirst(store.data.chat.count - 60) }
        }
        store.save()
        if haptic { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
    }

    private func close() { withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { ui.chatOpen = false } }
}
