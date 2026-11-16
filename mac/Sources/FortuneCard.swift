import SwiftUI

// MARK: - 今日断语卡（首页）：一句狠话 + 吉凶时辰条 + 去做/别做 + 方位 + 今日一卦 + 这段时间

struct FortuneCard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p

    var body: some View {
        let s = store.data.settings
        let date = ui.dialDay == 0 ? Days.now : Days.addDays(ui.dialDay, to: Days.startOfDay(Days.now))
        let r = Fortune.reading(for: date, birth: s.birthOn ? s.birthDate : nil, birthHour: s.birthHour)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                badge(r.tone)
                Text(L("山人说")).font(Typo.song(13, bold: true)).foregroundColor(p.ink2)
                Spacer()
                if r.personal {
                    Text(L("按你的八字推算")).font(Typo.ui(10.5, .semibold)).foregroundColor(p.ink3)
                    if store.todayLot != nil { ShareButton() }
                } else {
                    Button(action: { ui.go(.settings) }) {
                        HStack(spacing: 2) { Text(L("填生辰，算得更准")); Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)) }
                            .font(Typo.ui(11, .bold)).foregroundColor(p.tint)
                    }.buttonStyle(.plain)
                }
            }
            Text(r.headline)
                .font(Typo.ui(17, .heavy)).foregroundColor(p.ink).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if !r.reasons.isEmpty {
                Text(L("依据：") + r.reasons.joined(separator: "；"))
                    .font(Typo.ui(10.5)).foregroundColor(p.ink3).fixedSize(horizontal: false, vertical: true)
            }
            timeline(r)
            VStack(spacing: 6) {
                ForEach(Array(r.goodHours.enumerated()), id: \.offset) { _, g in hourRow(g.0, g.1, good: true) }
                ForEach(Array(r.badHours.enumerated()), id: \.offset) { _, b in hourRow(b.0, b.1, good: false) }
            }
            HStack(spacing: 6) {
                dirChip(L("喜神"), r.luckyDir)
                dirChip(L("财神"), r.wealthDir)
                dirChip(L("煞"), r.shaDir)
                dirChip(L("冲"), r.clashZodiac)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("☯").font(.system(size: 14))
                    Text(L("今日一卦") + " · " + r.hexName).font(Typo.song(14, bold: true)).foregroundColor(p.ink)
                }
                Text(r.hexVerdict).font(Typo.ui(12.5, .semibold)).foregroundColor(p.ink).fixedSize(horizontal: false, vertical: true)
                Text(r.hexLine).font(Typo.ui(11)).foregroundColor(p.ink2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(p.glassFill2))
            if !r.period.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("这段时间")).font(Typo.ui(11.5, .bold)).foregroundColor(p.ink2)
                    ForEach(r.period, id: \.self) { t in
                        HStack(alignment: .top, spacing: 6) {
                            Circle().fill(p.ink).frame(width: 5, height: 5).padding(.top, 6)
                            Text(t).font(Typo.ui(12.5, .medium)).foregroundColor(p.ink).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            Text(L("命理推算仅供娱乐参考，请勿据此做重大决定")).font(Typo.ui(10)).foregroundColor(p.ink3)
        }
        .padding(16)
        .glass(24, depth: 2, fill: p.heroTop)
    }

    private func badge(_ t: Reading.Tone) -> some View {
        let txt = t == .good ? L("吉") : (t == .bad ? L("慎") : L("平"))
        return HStack(spacing: 3) {
            if t == .bad { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9, weight: .bold)) }
            Text(txt).font(Typo.song(13, bold: true))
        }
        .foregroundColor(t == .mixed ? p.ink : p.onAccent)
        .padding(.horizontal, 9).padding(.vertical, 3)
        .background(Capsule().fill(t == .mixed ? p.glassFill2 : p.accent))
        .overlay(Capsule().strokeBorder(t == .mixed ? p.hairline : .clear, lineWidth: 1))
    }

    /// 十二时辰条：实心 = 吉时，空心 = 凶时，蓝圈 = 你的冲时，小三角 = 现在
    private func timeline(_ r: Reading) -> some View {
        let order = Array(r.slots.sorted { $0.start == 23 ? true : ($1.start == 23 ? false : $0.start < $1.start) })
        let nowB = ((Days.cal.component(.hour, from: Days.now) + 1) / 2) % 12
        return VStack(spacing: 4) {
            HStack(spacing: 3) {
                ForEach(order) { s in
                    VStack(spacing: 3) {
                        Image(systemName: "arrowtriangle.down.fill").font(.system(size: 6)).foregroundColor(s.branch == nowB ? p.tint : .clear)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(s.good ? p.ink : Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(s.personalClash ? p.tint : (s.good ? Color.clear : p.ink3), lineWidth: s.personalClash ? 2 : 1))
                            .frame(height: 16)
                        Text(Almanac.branches[s.branch]).font(Typo.song(10, bold: true)).foregroundColor(s.good ? p.ink : p.ink3)
                    }
                }
            }
            HStack {
                legend(fill: true, L("吉时"))
                legend(fill: false, L("凶时"))
                if r.personal {
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2).strokeBorder(p.tint, lineWidth: 1.5).frame(width: 10, height: 8)
                        Text(L("你的冲时")).font(Typo.ui(9.5)).foregroundColor(p.ink2)
                    }
                }
                Spacer()
            }
        }
    }

    private func legend(fill: Bool, _ t: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).fill(fill ? p.ink : .clear)
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(p.ink3, lineWidth: fill ? 0 : 1))
                .frame(width: 10, height: 8)
            Text(t).font(Typo.ui(9.5)).foregroundColor(p.ink2)
        }
    }

    private func hourRow(_ s: HourSlot, _ advice: String, good: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Group {
                if I18n.en {
                    Image(systemName: good ? "checkmark" : "exclamationmark").font(.system(size: 10, weight: .heavy))
                } else {
                    Text(good ? "吉" : "凶").font(Typo.song(12, bold: true))
                }
            }
            .foregroundColor(good ? p.onAccent : p.ink)
            .frame(width: 22, height: 22)
            .background(Circle().fill(good ? p.accent : Color.clear))
            .overlay(Circle().strokeBorder(good ? Color.clear : p.ink2, lineWidth: 1.2))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(s.range).font(Typo.num(12.5, .bold)).monospacedDigit().foregroundColor(p.ink)
                    Text(s.name + " · " + L(s.god)).font(Typo.ui(10.5)).foregroundColor(p.ink2).lineLimit(1)
                }
                Text(advice).font(Typo.ui(12, .semibold)).foregroundColor(p.ink).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func list(_ title: String, _ items: [String], _ sym: String, strong: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(Typo.ui(11, .bold)).foregroundColor(p.ink2)
            ForEach(items, id: \.self) { s in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: sym).font(.system(size: 9.5, weight: .bold)).foregroundColor(strong ? p.ink : p.ink2).padding(.top, 2.5)
                    Text(s).font(Typo.ui(12, .semibold)).foregroundColor(p.ink).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(p.glassFill2))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(p.hairline, lineWidth: 1))
    }

    private func dirChip(_ k: String, _ v: String) -> some View {
        VStack(spacing: 1) {
            Text(k).font(Typo.ui(9.5, .bold)).foregroundColor(p.ink3)
            Text(v).font(Typo.ui(12, .bold)).foregroundColor(p.ink).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(p.glassFill2))
    }
}
