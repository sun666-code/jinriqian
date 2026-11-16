import Foundation

// MARK: - 中英双语
// L("中文") → 英文模式下查表返回英文，查不到就原样返回（因此可重复调用）。
// LF("还有 %d 件要做", n) → 先翻译格式串再填参数。

enum Lang: String, Codable, CaseIterable {
    case zh, en
}

enum I18n {
    static var lang: Lang = .zh
    static var en: Bool { lang == .en }
}

func L(_ zh: String) -> String {
    guard I18n.en else { return zh }
    return I18nV10.en[zh] ?? I18nTable.en[zh] ?? zh
}

func LF(_ zh: String, _ args: CVarArg...) -> String {
    String(format: L(zh), arguments: args)
}

// MARK: 日期与黄历的英文表达

extension Days {
    static let weekNamesEn = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let monthNamesEn = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
}

extension DayAlmanac {
    /// “农历九月廿七” / “Lunar 9/27”
    var lunarFull: String {
        I18n.en ? "Lunar \(isLeap ? "leap " : "")\(lunarMonth)/\(lunarDay)" : "农历" + lunarText
    }
    var lunarShort: String {
        I18n.en ? (lunarDay == 1 ? "L\(lunarMonth)" : "\(lunarDay)") : lunarDayText
    }
    var officerDisplay: String { L(officerName) }
}

extension Lot {
    var en: LotLibrary.EnText? { LotLibrary.english[no] }
    var displayName: String { I18n.en ? (en?.name ?? name) : name }
    var displayNote: String { I18n.en ? (en?.note ?? note) : note }
    var displayTodo: [String] { I18n.en ? (en?.todo ?? todo) : todo }
    var displayAvoid: [String] { I18n.en ? (en?.avoid ?? avoid) : avoid }
    var displayOne: String { I18n.en ? (en?.one ?? one) : one }
    /// 签诗保留中文原文；英文模式下附一句意译
    var displayPoemGloss: String? { I18n.en ? en?.poem : nil }
}
