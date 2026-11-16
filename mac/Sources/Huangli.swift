import SwiftUI

// MARK: - 老黄历：万年历里点任意一天，看那天完整的黄历

struct HuangliCard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p

    var body: some View {
        let d = Days.date(fromKey: ui.selectedDay) ?? Days.now
        let a = Almanac.of(d)
        let di = Fortune.dayIndex(d)
        let db = ((di % 12) + 12) % 12, ds = ((di % 10) + 10) % 10
        let gz = Fortune.bazi(date: Days.cal.date(bySettingHour: 12, minute: 0, second: 0, of: d) ?? d, hour: 12).pillars
        let slots = Fortune.slots(dayBranch: db, me: nil)
        let list = store.reminders(on: ui.selectedDay)
        VStack(alignment: .leading, spacing: 12) {
            // 头：大日期 + 农历 + 干支
            HStack(alignment: .center, spacing: 14) {
                VStack(spacing: 0) {
                    Text("\(Days.cal.component(.day, from: d))").font(Typo.num(40, .bold)).foregroundColor(p.ink)
                    Text(Days.weekday(d)).font(Typo.ui(11, .semibold)).foregroundColor(p.ink2)
                }
                .frame(width: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(a.lunarFull).font(Typo.song(17, bold: true)).foregroundColor(p.ink)
                    Text(gz[0] + L("年 ") + gz[1] + L("月 ") + gz[2] + L("日") + " · " + LF("属%@", L(a.zodiac)))
                        .font(Typo.ui(11.5, .semibold)).foregroundColor(p.ink2)
                    Text(LF("%@ · 冲%@ 煞%@", a.officerDisplay, L(Almanac.animals[(db + 6) % 12]), L(Fortune.shaDir(db))))
                        .font(Typo.ui(11.5)).foregroundColor(p.ink2)
                }
                Spacer(minLength: 0)
            }
            // 宜 / 忌
            HStack(alignment: .top, spacing: 8) {
                yiji(L("宜"), a.yi, strong: true)
                yiji(L("忌"), a.ji, strong: false)
            }
            // 吉神方位
            HStack(spacing: 6) {
                dir(L("喜神"), Fortune.luckyDir(ds))
                dir(L("财神"), Fortune.wealthDir(ds))
                dir(L("煞方"), Fortune.shaDir(db))
            }
            // 十二时辰吉凶
            VStack(alignment: .leading, spacing: 6) {
                Text(L("时辰吉凶（实心为黄道吉时）")).font(Typo.ui(11, .bold)).foregroundColor(p.ink2)
                VStack(spacing: 5) { ForEach(0..<2, id: \.self) { row in HStack(spacing: 5) {
                    ForEach(slots[(row * 6)..<(row * 6 + 6)]) { sl in
                        VStack(spacing: 1) {
                            Text(Almanac.branches[sl.branch]).font(Typo.song(14, bold: true))
                            Text(L(sl.god)).font(Typo.ui(8.5, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .foregroundColor(sl.good ? p.onAccent : p.ink2)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(sl.good ? p.accent : Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(sl.good ? Color.clear : p.hairline, lineWidth: 1))
                    }
                } } }
            }
            if let lot = store.lot(forDay: ui.selectedDay) {
                Button(action: { if ui.selectedDay == store.qianDay { ui.go(.home); ui.lotOpen = true } }) {
                    HStack(spacing: 8) {
                        InkSeal(text: lot.levelShort, size: 24, color: p.ink)
                        Text(L("那天的签：") + lot.displayName + "　" + lot.poem).font(Typo.ui(12)).foregroundColor(p.ink).lineLimit(1)
                    }
                }.buttonStyle(.plain)
            }
            if !list.isEmpty {
                Collapsible(list) { r in
                    ReminderPill(r: r, ink: p.ink, ink2: p.ink2, chip: p.glassFill2, dotColor: p.ink)
                }
            }
            Text(L("黄历按传统建除、黄黑道算法在本机推算 · 仅供娱乐参考")).font(Typo.ui(10)).foregroundColor(p.ink3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(22, depth: 1)
    }

    private func yiji(_ t: String, _ items: [String], strong: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(t).font(Typo.song(18, bold: true))
                .foregroundColor(strong ? p.onAccent : p.ink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(strong ? p.accent : Color.clear))
                .overlay(Circle().strokeBorder(strong ? Color.clear : p.ink2, lineWidth: 1.4))
            VStack(alignment: .leading, spacing: 3) {
                ForEach(items, id: \.self) { Text(L($0)).font(Typo.ui(12.5, .semibold)).foregroundColor(strong ? p.ink : p.ink2) }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.glassFill2))
    }

    private func dir(_ t: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(t).font(Typo.ui(10, .semibold)).foregroundColor(p.ink3)
            Text(L(v)).font(Typo.song(14, bold: true)).foregroundColor(p.ink)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(p.glassFill2))
    }
}
