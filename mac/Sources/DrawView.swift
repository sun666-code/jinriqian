import SwiftUI
import AppKit

// MARK: - 抽签：像从一本书里抽出一页纸
// 一叠斜放的签纸（无限张），上下滑动 / 滚轮翻动，正中那张立起来；
// 点它 → 从书里“抽出”（上移、放大、摆正）→ 翻面显示签文 → 收下进入首页。

struct OldDrawView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    var onFinish: () -> Void

    private let slipW: CGFloat = 300
    private let slipH: CGFloat = 178
    @State private var busy = false
    @State private var initialized = false

    var body: some View {
        let lot = LotLibrary.lot(store.lotNo(at: ui.drawIndex))
        let today = Days.date(fromKey: store.qianDay) ?? Days.now
        let a = Almanac.of(today)
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(Days.md(today) + " " + Days.weekday(today) + "　" + a.lunarFull)
                    .font(Typo.ui(12, .medium)).foregroundColor(p.ink2)
                Text(L(ui.drawFlipped ? "山人给你的签" : "向山人求一支签"))
                    .font(Typo.ui(25, .heavy)).foregroundColor(p.ink)
                Text(ui.drawFlipped ? lot.levelText + " · " + lot.displayName : L("上下滑动翻签，点中间那张抽出来"))
                    .font(Typo.ui(12.5)).foregroundColor(p.ink2)
            }
            .padding(.top, 26)

            ZStack {
                if !ui.drawPulled {
                    ForEach(window, id: \.self) { i in slip(i) }
                } else {
                    // 抽出来的那一张
                    Group {
                        if ui.drawFlipped {
                            LotFace(lot: lot, date: today)
                                .frame(width: 200, height: 292)
                        } else {
                            SlipBack(index: ui.drawIndex, focused: true)
                                .frame(width: slipW, height: slipH)
                        }
                    }
                    .rotation3DEffect(.degrees(ui.drawAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                    .shadow(color: Color.black.opacity(p.dark ? 0.55 : 0.16), radius: 30, x: 0, y: 20)
                    .transition(.asymmetric(insertion: .offset(y: 0).combined(with: .opacity), removal: .opacity))
                }
            }
            .frame(height: 360)
            .frame(maxWidth: .infinity)
            .clipped()
            .contentShape(Rectangle())
            .gesture(drag, including: ui.drawPulled ? .none : .all)
            .background(Group { if !Snap.active && !ui.drawPulled { ScrollCatcher(onScroll: { dy in scrollBy(dy) }) } })
            .padding(.top, 8)

            Spacer(minLength: 0)

            if ui.drawFlipped && ui.drawAngle == 0 {
                result(lot).transition(.move(edge: .bottom).combined(with: .opacity))
            } else if !ui.drawPulled {
                controls
            } else {
                Text(L("正在抽出…")).font(Typo.ui(12)).foregroundColor(p.ink3).padding(.bottom, 40)
            }
        }
        .padding(.bottom, 18)
        .onAppear {
            if !initialized && !Snap.active { ui.drawIndex = store.startIndex; initialized = true }
        }
    }

    private var window: [Int] { Array((ui.drawIndex - 7)...(ui.drawIndex + 7)) }

    // MARK: 牌堆中的一张

    @ViewBuilder
    private func slip(_ i: Int) -> some View {
        let rel = Double(i - ui.drawIndex) + Double(ui.drawDrag)
        let a = abs(rel)
        let sign: Double = rel < 0 ? -1 : 1
        let y = sign * (min(a, 1) * 118 + max(a - 1, 0) * 24)
        let tilt = max(-68, min(68, rel * 64))
        SlipBack(index: i, focused: a < 0.5)
            .frame(width: slipW, height: slipH)
            .rotation3DEffect(.degrees(-tilt), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.45)
            .scaleEffect(1 - min(a, 6) * 0.035)
            .shadow(color: Color.black.opacity(a < 0.5 ? (p.dark ? 0.55 : 0.16) : (p.dark ? 0.35 : 0.06)),
                    radius: a < 0.5 ? 24 : 6, x: 0, y: a < 0.5 ? 16 : 3)
            .offset(y: y)
            .blur(radius: max(0, a - 1.2) * 0.9)
            .opacity(max(0, 1 - max(0, a - 4.5) * 0.5))
            .zIndex(-a)
            .onTapGesture { if a < 0.5 { pull() } else { select(i) } }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { v in ui.drawDrag = v.translation.height / 70 }
            .onEnded { v in
                let predicted = v.predictedEndTranslation.height / 70
                let target = Int((Double(ui.drawIndex) - Double(predicted)).rounded())
                withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                    ui.drawIndex = target
                    ui.drawDrag = 0
                }
            }
    }

    @State private var scrollAcc: CGFloat = 0
    private func scrollBy(_ dy: CGFloat) {
        scrollAcc += dy
        if abs(scrollAcc) > 18 {
            let step = scrollAcc > 0 ? -1 : 1
            scrollAcc = 0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { ui.drawIndex += step }
        }
    }

    private func select(_ i: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) { ui.drawIndex = i }
    }

    private func pull() {
        guard !ui.drawPulled, !busy else { return }
        busy = true
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { ui.drawPulled = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeIn(duration: 0.2)) { ui.drawAngle = 90 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                ui.drawFlipped = true
                ui.drawAngle = -90
                withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { ui.drawAngle = 0 }
                busy = false
            }
        }
    }

    // MARK: 控件

    private var controls: some View {
        VStack(spacing: 12) {
            Text(LF("第 %d 张 · 签库共 %d 支", ui.drawIndex, LotLibrary.all.count))
                .font(Typo.ui(11.5, .medium)).foregroundColor(p.ink3)
            HStack(spacing: 10) {
                Button(action: { select(ui.drawIndex - 1) }) { IconCircle(symbol: "chevron.up", size: 44) }
                    .buttonStyle(PressStyle())
                Button(action: pull) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.draw.fill").font(.system(size: 14, weight: .bold))
                        Text(L("抽出这一张")).font(Typo.ui(15, .bold))
                    }
                    .foregroundColor(p.onAccent)
                    .frame(width: 170, height: 48)
                    .background(Capsule().fill(p.accent))
                    .shadow(color: Color.black.opacity(p.dark ? 0.4 : 0.18), radius: 14, x: 0, y: 8)
                }
                .buttonStyle(PressStyle())
                Button(action: { select(ui.drawIndex + 1) }) { IconCircle(symbol: "chevron.down", size: 44) }
                    .buttonStyle(PressStyle())
            }
            .padding(8)
            .glass(32, depth: 2)
            Text(L("签文为原创 · 仅供娱乐参考")).font(Typo.ui(10.5)).foregroundColor(p.ink3)
        }
    }

    private func result(_ lot: Lot) -> some View {
        VStack(spacing: 12) {
            Text(lot.displayNote)
                .font(Typo.ui(12.5)).foregroundColor(p.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 30)
            Button(action: {
                store.commitDraw(pick: ui.drawIndex)
                onFinish()
            }) {
                HStack(spacing: 8) {
                    Text(L("收下这支签")).font(Typo.ui(15, .bold))
                    Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(p.onAccent)
                .frame(width: 220, height: 48)
                .background(Capsule().fill(p.accent))
                .shadow(color: Color.black.opacity(p.dark ? 0.4 : 0.18), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(PressStyle())
        }
    }
}

/// 触控板两指手势：两指滑动（滚轮）与两指旋转。
/// 用本地事件监听而不是覆盖视图，确保 SwiftUI 内容上方也能收到；只在光标位于该区域时生效并吞掉事件，
/// 外层滚动区不会跟着动。
struct ScrollCatcher: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void = { _ in }
    var onScrollX: ((CGFloat) -> Void)? = nil
    var onRotate: ((CGFloat) -> Void)? = nil

    final class V: NSView {
        var onScroll: ((CGFloat) -> Void)?
        var onScrollX: ((CGFloat) -> Void)?
        var onRotate: ((CGFloat) -> Void)?
        private var monitor: Any?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }   // 不挡点击
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .rotate]) { [weak self] e in
                guard let self = self, let w = self.window, e.window === w else { return e }
                let p = self.convert(e.locationInWindow, from: nil)
                guard self.bounds.contains(p) else { return e }
                if e.type == .rotate {
                    guard let r = self.onRotate else { return e }
                    r(CGFloat(e.rotation)); return nil
                }
                let dx = e.scrollingDeltaX, dy = e.scrollingDeltaY
                if abs(dx) > abs(dy), let hx = self.onScrollX { hx(dx); return nil }
                if abs(dy) > 0 { self.onScroll?(dy); return nil }
                return e
            }
        }
        deinit { if let m = monitor { NSEvent.removeMonitor(m) } }
    }
    func makeNSView(context: Context) -> V { let v = V(); update(v); return v }
    func updateNSView(_ v: V, context: Context) { update(v) }
    private func update(_ v: V) { v.onScroll = onScroll; v.onScrollX = onScrollX; v.onRotate = onRotate }
}
