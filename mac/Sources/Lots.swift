import Foundation

// MARK: - 签库（全部原创文案，24 支）
// 每支签：签名、等级、一句签诗、白话解签（温和建议）、宜做三件、避开三件、今日一事。
// 等级刻意不用“凶”字：最差的签也只是“守成 / 静养”，提醒稳一稳，不吓人。

struct Lot: Identifiable, Hashable, Codable {
    let no: Int
    let name: String
    let level: String
    let poem: String
    let note: String
    let todo: [String]
    let avoid: [String]
    let one: String
    var id: Int { no }

    var levelText: String { I18n.en ? (LotLibrary.levelEn[level] ?? level) : level + "签" }
    var levelShort: String { I18n.en ? (LotLibrary.levelEn[level] ?? level) : level }
    var noText: String { I18n.en ? "No.\(no)" : "第" + Lot.cn(no) + "签" }
    /// 卡面色调序号（无红色）
    var tone: Int {
        switch level {
        case "上上": return 0
        case "上吉": return 1
        case "中吉": return 2
        case "中平": return 3
        case "守成": return 4
        default: return 5
        }
    }

    static func cn(_ n: Int) -> String {
        let d = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        if n < 10 { return d[n] }
        if n == 10 { return "十" }
        if n < 20 { return "十" + d[n % 10] }
        return d[n / 10] + "十" + d[n % 10]
    }
}

// 签库可以扩充：首次运行会把内置签写到数据文件夹
// （~/Library/Application Support/今日签-山人/lots-v2.json），用文本编辑器往里加即可。
enum LotLibrary {
    static func lot(_ no: Int) -> Lot { all[((no - 1) % all.count + all.count) % all.count] }

    static var fileURL: URL { Store.fileURL.deletingLastPathComponent().appendingPathComponent("lots-v2.json") }

    private(set) static var all: [Lot] = builtin

    /// 读取用户签库；文件不存在就写入内置签库作为模板
    static func load(useFile: Bool = true) {
        guard useFile else { all = builtin; return }
        let url = fileURL
        if let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([LotEntry].self, from: data), !list.isEmpty {
            all = list.enumerated().map { i, e in
                Lot(no: i + 1, name: e.name, level: e.level, poem: e.poem, note: e.note,
                    todo: Array((e.todo + ["", "", ""]).prefix(3)).filter { !$0.isEmpty },
                    avoid: Array((e.avoid + ["", "", ""]).prefix(3)).filter { !$0.isEmpty }, one: e.one)
            }
            var en: [Int: EnText] = [:]
            for (i, e) in list.enumerated() {
                if let n = e.nameEn {
                    en[i + 1] = EnText(name: n, poem: e.poemEn ?? "", note: e.noteEn ?? e.note, todo: e.todoEn ?? e.todo, avoid: e.avoidEn ?? e.avoid, one: e.oneEn ?? e.one)
                }
            }
            custom = en
        } else {
            all = builtin
            let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let entries = builtin.map { l -> LotEntry in
                let e = builtinEn[l.no] ?? hexEn[l.no]
                return LotEntry(name: l.name, level: l.level, poem: l.poem, note: l.note, todo: l.todo, avoid: l.avoid, one: l.one,
                                nameEn: e?.name, poemEn: e?.poem, noteEn: e?.note, todoEn: e?.todo, avoidEn: e?.avoid, oneEn: e?.one)
            }
            if let d = try? enc.encode(entries) { try? d.write(to: url, options: .atomic) }
        }
    }

    struct LotEntry: Codable {
        var name: String
        var level: String
        var poem: String
        var note: String
        var todo: [String]
        var avoid: [String]
        var one: String
        var nameEn: String? = nil
        var poemEn: String? = nil
        var noteEn: String? = nil
        var todoEn: [String]? = nil
        var avoidEn: [String]? = nil
        var oneEn: String? = nil
    }

