import SwiftUI

// MARK: - 命理总批：按生辰算出的「一辈子的底色」
// 本地推算：四柱、五行分布、日主强弱、喜用、本命四象、本命卦（梅花易数起于生辰）。
// 可选「让 AI 细批」：只发送四柱与推算结论，不发送出生日期；需用户自己接入 AI 后手动点。

struct LifeChart {
    let bz: BaZi
    let counts: [Int]          // 木火土金水 各几个（八个字）
    let me: Int                // 日主五行
    let strong: Bool
    let likes: [Int]           // 喜用五行
    let symbol: String         // 本命四象
    let symbolDir: String
    let hexName: String
    let upper: Int             // 上卦序号（乾兑离震巽坎艮坤）

    static let branchElement = [4, 2, 0, 0, 2, 1, 1, 2, 3, 3, 2, 4]   // 子丑寅卯辰巳午未申酉戌亥
    static let trigramNames = ["乾", "兑", "离", "震", "巽", "坎", "艮", "坤"]
    static let trigramNature = ["刚健自强，天生要做主", "善言悦人，人缘是你的财", "明亮好学，靠眼光与表达出头", "果敢好动，机会靠抢",
                                "灵活善谋，润物细无声", "深沉多思，越难越清醒", "稳重守成，慢慢积累成山", "包容厚德，后劲最足"]
    static let elementNature = ["木：心软有主见，爱成长、怕被困住", "火：热情外放，来得快也去得快", "土：可靠务实，答应的事一定做到",
                                "金：讲原则、有决断，刀子嘴", "水：聪明善变，想得多、看得远"]

    init(date: Date, hour: Int) {
        bz = Fortune.bazi(date: date, hour: hour)
        var c = [0, 0, 0, 0, 0]
        for g in [bz.year, bz.month, bz.day, bz.hour] {
            c[Fortune.stemElement(((g % 10) + 10) % 10)] += 1
            c[LifeChart.branchElement[((g % 12) + 12) % 12]] += 1
        }
        counts = c
        me = bz.element
        let mother = (me + 4) % 5                         // 生我者（印）
        let support = c[me] + c[mother]
        strong = support >= 4
        likes = strong ? [(me + 1) % 5, (me + 2) % 5] : [me, mother]
        switch bz.yearBranch {
        case 2, 3, 4: symbol = "青龙"; symbolDir = "东"
        case 5, 6, 7: symbol = "朱雀"; symbolDir = "南"
        case 8, 9, 10: symbol = "白虎"; symbolDir = "西"
        default: symbol = "玄武"; symbolDir = "北"
        }
        let a = Almanac.of(date)
        let s1 = (bz.yearBranch + 1) + a.lunarMonth + a.lunarDay
        let up = (s1 - 1) % 8, low = (s1 + (hour + 1) / 2 % 12 + 1 - 1) % 8
        upper = up
        hexName = Fortune.hexNames[up][low]
    }

    var meText: String { Almanac.stems[bz.dayStem] + L(Fortune.elements[me]) }
    var missing: [Int] { (0..<5).filter { counts[$0] == 0 } }
    var heavy: [Int] { (0..<5).filter { counts[$0] >= 4 } }

    /// 山人批：四五句结论
    var verdicts: [String] {
        var v: [String] = []
        v.append(LF("日主%@，%@。", meText, L(LifeChart.elementNature[me])))
        v.append(strong ? L("身强：精力足、扛得住事，宜往外闯、去花力气赚钱；忌固执、单打独斗。")
                        : L("身弱：心思细、易累，宜借力——找对平台和贵人；忌硬扛、什么都自己来。"))
        if let m = missing.first {
            v.append(LF("八字缺%@：%@", L(Fortune.elements[m]), L(LifeChart.missingTip[m])))
        } else if let h = heavy.first {
            v.append(LF("%@气过旺：%@", L(Fortune.elements[h]), L(LifeChart.heavyTip[h])))
        }
        v.append(LF("本命卦「%@」，上卦为%@：%@。", hexName, L(LifeChart.trigramNames[upper]), L(LifeChart.trigramNature[upper])))
        v.append(LF("本命四象属%@（%@方）：利往%@方发展，喜用%@，多用%@。", L(symbol), L(symbolDir), L(symbolDir),
                    likes.map { L(Fortune.elements[$0]) }.joined(separator: L("、")), L(Fortune.elementColor[likes[0]])))
        return v
    }

