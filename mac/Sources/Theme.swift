import SwiftUI
import AppKit

// MARK: - 外观模式

enum AppearanceMode: String, Codable, CaseIterable {
    case system, light, dark
    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

// MARK: - 调色板（全局无红色系）
// 深色：深色磨玻璃 + 荧光黄绿卡片；浅色：苹果原生白净 + 冷蓝微光。

struct Palette {
    let dark: Bool
    let bgTop: Color
    let bgBottom: Color
    let orbs: [Color]
    let ink: Color
    let ink2: Color
    let ink3: Color
    let accent: Color        // 主强调：深色=荧光黄绿，浅色=墨黑
    let onAccent: Color
    let tint: Color          // 次强调：蓝（深色=柔和雾蓝，不刺眼；浅色=沉稳的蓝）
    let glassFill: Color
    let glassFill2: Color    // 嵌套层（玻璃里的胶囊）
    let strokeTop: Color
    let strokeBottom: Color
    let shadow: Color
    let hairline: Color
    let heroTop: Color       // 今日提醒主卡
    let heroBottom: Color
    let heroInk: Color
    let heroInk2: Color
    let heroChip: Color

    static func make(dark: Bool) -> Palette {
        if dark {
            // 苹果原生深色：中性灰黑，不带任何彩色倾向；强调色 = 白，次强调 = 系统蓝
            return Palette(
                dark: true,
                bgTop: Color(hex: 0x232325),
                bgBottom: Color(hex: 0x141416),
                orbs: [Color.white.opacity(0.07), Color.white.opacity(0.04), Color(hex: 0x8E9BB5, alpha: 0.07)],
                ink: Color.white.opacity(0.95),
                ink2: Color.white.opacity(0.60),
                ink3: Color.white.opacity(0.34),
                accent: Color(hex: 0xF5F5F7),
                onAccent: Color(hex: 0x111113),
                tint: Color(hex: 0x7EA6E0),
                glassFill: Color.white.opacity(0.07),
                glassFill2: Color.white.opacity(0.06),
                strokeTop: Color.white.opacity(0.20),
                strokeBottom: Color.white.opacity(0.03),
                shadow: Color.black.opacity(0.45),
                hairline: Color.white.opacity(0.08),
                heroTop: Color.white.opacity(0.13),
                heroBottom: Color.white.opacity(0.07),
                heroInk: Color.white.opacity(0.95),
                heroInk2: Color.white.opacity(0.58),
                heroChip: Color.white.opacity(0.07)
            )
        } else {
            // 苹果原生浅色：纯净冷白，几乎无色偏
            return Palette(
                dark: false,
                bgTop: Color(hex: 0xF7F7F9),
                bgBottom: Color(hex: 0xEDEDF0),
                orbs: [Color.white.opacity(0.9), Color.white.opacity(0.7), Color(hex: 0xDDE3EE, alpha: 0.45)],
                ink: Color(hex: 0x111113),
                ink2: Color(hex: 0x111113, alpha: 0.55),
                ink3: Color(hex: 0x111113, alpha: 0.30),
                accent: Color(hex: 0x111113),
                onAccent: .white,
                tint: Color(hex: 0x2F6BD0),
                glassFill: Color.white.opacity(0.62),
                glassFill2: Color(hex: 0x111113, alpha: 0.04),
                strokeTop: Color.white.opacity(1.0),
                strokeBottom: Color(hex: 0x111113, alpha: 0.06),
                shadow: Color(hex: 0x1C1C24, alpha: 0.09),
                hairline: Color(hex: 0x111113, alpha: 0.07),
                heroTop: Color.white.opacity(0.90),
                heroBottom: Color.white.opacity(0.70),
                heroInk: Color(hex: 0x111113),
                heroInk2: Color(hex: 0x111113, alpha: 0.52),
                heroChip: Color(hex: 0x111113, alpha: 0.045)
            )
        }
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.make(dark: true)
}

extension EnvironmentValues {
    var pal: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

struct PaletteProvider<Content: View>: View {
    @Environment(\.colorScheme) private var cs
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.environment(\.pal, Palette.make(dark: cs == .dark))
    }
}

// MARK: - 字体

enum Typo {
    static func song(_ size: CGFloat, bold: Bool = false) -> Font {
        let f = Font.custom("Songti SC", size: size)
        return bold ? f.weight(.bold) : f
    }
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    /// 手写感字体（系统若装有则用，否则回退到圆体）
    static let handName: String? = {
        for n in ["HannotateSC-W5", "HanziPenSC-W3", "Wawati SC", "STXingkai", "Kaiti SC", "STKaiti"] where NSFont(name: n, size: 12) != nil { return n }
        return nil
    }()
    static func hand(_ size: CGFloat) -> Font {
        if let n = handName { return Font.custom(n, size: size) }
        return .system(size: size, weight: .semibold, design: .rounded)
    }
    static func num(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - 多层磨砂玻璃
// 第 1 层：底色（半透明）  第 2 层：顶部高光渐变  第 3 层：上亮下暗的描边
// 第 4 层：近处小阴影 + 远处大阴影，形成悬浮深度。

struct GlassModifier: ViewModifier {
    @Environment(\.pal) private var p
    var radius: CGFloat
    var depth: Int
    var fill: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(
                ZStack {
                    shape.fill(fill ?? p.glassFill)
                    shape.fill(LinearGradient(colors: [Color.white.opacity(p.dark ? 0.09 : 0.65), Color.white.opacity(0)],
                                              startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55)))
                }
            )
            .overlay(
                shape.strokeBorder(LinearGradient(colors: [p.strokeTop, p.strokeBottom], startPoint: .top, endPoint: .bottom),
                                   lineWidth: 1)
            )
            .shadow(color: p.shadow.opacity(depth == 0 ? 0 : 0.6), radius: 2, x: 0, y: 1)
            .shadow(color: p.shadow.opacity(depth == 0 ? 0.0 : 1), radius: depth >= 2 ? 26 : 14, x: 0, y: depth >= 2 ? 16 : 8)
    }
}

extension View {
    func glass(_ radius: CGFloat = 22, depth: Int = 1, fill: Color? = nil) -> some View {
        modifier(GlassModifier(radius: radius, depth: depth, fill: fill))
    }
}

// MARK: - 背景：渐变 + 柔光球（模拟景深）

struct Backdrop: View {
    @Environment(\.pal) private var p
    var body: some View {
        ZStack {
            LinearGradient(colors: [p.bgTop, p.bgBottom], startPoint: .top, endPoint: .bottom)
            GeometryReader { g in
                let w = g.size.width, h = g.size.height
                ZStack {
                    orb(p.orbs[0], size: w * 1.1).position(x: w * 0.05, y: h * 0.08)
                    orb(p.orbs[1], size: w * 0.9).position(x: w * 1.0, y: h * 0.42)
                    orb(p.orbs[2], size: w * 1.0).position(x: w * 0.15, y: h * 0.95)
                }
            }
            InkMountains()
            PaperGrain()
        }
    }
    private func orb(_ c: Color, size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [c, c.opacity(0)], center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
    }
}

// MARK: - 通用小组件

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct IconCircle: View {
    @Environment(\.pal) private var p
    let symbol: String
    var size: CGFloat = 34
    var filled = false
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundColor(filled ? p.onAccent : p.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(filled ? p.accent : p.glassFill2))
            .overlay(Circle().strokeBorder(filled ? Color.clear : p.hairline, lineWidth: 1))
    }
}

struct PageHeader: View {
    @Environment(\.pal) private var p
    let title: String
    var subtitle: String? = nil
    var back: () -> Void
    var trailing: AnyView? = nil
    var body: some View {
        // 统一：关闭按钮都在右上角（和侧栏同一边），侧栏上再点一次同一个按钮也能收起
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Typo.ui(17, .bold)).foregroundColor(p.ink)
                if let s = subtitle { Text(s).font(Typo.ui(11)).foregroundColor(p.ink2).lineLimit(1) }
            }
            Spacer()
            if let t = trailing { t }
            Button(action: back) { IconCircle(symbol: "xmark", size: 30) }
                .buttonStyle(PressStyle())
                .demoTarget("page.close")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

struct SectionTitle: View {
    @Environment(\.pal) private var p
    let text: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(L(text)).font(Typo.ui(13, .semibold)).foregroundColor(p.ink2)
            Spacer()
            if let t = trailing {
                Button(action: { action?() }) {
                    HStack(spacing: 2) {
                        Text(t)
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                    }
                    .font(Typo.ui(12, .semibold)).foregroundColor(p.dark ? p.accent : p.tint)
                }.buttonStyle(.plain)
            }
        }
    }
}

