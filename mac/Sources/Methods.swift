import Foundation

// MARK: - 多角度起课（全部本地、原创实现，娱乐用途）
// 小六壬（农历月 + 日 + 时辰掐指）、六爻（三钱法，含动爻与变卦）、塔罗（22 张大阿卡纳，正逆位）。
// 起课种子 = 问句 + 所问时间 + 八字，所以换了生辰或换了问法，结果都会不同。

struct Angle: Identifiable {
    let id = UUID()
    let method: String      // 方法名
    let symbol: String      // SF Symbol
    let result: String      // 起出的结果（如“速喜”“雷风恒 → 地风升”“星星·正位”）
    let verdict: String     // 白话断语
    let score: Int          // -2...+2
}

enum Methods {
    static func hash(_ s: String) -> UInt64 { Draw.mix(Draw.fnv(s)) }

    // MARK: 小六壬
    static let liuren = ["大安", "留连", "速喜", "赤口", "小吉", "空亡"]
    static let liurenVerdict = [
        "稳：事情会照计划走，慢一点反而更好。", "拖：会卡在中间，别指望一次办成，多准备一个备选。",
        "快：好消息来得快，想做就趁早，拖了反而变卦。", "争：容易起口舌，少说话、别争对错。",
        "顺：有贵人帮一把，主动开口就能成。", "空：多半落空或白忙，换个时间或换条路。",
    ]
    static let liurenScore = [1, -1, 2, -2, 1, -2]

    static func xiaoLiuRen(when: Date) -> Angle {
        let a = Almanac.of(when)
        let hb = ((Days.cal.component(.hour, from: when) + 1) / 2) % 12
        let i = ((a.lunarMonth - 1) + (a.lunarDay - 1) + hb) % 6
        return Angle(method: L("小六壬"), symbol: "hand.raised.fingers.spread", result: L(liuren[i]),
                     verdict: L(liurenVerdict[i]), score: liurenScore[i])
    }

    // MARK: 六爻（三钱法）
    // 每爻掷三枚钱：6 老阴（动）、7 少阳、8 少阴、9 老阳（动）
    static let trigramLines: [[Int]] = [[1, 1, 1], [1, 1, 0], [1, 0, 1], [1, 0, 0], [0, 1, 1], [0, 1, 0], [0, 0, 1], [0, 0, 0]]

    static func trigram(_ l: [Int]) -> Int { trigramLines.firstIndex(of: l) ?? 0 }

    static func liuYao(question: String, when: Date, seed: String) -> (angle: Angle, main: String, changed: String, moving: [Int]) {
        var h = hash(question + "|" + Days.key(when) + "|" + Days.hm(when) + "|" + seed)
        var vals: [Int] = []
        for _ in 0..<6 {
            var sum = 0
            for _ in 0..<3 { h = Draw.mix(h &+ 0x9E37); sum += (h % 2 == 0) ? 2 : 3 }
            vals.append(sum)   // 6/7/8/9
        }
        let lines = vals.map { $0 % 2 }                 // 1 阳 0 阴（7、9 为阳）
        let changedLines = vals.map { v -> Int in v == 6 ? 1 : (v == 9 ? 0 : v % 2) }
        let moving = vals.enumerated().filter { $0.element == 6 || $0.element == 9 }.map { $0.offset + 1 }
        let main = Fortune.hexNames[trigram(Array(lines[3...5]))][trigram(Array(lines[0...2]))]
        let changed = Fortune.hexNames[trigram(Array(changedLines[3...5]))][trigram(Array(changedLines[0...2]))]
        func sc(_ n: String) -> Int { Oracle.auspicious.contains(n) ? 1 : (Oracle.ominous.contains(n) ? -1 : 0) }
        var score = sc(main) + (moving.isEmpty ? 0 : sc(changed))
        score = max(-2, min(2, score))
        let mv = I18n.en ? (HexVerdicts.en[main] ?? "") : (HexVerdicts.zh[main] ?? "")
        let cv = I18n.en ? (HexVerdicts.en[changed] ?? "") : (HexVerdicts.zh[changed] ?? "")
        let verdict: String
        if moving.isEmpty {
            verdict = LF("六爻安静，事情不会有大变化：%@", mv)
        } else {
            verdict = LF("本卦看现在：%@ 变卦看结果：%@", mv, cv)
        }
        let result = moving.isEmpty ? main : main + " → " + changed + " · " + LF("动 %@ 爻", moving.map(String.init).joined(separator: "、"))
        return (Angle(method: L("六爻"), symbol: "circle.grid.3x3", result: result, verdict: verdict, score: score), main, changed, moving)
    }

