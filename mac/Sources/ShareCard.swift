import SwiftUI
import AppKit

// MARK: - 分享今日签：生成一张图片卡（可加一句约定），复制后直接粘贴到微信，或保存 / 系统分享

struct ShareCardView: View {
    let lot: Lot
    let reading: Reading
    let date: Date
    let promise: String
    let dark: Bool

    var body: some View {
        let ink = dark ? Color.white : Color(hex: 0x111113)
        let ink2 = ink.opacity(0.6)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("今日签")).font(Typo.song(15, bold: true)).foregroundColor(ink)
                Spacer()
                Text(Days.md(date) + " " + Days.weekday(date)).font(Typo.ui(12, .semibold)).foregroundColor(ink2)
            }
            HStack(alignment: .top, spacing: 14) {
                FolkArt(no: lot.no, compact: true).frame(width: 82, height: 118).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text(lot.levelText + " · " + lot.displayName).font(Typo.ui(12, .bold)).foregroundColor(ink2)
                    Text(lot.poem).font(Typo.song(16, bold: true)).foregroundColor(ink).fixedSize(horizontal: false, vertical: true)
                    if let g = lot.displayPoemGloss { Text(g).font(Typo.ui(11)).italic().foregroundColor(ink2) }
                }
            }
            Text(reading.headline).font(Typo.ui(15, .heavy)).foregroundColor(ink).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(reading.goodHours.prefix(1).enumerated()), id: \.offset) { _, g in
                    row("✓", g.0.range, g.1, ink: ink, ink2: ink2)
                }
                ForEach(Array(reading.badHours.prefix(1).enumerated()), id: \.offset) { _, b in
                    row("!", b.0.range, b.1, ink: ink, ink2: ink2)
                }
            }
            if !promise.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "hand.wave.fill").font(.system(size: 13)).foregroundColor(ink)
                    Text(promise).font(Typo.ui(14, .bold)).foregroundColor(ink).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ink.opacity(0.07)))
            }
            HStack {
                Text("☯ " + reading.hexName).font(Typo.song(12, bold: true)).foregroundColor(ink2)
                Spacer()
                Text(L("今日签 · 仅供娱乐参考")).font(Typo.ui(10)).foregroundColor(ink2)
            }
        }
        .padding(22)
        .frame(width: 340)
        .background(
            ZStack {
                LinearGradient(colors: dark ? [Color(hex: 0x2A2A2E), Color(hex: 0x151517)] : [Color.white, Color(hex: 0xF0F0F3)],
                               startPoint: .top, endPoint: .bottom)
                Circle().fill(RadialGradient(colors: [Tone.color(lot.tone).opacity(dark ? 0.25 : 0.7), .clear], center: .center, startRadius: 0, endRadius: 160))
                    .frame(width: 320, height: 320).offset(x: 120, y: -150)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .environment(\.pal, Palette.make(dark: dark))
    }

    private func row(_ mark: String, _ range: String, _ text: String, ink: Color, ink2: Color) -> some View {
        HStack(spacing: 8) {
            Text(mark).font(Typo.ui(12, .heavy)).foregroundColor(ink).frame(width: 18)
            Text(range).font(Typo.num(13, .bold)).foregroundColor(ink)
            Text(text).font(Typo.ui(12.5, .semibold)).foregroundColor(ink).lineLimit(1)
        }
    }
}