    static let missingTip = ["少了生发之气，做事容易停在想法，给自己定个开始的日子", "少了热度，别把情绪憋着，多晒太阳多见人",
                             "少了定力，钱和计划都要落到纸上", "少了决断，该拒绝的时候说出口", "少了变通，遇事多问一句「还有别的路吗」"]
    static let heavyTip = ["想法太多，挑一件做到底", "急躁易怒，重要决定隔一夜再说", "容易想太多顾太多，别被琐事拖住",
                           "太硬，说话留三分", "心思太活，定下来的事别反复"]

    /// 发给 AI 的内容：不含出生日期
    var aiPrompt: String {
        """
        你是隐居山中的命理先生「山人」，说话直接、有分寸、不吓人。下面是一位求问者的命盘（不含出生日期）：
        四柱：\(bz.text)；日主：\(Almanac.stems[bz.dayStem])\(Fortune.elements[me])，\(strong ? "身强" : "身弱")；
        五行：木\(counts[0]) 火\(counts[1]) 土\(counts[2]) 金\(counts[3]) 水\(counts[4])；喜用：\(likes.map { Fortune.elements[$0] }.joined(separator: "、"))；
        本命四象：\(symbol)；本命卦：\(hexName)。
        请用\(I18n.en ? "英文" : "简体中文")写一段 300 字左右的「命理总批」，分五小段，每段一句小标题：
        一、性情；二、事业与财；三、感情与人缘；四、身体要留意的地方（只说生活习惯，不做医学判断）；五、往后十年要注意的事。
        结合八字、五行、周易卦象来讲，具体、可执行，不要恐吓，不要绝对化。结尾注明“仅供娱乐参考”。
        """
    }
    var cacheKey: String { "life|" + bz.text + "|" + I18n.lang.rawValue }
}