    static let original: [Lot] = [
        Lot(no: 1, name: "晨光", level: "上上", poem: "雪尽春山第一枝，风来不必问归期。",
            note: "想了很久的事，今天适合先迈出一小步。好的开头，已经算赢了一半。",
            todo: ["开启一个新计划", "主动约一位老朋友", "早起晒十分钟太阳"], avoid: ["把好主意又放回抽屉", "一次答应太多邀约", "熬夜庆祝"],
            one: "把一直想做的事写成一句话，贴在显示器边上。"),
        Lot(no: 2, name: "得月", level: "上上", poem: "推窗恰见月当头，旧事轻轻放下舟。",
            note: "心里那件放不下的事，今天会自己松一点。顺势而为就好。",
            todo: ["说出一句迟到的谢谢", "收尾一件旧事", "归档旧文件"], avoid: ["和人争输赢", "翻旧账", "睡前刷手机"],
            one: "给一个很久没联系的人，发一句「最近好吗」。"),
        Lot(no: 3, name: "临溪", level: "上吉", poem: "溪声伴我过前桥，半路逢人共一瓢。",
            note: "今天容易遇到愿意帮你的人，开口问一句，比自己硬扛轻松得多。",
            todo: ["向同事请教一个问题", "约人一起吃午饭", "多喝温水"], avoid: ["独自扛下所有", "急着下结论", "跳过午饭"],
            one: "今天主动问一个问题，哪怕它看起来很简单。"),
        Lot(no: 4, name: "松风", level: "上吉", poem: "松下听风不急行，一壶清茗待天晴。",
            note: "好事在路上，只是走得慢一点。今天把节奏放稳，比加速更有用。",
            todo: ["做一件需要耐心的事", "泡一壶茶", "读二十页书"], avoid: ["催别人回复", "频繁刷进度", "边走路边回消息"],
            one: "关掉通知 25 分钟，专心做完一件事。"),
        Lot(no: 5, name: "燕归", level: "中吉", poem: "檐前燕子识旧家，衔泥一点是生涯。",
            note: "日子是一点点垒起来的。今天适合打理身边的小事，家和桌面都会回报你。",
            todo: ["收拾房间一角", "给家里打个电话", "自己做一顿饭"], avoid: ["嫌弃小进步", "大笔开销", "外卖连吃"],
            one: "清空一个抽屉，或者扔掉三样不用的东西。"),
        Lot(no: 6, name: "种竹", level: "中吉", poem: "今朝种竹三两竿，他日清阴满院看。",
            note: "今天做的事不会马上有回报，但会在以后某一天让你感谢自己。",
            todo: ["学一点新东西", "存一笔小钱", "给植物浇水"], avoid: ["期待立刻见效", "和别人比进度", "透支身体"],
            one: "花 10 分钟学一个新知识，记下一句心得。"),
        Lot(no: 7, name: "行舟", level: "中平", poem: "顺水行舟莫贪快，两岸青山慢慢来。",
            note: "一切正常推进，不必用力过猛。保持现在的速度，就是今天最好的选择。",
            todo: ["按计划办事", "早点出门", "做一次小复盘"], avoid: ["临时加码", "抄近路", "一口气做太多"],
            one: "出门前多留 10 分钟，路上看看两边的风景。"),
        Lot(no: 8, name: "听雨", level: "中平", poem: "夜雨敲窗不必愁，明朝檐下看新流。",
            note: "有点小情绪很正常，它会像雨一样停下来。今天先照顾好自己。",
            todo: ["听一张喜欢的专辑", "早点下班", "睡前泡个脚"], avoid: ["回复情绪化的消息", "做重大决定", "深夜自我否定"],
            one: "写下一件今天让你不舒服的事，然后合上本子。"),
        Lot(no: 9, name: "半云", level: "中平", poem: "云遮半岭路犹在，脚下分明一寸宽。",
            note: "看不清远方没关系，眼前这一步是清楚的。只管做好手边的事。",
            todo: ["列一张小清单", "先完成最小的一项", "早睡半小时"], avoid: ["规划太远的事", "反复纠结", "空着肚子做决定"],
            one: "只写下明天最重要的一件事。"),
        Lot(no: 10, name: "霜桥", level: "守成", poem: "霜重桥滑缓步行，回头一笑是天明。",
            note: "今天容易出点小差错，慢一点就能避开。不是坏事，是提醒你稳一稳。",
            todo: ["检查一遍再发送", "穿双舒服的鞋", "备份重要文件"], avoid: ["匆忙签字或付款", "过马路看手机", "带着火气回消息"],
            one: "重要消息写好后，隔 10 分钟再发。"),
        Lot(no: 11, name: "收帆", level: "守成", poem: "逆风且把帆收半，留得船身待好天。",
            note: "今天推进可能有点费劲，少用力反而更省心。先守住，不必硬冲。",
            todo: ["做保守一点的选择", "喝一碗热汤", "早点休息"], avoid: ["跟人讲道理到底", "孤注一掷", "大额消费"],
            one: "今天少说一句反驳的话，看看会发生什么。"),
        Lot(no: 12, name: "静夜", level: "静养", poem: "灯暗宜收书一卷，夜长正好养精神。",
            note: "这不是坏日子，是适合休息的日子。少做决定、早点睡，明天会顺很多。",
            todo: ["早点回家", "好好吃一顿饭", "整理一下心情"], avoid: ["熬夜", "谈判或摊牌", "把小事想得太坏"],
            one: "今晚 11 点前放下手机，给自己一个完整的睡眠。"),
        Lot(no: 13, name: "开窗", level: "上上", poem: "一夜东风过小楼，推窗满眼是新绿。",
            note: "换个角度，事情会突然变简单。今天适合尝试新方法、见新的人。",
            todo: ["换一条路线上班", "试一个新工具", "认识一位新朋友"], avoid: ["固守老办法", "拒绝新提议", "一直宅着"],
            one: "今天做一件以前从没做过的小事。"),
        Lot(no: 14, name: "鹤鸣", level: "上吉", poem: "鹤鸣九皋声自远，不须高处更扬声。",
            note: "你做的事别人看得见。今天安心把事做好，不必急着证明自己。",
            todo: ["把作品认真收尾", "整理一次成果", "给自己一句肯定"], avoid: ["过度解释", "抢话", "和人比声量"],
            one: "把这周做成的一件事，用三句话记下来。"),
        Lot(no: 15, name: "春泥", level: "中吉", poem: "落红化作春泥暖，护得新芽一寸长。",
            note: "过去的经历都没有白费，它们正在悄悄滋养你。今天适合照顾别人，也照顾自己。",
            todo: ["帮身边人一个小忙", "整理旧笔记", "吃点新鲜蔬果"], avoid: ["否定过去的自己", "嫌弃慢", "忘了吃早饭"],
            one: "翻一页旧笔记，找出一句今天还用得上的话。"),
        Lot(no: 16, name: "远山", level: "中吉", poem: "远山不语自青青，一步一阶有路程。",
            note: "目标还远，但方向是对的。今天只需要往前挪一格。",
            todo: ["推进长期项目一小步", "散步二十分钟", "更新一下计划"], avoid: ["三分钟热度", "因为远就不开始", "一次走太快"],
            one: "给长期目标设一个本周就能完成的小台阶。"),
        Lot(no: 17, name: "晴川", level: "上吉", poem: "晴川历历好行舟，万事随缘自可求。",
            note: "今天气顺，适合把拖着的沟通一次说清楚。语气温和，结果会更好。",
            todo: ["把该说的话说清楚", "确认一件悬而未决的事", "出门走走"], avoid: ["含糊其辞", "冷处理", "临时爽约"],
            one: "回复一条你一直没回的消息。"),
        Lot(no: 18, name: "灯下", level: "中平", poem: "灯下研墨写新字，一笔未成莫心焦。",
            note: "今天做事可能要多试几次。不顺不代表不对，慢慢来就好。",
            todo: ["练习一项技能", "把桌面收拾干净", "写下今天的进展"], avoid: ["一次不成就放弃", "边做边刷手机", "自我苛责"],
            one: "把今天卡住的地方写成一个问题，明天再看。"),
        Lot(no: 19, name: "流萤", level: "中平", poem: "草间流萤一点光，不争明月自成行。",
            note: "小小的努力也会发光。今天不必做大事，把小事做漂亮就够了。",
            todo: ["完成三件小事", "夸一次别人", "晚饭后散步"], avoid: ["小看小进步", "跟人攀比", "拖到深夜"],
            one: "睡前写下今天完成的三件小事。"),
        Lot(no: 20, name: "停云", level: "守成", poem: "停云霭霭且安坐，待得风来再举杯。",
            note: "时机还没到，先别急着推进。今天适合准备、整理和等待。",
            todo: ["把资料准备齐", "整理待办清单", "按时吃饭"], avoid: ["急着拍板", "强行推进", "空腹喝咖啡"],
            one: "列出这件事还差的三样准备。"),
        Lot(no: 21, name: "白露", level: "静养", poem: "白露凝时秋意深，添衣一件暖人心。",
            note: "身体在提醒你慢一点。今天把照顾自己放在第一位。",
            todo: ["添一件衣服", "喝温热的东西", "提前上床"], avoid: ["硬撑加班", "吃太凉", "熬夜追剧"],
            one: "今天给自己留出 30 分钟什么都不做。"),
        Lot(no: 22, name: "归雁", level: "上上", poem: "雁字回时月满楼，等闲心事一时休。",
            note: "等的消息、盼的事，今天可能有回音。保持开放，好事会来找你。",
            todo: ["查看一下邮件和消息", "联系家人", "给自己准备点小奖励"], avoid: ["患得患失", "反复确认", "把心事憋着"],
            one: "给关心你的人回一个电话。"),
        Lot(no: 23, name: "竹影", level: "中吉", poem: "竹影扫阶尘不动，心安何处不从容。",
            note: "外面再忙，心里也可以安静。今天适合专注，少被打扰。",
            todo: ["整块时间专注工作", "清理一个文件夹", "做几分钟深呼吸"], avoid: ["多线程乱切", "被消息牵着走", "临时开会"],
            one: "设一个 45 分钟的勿扰时段。"),
        Lot(no: 24, name: "初雪", level: "中平", poem: "初雪无声覆小径，明朝足迹自分明。",
            note: "事情会慢慢变清楚。今天少下判断，多观察。",
            todo: ["多听少说", "记录一个观察", "整理一下衣柜"], avoid: ["急着下定论", "传播没确认的消息", "冲动购物"],
            one: "今天记下一件让你意外的小事。"),
    ]
}

// MARK: - 确定性抽签
// 牌堆是“无限”的：第 i 张牌对应哪支签 = 哈希(本地种子 | 签日 | i) 对签库取余。
// 滑到哪张、抽出哪张就是哪张；同一签日同一张牌永远是同一支签。

enum Draw {
    static func fnv(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
        return h
    }

    static func mix(_ x: UInt64) -> UInt64 {
        var z = x &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    static func lotNo(seed: String, day: String, index: Int) -> Int {
        let n = max(1, LotLibrary.all.count)
        return Int(mix(fnv(seed + "|" + day) &+ UInt64(bitPattern: Int64(index))) % UInt64(n)) + 1
    }

    /// 每天打开时牌堆停在一个随机位置（同一天固定）
    static func startIndex(seed: String, day: String) -> Int {
        Int(mix(fnv("start|" + seed + "|" + day)) % 900) + 100
    }
}
