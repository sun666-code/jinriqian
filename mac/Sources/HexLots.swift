import Foundation

// MARK: - 签库扩充：原创 24 支 + 周易六十四卦签 64 支 = 88 支
// 卦签的签诗取自本应用原创的卦义断语（HexVerdicts），不抄任何庙宇签文。
// 每次抽到还会按抽中的那张牌分出「动爻」（6 种变化），一共 88 × 6 种结果。

extension LotLibrary {
    static let builtin: [Lot] = original + hexLots

    private static let levelText: [String: (note: String, todo: [String], avoid: [String], one: String)] = [
        "上上": ("大势在你，放手去做，记得给身边人留一份功劳。", ["主动开口提要求", "把搁置的大事推一步", "约重要的人见面"], ["犹豫拖延", "妄自菲薄", "临阵换人"], "今天把最想做的那件事开个头。"),
        "上吉": ("顺风顺水，适合推进与谈事，但别贪多。", ["推进手头的关键事", "谈合作或谈薪", "整理成果给人看"], ["一口吃成胖子", "口头承诺太多", "得意忘形"], "把今天的一件好事记下来。"),
        "中吉": ("小有收获，按部就班就好。", ["做完一件小事", "联系一位老朋友", "早点睡"], ["临时改计划", "冲动消费", "熬夜"], "完成清单上最小的一项。"),
        "中平": ("平稳的一天，不求大进，守住节奏。", ["按计划走", "整理房间或文件", "少说多听"], ["和人争论", "做重大决定", "轻信传言"], "给自己留出 20 分钟安静时间。"),
        "守成": ("逆风的日子，守比攻好，先护住手里的。", ["把已有的事做稳", "检查合同与账目", "照顾好身体"], ["借钱或担保", "开新坑", "跟人硬碰"], "今天只做一件事，并把它做好。"),
    ]
    private static let levelEnText: [String: (note: String, todo: [String], avoid: [String], one: String)] = [
        "上上": ("The tide is yours — go for it, and share the credit.", ["Ask for what you want", "Push a big task forward", "Meet someone important"], ["Hesitating", "Selling yourself short", "Changing horses mid-stream"], "Start the one thing you most want to do."),
        "上吉": ("Smooth sailing — good for pushing and negotiating; don't overreach.", ["Advance a key task", "Negotiate a deal or raise", "Show your results"], ["Doing too much at once", "Over-promising", "Getting cocky"], "Write down one good thing from today."),
        "中吉": ("Small gains — steady does it.", ["Finish one small task", "Message an old friend", "Sleep early"], ["Last-minute changes", "Impulse buys", "Late nights"], "Do the smallest item on your list."),
        "中平": ("An even day — keep your rhythm.", ["Stick to the plan", "Tidy up", "Listen more"], ["Arguing", "Big decisions", "Rumors"], "Give yourself 20 quiet minutes."),
        "守成": ("Headwind — defend rather than attack.", ["Stabilize what you have", "Check contracts and accounts", "Look after your health"], ["Lending or guaranteeing", "Starting new things", "Head-on clashes"], "Do just one thing today, and do it well."),
    ]

    static func hexLevel(_ name: String, _ up: Int, _ low: Int) -> String {
        if name == "乾为天" || name == "地天泰" { return "上上" }
        if Oracle.auspicious.contains(name) { return "上吉" }
        if Oracle.ominous.contains(name) { return "守成" }
        return (up + low) % 2 == 0 ? "中吉" : "中平"
    }

    static let hexLots: [Lot] = {
        var out: [Lot] = []
        for up in 0..<8 {
            for low in 0..<8 {
                let name = Fortune.hexNames[up][low]
                let v = HexVerdicts.zh[name] ?? name
                let parts = v.split(separator: "：", maxSplits: 1).map(String.init)
                let head = parts.first ?? name
                let body = parts.count > 1 ? parts[1] : v
                let lv = hexLevel(name, up, low)
                let t = levelText[lv]!
                out.append(Lot(no: 25 + up * 8 + low, name: name, level: lv, poem: body,
                               note: "「\(head)」" + t.note, todo: t.todo, avoid: t.avoid, one: t.one))
            }
        }
        return out
    }()

    static let hexEn: [Int: EnText] = {
        var out: [Int: EnText] = [:]
        for up in 0..<8 {
            for low in 0..<8 {
                let name = Fortune.hexNames[up][low]
                let lv = hexLevel(name, up, low)
                let t = levelEnText[lv]!
                let v = HexVerdicts.en[name] ?? ""
                out[25 + up * 8 + low] = EnText(name: "Hexagram \(up * 8 + low + 1)", poem: v, note: v + " " + t.note, todo: t.todo, avoid: t.avoid, one: t.one)
            }
        }
        return out
    }()
}

extension Lot {
    /// 卦象：卦签直接是那一卦；原创签按序号配一卦（用于签面的卦纹）
    var trigrams: (up: Int, low: Int) { Lot.trigramsFor(no) }
}
