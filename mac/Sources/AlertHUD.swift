import SwiftUI
import AppKit

// MARK: - 到点弹窗：时间到了在屏幕右上角弹出一张玻璃卡片（不依赖系统通知是否被允许）

struct AlertItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let time: Date
    let isFocus: Bool
}

struct AlertCard: View {
    @Environment(\.pal) private var p
    let item: AlertItem
    var onDone: () -> Void
    var onSnooze: () -> Void
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isFocus ? "timer" : "alarm.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(p.onAccent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(p.accent))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.isFocus ? L("番茄钟结束") : L("待办时间到了") + " · " + Days.hm(item.time))
                    .font(Typo.ui(11, .bold)).foregroundColor(p.ink2)
                Text(item.title).font(Typo.ui(15, .bold)).foregroundColor(p.ink).lineLimit(2)
            }
            Spacer(minLength: 4)
            VStack(spacing: 6) {
                Button(action: onDone) {
                    Text(L(item.isFocus ? "好的" : "完成")).font(Typo.ui(12, .bold)).foregroundColor(p.onAccent)
                        .frame(width: 74, height: 28).background(Capsule().fill(p.accent))
                }.buttonStyle(PressStyle())
                Button(action: item.isFocus ? onClose : onSnooze) {
                    Text(L(item.isFocus ? "关闭" : "10 分钟后")).font(Typo.ui(11.5, .semibold)).foregroundColor(p.ink)
                        .frame(width: 74, height: 26).background(Capsule().fill(p.glassFill2))
                        .overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
                }.buttonStyle(PressStyle())
            }
        }
        .padding(14)
        .frame(width: 340)
        .background(
            ZStack {
                Backdrop()
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(p.glassFill)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(LinearGradient(colors: [p.strokeTop, p.strokeBottom], startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }
}

final class AlertPresenter {
    static let shared = AlertPresenter()
    private var panel: NSPanel?
    weak var store: Store?
    private var queue: [AlertItem] = []
    private var current: AlertItem?

    func show(_ item: AlertItem) {
        if current?.id == item.id { return }
        if current != nil { if !queue.contains(item) { queue.append(item) }; return }
        current = item
        NSSound(named: "Glass")?.play()
        let view = PaletteProvider {
            AlertCard(item: item,
                      onDone: { [weak self] in if !item.isFocus { self?.store?.setDone(id: item.id) }; self?.dismiss() },
                      onSnooze: { [weak self] in self?.store?.snooze(id: item.id); self?.dismiss() },
                      onClose: { [weak self] in self?.dismiss() })
        }
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 340, height: 96)
        let size = host.fittingSize
        let p = panel ?? {
            let np = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: false)
            np.isOpaque = false
            np.backgroundColor = .clear
            np.hasShadow = true
            np.level = .statusBar
            np.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            return np
        }()
        p.contentView = host
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            p.setFrame(NSRect(x: f.maxX - size.width - 14, y: f.maxY - size.height - 10, width: size.width, height: size.height), display: true)
        }
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { c in c.duration = 0.25; p.animator().alphaValue = 1 }
        panel = p
    }

    func dismiss() {
        guard let p = panel else { return }
        NSAnimationContext.runAnimationGroup({ c in c.duration = 0.18; p.animator().alphaValue = 0 }, completionHandler: { [weak self] in
            p.orderOut(nil)
            self?.current = nil
            if let next = self?.queue.first { self?.queue.removeFirst(); self?.show(next) }
        })
    }
}