struct LifeReadingCard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    @State private var aiBusy = false
    @State private var thinking = false
    @State private var live = ""
    @State private var aiError = ""

    var body: some View {
        let s = store.data.settings
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                InkSeal(text: I18n.en ? "Life" : "批", size: 26, color: p.ink)
                Text(L("命理总批")).font(Typo.song(17, bold: true)).foregroundColor(p.ink)
                Spacer()
                Text(L("按你的生辰 · 仅供娱乐参考")).font(Typo.ui(10)).foregroundColor(p.ink3)
            }
            if s.birthOn, let b = s.birthDate {
                let c = LifeChart(date: b, hour: s.birthHour)
                pillars(c)
                elementsBar(c)
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(c.verdicts.enumerated()), id: \.offset) { _, t in
                        HStack(alignment: .top, spacing: 8) {
                            Text("✦").font(.system(size: 8)).foregroundColor(p.ink3).padding(.top, 4)
                            Text(t).font(Typo.ui(12.5, .medium)).foregroundColor(p.ink).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                aiPart(c)
            } else {
                Text(L("还没有生辰，山人无从下笔。填好出生年月日时，就能看到你这一辈子的底色。"))
                    .font(Typo.ui(12.5)).foregroundColor(p.ink2).fixedSize(horizontal: false, vertical: true)
                Button(action: { ui.lotOpen = false; ui.birthEditing = true; ui.go(.settings) }) {
                    Text(L("去填生辰")).font(Typo.ui(13, .bold)).foregroundColor(p.onAccent)
                        .frame(maxWidth: .infinity).frame(height: 38).background(Capsule().fill(p.accent))
                }.buttonStyle(PressStyle())
            }
        }
        .padding(16)
        .glass(22, depth: 2, fill: p.heroTop)
    }

    private func pillars(_ c: LifeChart) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(zip(["年柱", "月柱", "日柱", "时柱"], c.bz.pillars).enumerated()), id: \.offset) { i, pr in
                VStack(spacing: 2) {
                    Text(L(pr.0)).font(Typo.ui(9.5, .semibold)).foregroundColor(p.ink3)
                    ForEach(Array(pr.1.enumerated()), id: \.offset) { _, ch in
                        Text(String(ch)).font(Typo.song(20, bold: true)).foregroundColor(i == 2 ? p.onAccent : p.ink)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(i == 2 ? p.accent : p.glassFill2))
            }
        }
    }

    private func elementsBar(_ c: LifeChart) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { k in
                VStack(spacing: 3) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3).fill(p.glassFill2).frame(width: 14, height: 34)
                        RoundedRectangle(cornerRadius: 3).fill(c.likes.contains(k) ? p.tint : p.ink2)
                            .frame(width: 14, height: max(2, CGFloat(c.counts[k]) / 8 * 34 * 2))
                    }
                    .frame(height: 34)
                    Text(L(Fortune.elements[k]) + "\(c.counts[k])").font(Typo.ui(10, .bold)).foregroundColor(c.likes.contains(k) ? p.tint : p.ink2)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .topTrailing) {
            Text(L("蓝 = 喜用")).font(Typo.ui(9)).foregroundColor(p.ink3)
        }
    }

    @ViewBuilder
    private func aiPart(_ c: LifeChart) -> some View {
        let s = store.data.settings
        if let t = store.data.aiCache[c.cacheKey] ?? (live.isEmpty ? nil : live) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L("山人细批")).font(Typo.song(12, bold: true)).foregroundColor(p.ink2)
                    Spacer()
                    if aiBusy {
                        Text(L("正在写…")).font(Typo.ui(10.5, .semibold)).foregroundColor(p.ink3)
                    }
                }
                Text(t).font(Typo.ui(12.5)).foregroundColor(p.ink).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.glassFill2))
        } else if s.aiOn && !s.aiEndpoint.isEmpty && !s.aiModel.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: { run(c) }) {
                    HStack(spacing: 6) { Image(systemName: "seal"); Text(L(aiBusy ? (thinking ? "山人在推演…" : "山人正在细批…") : "请山人细批一生")) }
                        .font(Typo.ui(13, .bold)).foregroundColor(p.onAccent)
                        .frame(maxWidth: .infinity).frame(height: 38).background(Capsule().fill(p.accent))
                }.buttonStyle(PressStyle()).disabled(aiBusy)
                if !aiError.isEmpty { Text(aiError).font(Typo.ui(11)).foregroundColor(p.ink2) }
            }
        } else if !s.aiOn {
            Button(action: { ui.lotOpen = false; ui.go(.settings) }) {
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                    Text(L("开启细批后，山人可为你细批一生"))
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                }
                .font(Typo.ui(11.5, .bold)).foregroundColor(p.tint)
            }.buttonStyle(.plain)
        }
    }

    private func run(_ c: LifeChart) {
        let s = store.data.settings
        aiBusy = true; aiError = ""; live = ""; thinking = false
        let msgs = [["role": "system", "content": HermitKnowledge.primer], ["role": "user", "content": c.aiPrompt]]
        AIClient.stream(msgs, base: s.aiEndpoint, model: s.aiModel, maxTokens: 4000, onThinking: { thinking = true }, onText: { t in live = t }) { r in
            aiBusy = false; thinking = false
            switch r {
            case .success(let t): store.data.aiCache[c.cacheKey] = t; store.save(); live = ""
            case .failure(let e): aiError = e.localizedDescription; live = ""
            }
        }
    }
}