struct SharePanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    @State private var promise: String
    @State private var status = ""
    @State private var anchor = AnchorHolder()

    init(initialPromise: String = "") { _promise = State(initialValue: initialPromise) }

    var body: some View {
        if let lot = store.todayLot {
            let s = store.data.settings
            let r = Fortune.reading(for: Days.now, birth: s.birthOn ? s.birthDate : nil, birthHour: s.birthHour)
            let card = ShareCardView(lot: lot, reading: r, date: Days.now, promise: promise, dark: p.dark)
            VStack(spacing: 12) {
                HStack {
                    Text(L("分享今日签")).font(Typo.ui(17, .heavy)).foregroundColor(p.ink)
                    Spacer()
                    Button(action: close) { IconCircle(symbol: "xmark", size: 30) }.buttonStyle(PressStyle())
                }
                card.scaleEffect(0.78).frame(width: 266, height: 316).allowsHitTesting(false).frame(maxWidth: .infinity)
                    .shadow(color: Color.black.opacity(p.dark ? 0.5 : 0.15), radius: 16, x: 0, y: 8)
                HStack(spacing: 8) {
                    Image(systemName: "hand.wave").font(.system(size: 12, weight: .bold)).foregroundColor(p.ink3)
                    Field(placeholder: L("加一句约定（可选）：今天 15:00 约你喝咖啡"), text: $promise, size: 12.5)
                }
                .padding(.horizontal, 12).frame(height: 38)
                .background(Capsule().fill(p.glassFill2)).overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
                HStack(spacing: 8) {
                    action(L("复制图片"), "doc.on.doc", primary: true) { copy(card) }
                    action(L("保存"), "square.and.arrow.down", primary: false) { saveFile(card) }
                    action(L("分享…"), "square.and.arrow.up", primary: false) { share(card) }
                        .background(Group { if !Snap.active { AnchorView(holder: anchor) } })
                }
                Text(status.isEmpty ? L("复制后打开微信，在聊天框里粘贴（⌘V）就能发出去") : status)
                    .font(Typo.ui(10.5)).foregroundColor(p.ink2)
            }
        }
    }

    private func action(_ t: String, _ sym: String, primary: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 5) { Image(systemName: sym).font(.system(size: 11, weight: .bold)); Text(t).font(Typo.ui(12.5, .bold)) }
                .foregroundColor(primary ? p.onAccent : p.ink)
                .frame(maxWidth: .infinity).frame(height: 38)
                .background(Capsule().fill(primary ? p.accent : p.glassFill2))
                .overlay(Capsule().strokeBorder(primary ? Color.clear : p.hairline, lineWidth: 1))
        }.buttonStyle(PressStyle())
    }

    @MainActor private func render(_ card: ShareCardView) -> NSImage? {
        let r = ImageRenderer(content: card)
        r.scale = 3
        return r.nsImage
    }

    @MainActor private func copy(_ card: ShareCardView) {
        guard let img = render(card) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([img])
        status = L("已复制。打开微信聊天框，粘贴（⌘V）即可发送")
    }

    @MainActor private func fileURL(_ card: ShareCardView) -> URL? {
        guard let img = render(card), let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("今日签-\(Days.todayKey).png")
        try? png.write(to: url)
        return url
    }

    @MainActor private func saveFile(_ card: ShareCardView) {
        guard let url = fileURL(card) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        status = L("已保存到「下载」文件夹")
    }

    @MainActor private func share(_ card: ShareCardView) {
        guard let url = fileURL(card), let v = anchor.view else { return }
        let picker = NSSharingServicePicker(items: [url])
        picker.show(relativeTo: v.bounds, of: v, preferredEdge: .minY)
    }

    private func close() { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { ui.shareOpen = false } }
}

final class AnchorHolder { weak var view: NSView? }

struct AnchorView: NSViewRepresentable {
    let holder: AnchorHolder
    func makeNSView(context: Context) -> NSView { let v = NSView(); holder.view = v; return v }
    func updateNSView(_ nsView: NSView, context: Context) { holder.view = nsView }
}

/// 分享按钮（放在断语卡和看签页）
struct ShareButton: View {
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { ui.lotOpen = false; ui.shareOpen = true } }) {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 10.5, weight: .bold))
                Text(L("分享")).font(Typo.ui(11.5, .bold))
            }
            .foregroundColor(p.ink)
            .padding(.horizontal, 10).frame(height: 26)
            .background(Capsule().fill(p.glassFill2))
            .overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
        }.buttonStyle(PressStyle())
    }
}