    // MARK: 塔罗（大阿卡纳）
    static let tarot: [(zh: String, en: String, up: String, rev: String, s: Int)] = [
        ("愚者", "The Fool", "大胆迈出去，新开始有好运。", "冲动会吃亏，先看清再跳。", 1),
        ("魔术师", "The Magician", "资源都在手里，今天你能把事做成。", "别耍小聪明，诚实最省事。", 2),
        ("女祭司", "The High Priestess", "相信直觉，答案你心里已经有了。", "信息不全，先别下结论。", 0),
        ("皇后", "The Empress", "丰盛、被照顾，适合享受和谈感情。", "别过度放纵，花钱有度。", 1),
        ("皇帝", "The Emperor", "掌控局面，按规则来就赢。", "太强势会树敌，收一收。", 1),
        ("教皇", "The Hierophant", "找前辈或权威，按老规矩办。", "别被条条框框困住。", 0),
        ("恋人", "The Lovers", "关系和选择都会有好结果。", "犹豫不决，选了就别回头。", 1),
        ("战车", "The Chariot", "冲！意志坚定就能赢。", "方向不对越快越错，先停一下。", 2),
        ("力量", "Strength", "以柔克刚，耐心会赢。", "情绪失控就输了。", 1),
        ("隐士", "The Hermit", "适合独处思考，别凑热闹。", "别把自己关太久，出去走走。", 0),
        ("命运之轮", "Wheel of Fortune", "转运点到了，抓住机会。", "时机不对，等一轮再说。", 2),
        ("正义", "Justice", "公平的结果，按规矩来稳赢。", "可能被不公对待，留好证据。", 0),
        ("倒吊人", "The Hanged Man", "换个角度看，暂停是对的。", "白白牺牲，及时止损。", -1),
        ("死神", "Death", "旧的结束新的开始，放手吧。", "拖着不放会更痛。", -1),
        ("节制", "Temperance", "平衡、慢慢调，结果不错。", "失衡了，少做一件事。", 1),
        ("恶魔", "The Devil", "诱惑当前，小心上瘾和被套牢。", "正在挣脱束缚，是好事。", -2),
        ("高塔", "The Tower", "突发变动，别硬扛，先保住自己。", "危机在消退，但别大意。", -2),
        ("星星", "The Star", "希望和好运，愿望会实现。", "别灰心，再坚持一下。", 2),
        ("月亮", "The Moon", "情况不明，小心误会和被骗。", "迷雾散去，真相浮现。", -1),
        ("太阳", "The Sun", "大吉，成功、开心、被看见。", "好事会晚一点到。", 2),
        ("审判", "Judgement", "被认可、被召唤，该做决定了。", "别自我怀疑，过去的事放下。", 1),
        ("世界", "The World", "圆满完成，水到渠成。", "差最后一步，别松劲。", 2),
    ]

    static func tarotCard(question: String, when: Date, seed: String) -> Angle {
        let h = hash("tarot|" + question + "|" + Days.key(when) + "|" + seed)
        let c = tarot[Int(h % 22)]
        let upright = (h >> 8) % 3 != 0
        let name = I18n.en ? c.en : c.zh
        let text = upright ? c.up : c.rev
        let score = upright ? c.s : (c.s > 0 ? -1 : (c.s < 0 ? 1 : 0))
        return Angle(method: L("塔罗"), symbol: "suit.diamond", result: name + " · " + L(upright ? "正位" : "逆位"),
                     verdict: L(text), score: score)
    }
}
