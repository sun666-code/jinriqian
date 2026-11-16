import SwiftUI

// MARK: - 看签（吊牌下拉 / 点击打开）

struct LotSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    @State private var aiText = ""
    @State private var aiBusy = false
    @State private var aiError = ""

    var body: some View {
        if let lot = store.todayLot {
            let d = Days.date(fromKey: store.qianDay) ?? Days.now
            let a = Almanac.of(d)
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L("今日签 · 命理总批")).font(Typo.ui(17, .bold)).foregroundColor(p.ink)
                        Text(L("今天这支签，和你这一辈子的底色")).font(Typo.ui(10.5)).foregroundColor(p.ink3)
                    }
                    Spacer()
                    Button(action: close) { IconCircle(symbol: "xmark", size: 30) }.buttonStyle(PressStyle()).demoTarget("lot.close")
                }
                .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 6)
                Scroller {
                    VStack(spacing: 14) {
                        MysticFace(lot: lot, date: d)
                            .frame(width: 186, height: 302)
                            .shadow(color: Color.black.opacity(p.dark ? 0.45 : 0.12), radius: 26, x: 0, y: 16)
                            .padding(.top, 4)
                        Text(lot.poem).font(Typo.song(17, bold: true)).foregroundColor(p.ink).multilineTextAlignment(.center)
                        if let g = lot.displayPoemGloss { Text(g).font(Typo.ui(12)).italic().foregroundColor(p.ink2).multilineTextAlignment(.center) }
                        Text(lot.displayNote).font(Typo.ui(13)).foregroundColor(p.ink2).multilineTextAlignment(.center).lineSpacing(3)
                            .padding(.horizontal, 10)
                        if let pick = store.todayDraw?.pick {
                            HStack(spacing: 6) {
                                TrigramGlyph(lines: Mystic.trigrams[lot.trigrams.up], width: 12, color: p.ink2)
                                Text(L(Fortune.lineHints[((pick % 6) + 6) % 6])).font(Typo.ui(11.5, .semibold)).foregroundColor(p.ink2)
                            }
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "sparkles").foregroundColor(p.tint)
                            Text(L("今日一事：") + lot.displayOne).font(Typo.ui(12.5, .medium)).foregroundColor(p.ink).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(12).glass(16, depth: 0)
                        LifeReadingCard().id("lot.reading")
                        HStack(spacing: 8) {
                            Button(action: { ui.lotOpen = false; ui.go(.ask) }) {
                                HStack(spacing: 6) { Image(systemName: "mountain.2.fill"); Text(L("问山人一件事")) }
                                    .font(Typo.ui(13, .bold)).foregroundColor(p.onAccent)
                                    .frame(maxWidth: .infinity).frame(height: 40).background(Capsule().fill(p.accent))
                            }.buttonStyle(PressStyle())
                            ShareButton()
                        }
                        Text(L("签文为原创内容，仅供娱乐参考")).font(Typo.ui(10.5)).foregroundColor(p.ink3).padding(.bottom, 8)
                    }
                    .padding(.horizontal, 16)
                }
                .edgeFade(top: 8, bottom: 14)
            }
            .background(
                ZStack {
                    Backdrop()
                    RoundedRectangle(cornerRadius: 0).fill(p.dark ? Color.black.opacity(0.25) : Color.white.opacity(0.35))
                }
            )
        }
    }

    private func list(_ t: String, _ items: [String], _ sym: String, _ strong: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t).font(Typo.ui(11.5, .bold)).foregroundColor(p.ink2)
            ForEach(items, id: \.self) { s in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: sym).font(.system(size: 12, weight: .bold)).foregroundColor(strong ? p.ink : p.ink3)
                    Text(s).font(Typo.ui(12.5, .medium)).foregroundColor(strong ? p.ink : p.ink2).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glass(18, depth: 1)
    }

    @ViewBuilder
    private func aiBlock(_ lot: Lot, _ a: DayAlmanac) -> some View {
        let s = store.data.settings
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "wand.and.stars").foregroundColor(p.tint)
                Text(L("AI 解读")).font(Typo.ui(13, .bold)).foregroundColor(p.ink)
                Spacer()
                Text(L(s.aiOn ? (s.aiVerified ? "已连接你自己的接口" : "尚未测试连接") : "默认关闭")).font(Typo.ui(10.5)).foregroundColor(p.ink3)
            }
            if let cached = store.data.aiCache[store.qianDay] ?? (aiText.isEmpty ? nil : aiText) {
                Text(cached).font(Typo.ui(12.5)).foregroundColor(p.ink).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            } else if s.aiOn && s.aiVerified {
                Button(action: { run(lot, a) }) {
                    Text(L(aiBusy ? "正在解读…" : "让 AI 解读今天的签")).font(Typo.ui(12.5, .bold)).foregroundColor(p.onAccent)
                        .frame(maxWidth: .infinity).frame(height: 36).background(Capsule().fill(p.accent))
                }.buttonStyle(PressStyle()).disabled(aiBusy)
                if !aiError.isEmpty { Text(aiError).font(Typo.ui(11)).foregroundColor(p.ink2) }
            } else if s.aiOn {
                HStack {
                    Text(L("接口还没测试通过，去设置里点「测试连接」")).font(Typo.ui(11.5)).foregroundColor(p.ink2)
                    Spacer()
                    Button(L("去设置")) { ui.go(.settings) }.buttonStyle(.plain).font(Typo.ui(12, .bold)).foregroundColor(p.tint)
                }
            } else {
                Text(L("在「设置 → AI 解读」接入你自己的 API 后可用。本应用不内置任何算命后端，也不包含任何密钥。"))
                    .font(Typo.ui(11.5)).foregroundColor(p.ink2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .glass(16, depth: 0)
    }

    private func run(_ lot: Lot, _ a: DayAlmanac) {
        let s = store.data.settings
        aiBusy = true; aiError = ""
        AIClient.interpret(lot: lot, almanac: a, endpoint: s.aiEndpoint, model: s.aiModel) { r in
            aiBusy = false
            switch r {
            case .success(let t): aiText = t; store.data.aiCache[store.qianDay] = t; store.save()
            case .failure(let e): aiError = e.localizedDescription
            }
        }
    }

    private func close() { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { ui.lotOpen = false } }
}
