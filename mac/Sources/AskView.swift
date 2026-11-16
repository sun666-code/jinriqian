import SwiftUI
import AppKit

// MARK: - 问事页

struct AskView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    @State private var draft: String
    @State private var asked: String
    @State private var aiText = ""
    @State private var aiBusy = false
    @State private var aiError = ""

    init(initial: String = "") {
        _draft = State(initialValue: initial)
        _asked = State(initialValue: initial)
    }


    var body: some View {
        let s = store.data.settings
        let birth = s.birthOn ? s.birthDate : nil
        VStack(spacing: 0) {
            PageHeader(title: L("问山人"), subtitle: L(birth == nil ? "未填生辰：山人按当天黄历起卦" : "山人按你的八字起卦"), back: { ui.go(.home) })
            Scroller {
                VStack(alignment: .leading, spacing: 14) {
                    inputCard
                    if ui.tossing {
                        CoinToss().transition(.opacity)
                    } else if !asked.isEmpty {
                        answerCard(Oracle.ask(asked, birth: birth, birthHour: s.birthHour))
                    } else {
                        recent
                    }
                }
                .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 16)
            }
            .edgeFade()
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "mountain.2.fill").font(.system(size: 14, weight: .bold)).foregroundColor(p.ink3)
                Field(placeholder: L("有事问山人，直说"), text: $draft, size: 14, onSubmit: submit)
                Button(action: submit) {
                    Image(systemName: "arrow.up").font(.system(size: 13, weight: .bold)).foregroundColor(p.onAccent)
                        .frame(width: 32, height: 32).background(Circle().fill(p.accent))
                        .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.35 : 1)
                }.buttonStyle(PressStyle())
            }
            .padding(.leading, 14).padding(.trailing, 6).frame(height: 48)
            .background(Capsule().fill(p.glassFill2))
            .overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
        }
        .padding(14)
        .glass(22, depth: 1)
    }

    private func submit() {
        let q = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        aiText = ""; aiError = ""
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { asked = q; ui.tossing = true }
        if !Snap.active { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { ui.tossing = false }
            if !Snap.active { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
        }
        store.data.asks.removeAll { $0.question == q }
        store.data.asks.insert(AskRecord(question: q), at: 0)
        if store.data.asks.count > 12 { store.data.asks.removeLast(store.data.asks.count - 12) }
        store.save()
    }

    private func answerCard(_ a: OracleAnswer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                InkSeal(text: a.levelText, size: 62, color: p.ink, filled: a.level == .great || a.level == .good, angle: -6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("山人说")).font(Typo.song(11, bold: true)).foregroundColor(p.ink3)
                    Text("「\(a.question)」").font(Typo.ui(11.5)).foregroundColor(p.ink2).lineLimit(2)
                    Text(a.title).font(Typo.ui(17, .heavy)).foregroundColor(p.ink).fixedSize(horizontal: false, vertical: true)
                }
            }
            anglesView(a.angles)
            section(L("为什么"), a.reasons, "circle.fill", size: 5)
            section(L(a.level == .great || a.level == .good ? "加持办法" : "破解办法"), a.remedies, "sparkles", size: 10)
            aiBlock(a)
            HStack {
                Button(action: { withAnimation { asked = ""; draft = "" } }) {
                    Text(L("再问一件")).font(Typo.ui(12.5, .bold)).foregroundColor(p.ink)
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(Capsule().fill(p.glassFill2)).overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
                }.buttonStyle(PressStyle())
                Spacer()
                if !a.personal {
                    Button(L("填生辰，算得更准")) { ui.go(.settings) }.buttonStyle(.plain).font(Typo.ui(11.5, .bold)).foregroundColor(p.tint)
                }
            }
            Text(L("命理推算仅供娱乐参考，请勿据此做重大决定")).font(Typo.ui(10)).foregroundColor(p.ink3)
        }
        .padding(16)
        .glass(24, depth: 2, fill: p.heroTop)
    }

    /// 多角度合参：每种方法一行（方法 · 起出的结果 · 吉凶点 · 一句断语）
    private func anglesView(_ list: [Angle]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L("多角度合参")).font(Typo.ui(11.5, .bold)).foregroundColor(p.ink2)
                Spacer()
                let pos = list.filter { $0.score > 0 }.count, neg = list.filter { $0.score < 0 }.count
                Text(LF("%d 吉 · %d 凶 · %d 平", pos, neg, list.count - pos - neg)).font(Typo.ui(10.5, .semibold)).foregroundColor(p.ink3)
            }
            .padding(.bottom, 8)
            ForEach(Array(list.enumerated()), id: \.offset) { i, g in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: g.symbol).font(.system(size: 12, weight: .semibold)).foregroundColor(p.ink)
                        .frame(width: 26, height: 26).background(Circle().fill(p.glassFill2))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(g.method).font(Typo.ui(12, .bold)).foregroundColor(p.ink)
                            Text(g.result).font(Typo.song(11.5, bold: true)).foregroundColor(p.ink2).lineLimit(1)
                            Spacer(minLength: 2)
                            scoreDots(g.score)
                        }
                        Text(g.verdict).font(Typo.ui(11.5)).foregroundColor(p.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) { if i < list.count - 1 { Rectangle().fill(p.hairline).frame(height: 1).padding(.leading, 36) } }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(p.glassFill2))
    }

    private func scoreDots(_ s: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(-2...2, id: \.self) { k in
                let on = (s > 0 && k > 0 && k <= s) || (s < 0 && k < 0 && k >= s) || (s == 0 && k == 0)
                Circle().fill(on ? (k >= 0 ? p.ink : Color.clear) : p.ink3.opacity(0.25))
                    .overlay(Circle().strokeBorder(on && k < 0 ? p.ink : Color.clear, lineWidth: 1.2))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func section(_ title: String, _ items: [String], _ sym: String, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Typo.ui(11.5, .bold)).foregroundColor(p.ink2)
            ForEach(Array(items.enumerated()), id: \.offset) { _, t in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: sym).font(.system(size: size, weight: .bold)).foregroundColor(p.ink).frame(width: 12).padding(.top, size < 8 ? 6 : 3)
                    Text(t).font(Typo.ui(12.5, .medium)).foregroundColor(p.ink).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func aiBlock(_ a: OracleAnswer) -> some View {
        let s = store.data.settings
        if s.aiOn && s.aiVerified {
            VStack(alignment: .leading, spacing: 6) {
                if !aiText.isEmpty {
                    Text(aiText).font(Typo.ui(12.5)).foregroundColor(p.ink).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                } else {
                    Button(action: { runAI(a) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                            Text(L(aiBusy ? "正在细说…" : "让 AI 细说这一卦"))
                        }
                        .font(Typo.ui(12.5, .bold)).foregroundColor(p.ink)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(Capsule().fill(p.glassFill2)).overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
                    }.buttonStyle(PressStyle()).disabled(aiBusy)
                    if !aiError.isEmpty { Text(aiError).font(Typo.ui(11)).foregroundColor(p.ink2) }
                }
            }
        }
    }

    private func runAI(_ a: OracleAnswer) {
        let s = store.data.settings
        aiBusy = true; aiError = ""
        // 只发送推算结论，不发送生辰
        let prompt = """
        你是一位隐居山中、话不多但一针见血的老先生（自称“山人”）。用户问：「\(a.question)」。
        本地推算结论：\(a.levelText)。依据：\(a.reasons.joined(separator: "；"))。
        多角度起课：\(a.angles.map { "\($0.method)【\($0.result)】\($0.verdict)" }.joined(separator: "；"))。
        建议：\(a.remedies.joined(separator: "；"))。
        请用 150 字以内的\(I18n.en ? "英文" : "简体中文")，口语化地把这件事说透：先给结论，再说一个具体的注意点和一个破解小办法。结尾注明“仅供娱乐参考”。
        """
        AIClient.chat(prompt, base: s.aiEndpoint, model: s.aiModel) { r in
            aiBusy = false
            switch r {
            case .success(let t): aiText = t
            case .failure(let e): aiError = e.localizedDescription
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("最近问过")).font(Typo.ui(12, .bold)).foregroundColor(p.ink2)
            if store.data.asks.isEmpty {
                Text(L("还没问过。问问今天下午能不能谈事、晚上适不适合出门。")).font(Typo.ui(12)).foregroundColor(p.ink3)
            }
            Collapsible(store.data.asks, spacing: 2) { r in
                Button(action: { draft = r.question; submit() }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath").font(.system(size: 11)).foregroundColor(p.ink3)
                        Text(r.question).font(Typo.ui(12.5)).foregroundColor(p.ink).lineLimit(1)
                        Spacer()
                        Text(Days.md(r.at)).font(Typo.ui(10.5)).foregroundColor(p.ink3)
                    }.padding(.vertical, 4)
                }.buttonStyle(.plain)
            }
        }
        .padding(14)
        .glass(22, depth: 1)
    }
}