/// 自绘开关（原生开关在离屏截图中无法渲染，也更贴合玻璃风格）
struct GlassToggle: View {
    @Environment(\.pal) private var p
    @Binding var isOn: Bool
    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { isOn.toggle() } }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? p.accent : p.glassFill2)
                    .overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
                Circle().fill(isOn ? p.onAccent : (p.dark ? Color.white.opacity(0.85) : Color.white))
                    .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
                    .padding(3)
            }
            .frame(width: 44, height: 26)
        }
        .buttonStyle(.plain)
    }
}

/// 分段选择（自绘）
struct Segmented<T: Hashable>: View {
    @Environment(\.pal) private var p
    let items: [(T, String)]
    @Binding var selection: T
    var body: some View {
        HStack(spacing: 4) {
            ForEach(items.indices, id: \.self) { i in
                let it = items[i]
                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = it.0 } }) {
                    Text(it.1)
                        .font(Typo.ui(12, .semibold))
                        .foregroundColor(selection == it.0 ? p.onAccent : p.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(selection == it.0 ? p.accent : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(p.glassFill2))
        .overlay(Capsule().strokeBorder(p.hairline, lineWidth: 1))
    }
}

struct Chip: View {
    @Environment(\.pal) private var p
    let text: String
    var strong = false
    var body: some View {
        Text(L(text))
            .font(Typo.ui(11.5, .semibold))
            .foregroundColor(strong ? p.onAccent : p.ink)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(strong ? p.accent : p.glassFill2))
            .overlay(Capsule().strokeBorder(strong ? Color.clear : p.hairline, lineWidth: 1))
    }
}

/// 简单的流式换行布局（macOS 13 Layout 协议）
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxW, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

extension Palette {
    /// 表盘专用的黑白色（不用蓝色）：深色模式是白，浅色模式是墨黑
    var mono: Color { dark ? Color.white.opacity(0.92) : Color(hex: 0x1A1A1C) }
    var onMono: Color { dark ? Color(hex: 0x111113) : .white }

    /// 铜金底色上的文字：深色模式用墨色，浅色模式用白色
    var onTint: Color { dark ? Color(hex: 0x16130B) : .white }
}
