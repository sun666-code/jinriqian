import SwiftUI

let panelSize = CGSize(width: 420, height: 700)

struct RootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.colorScheme) private var systemScheme
    var forcedScheme: ColorScheme? = nil
    var translucent = true

    var body: some View {
        let mode = store.data.settings.appearance
        let scheme: ColorScheme = forcedScheme ?? (mode == .system ? systemScheme : (mode == .dark ? .dark : .light))
        PaletteProvider {
            Shell(translucent: translucent)
        }
        .environment(\.colorScheme, scheme)
        .frame(width: panelSize.width, height: panelSize.height)
        .coordinateSpace(name: "demoRoot")
    }
}

struct Shell: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var ui: UIState
    @Environment(\.pal) private var p
    var translucent: Bool

    private let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)

    var body: some View {
        ZStack {
            Backdrop().opacity(translucent ? 0.74 : 1)
            if !store.data.settings.birthOn {
                BirthGate().transition(.opacity)
            } else if store.needsDraw {
                DrawView(onFinish: finishDraw)
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .top).combined(with: .opacity)))
            } else {
                HStack(spacing: 0) {
                    content
                    SideRail()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(LinearGradient(colors: [Color.white.opacity(p.dark ? 0.18 : 0.9), Color.white.opacity(p.dark ? 0.03 : 0.3)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }

    /// 左边主内容：页面 + 各种浮层（只盖住内容区，侧栏始终可点）
    private var content: some View {
        ZStack {
            page.transition(.opacity)
            if ui.dockOpen {
                dim { ui.dockOpen = false }.zIndex(5)
                VStack { Spacer(); DockPanel() }
                    .transition(.move(edge: .bottom))
                    .zIndex(6)
            }
            if ui.composerOpen {
                dim { ui.composerOpen = false }.zIndex(8)
                VStack {
                    Spacer()
                    TodoComposer(initial: ui.scheduleDraft)
                        .padding(18)
                        .glass(30, depth: 2, fill: p.dark ? Color(hex: 0x2A2A2D, alpha: 0.97) : Color.white.opacity(0.97))
                        .padding(10)
                }
                .transition(.move(edge: .bottom))
                .zIndex(9)
            }
            if ui.shareOpen {
                dim { ui.shareOpen = false }.zIndex(10)
                VStack {
                    Spacer()
                    SharePanel(initialPromise: Snap.active ? L("今天 15:00 约你喝咖啡，宜谈事 ☕️") : "")
                        .padding(18)
                        .glass(30, depth: 2, fill: p.dark ? Color(hex: 0x2A2A2D, alpha: 0.97) : Color.white.opacity(0.97))
                        .padding(10)
                }
                .transition(.move(edge: .bottom))
                .zIndex(11)
            }
            if ui.lotOpen {
                LotSheet()
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .scale(scale: 0.96, anchor: .trailing)),
                                            removal: .move(edge: .trailing).combined(with: .opacity)))
                    .zIndex(7)
            }
            if ui.weatherOpen {
                Color.black.opacity(0.001).onTapGesture { withAnimation(spring) { ui.weatherOpen = false } }.zIndex(12)
                VStack { WeatherPopover(); Spacer() }
                    .padding(.top, 14).padding(.horizontal, 12)
                    .transition(.scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity))
                    .zIndex(13)
            }
            if ui.chatOpen {
                dim { ui.chatOpen = false }.zIndex(14)
                HermitChat()
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .scale(scale: 0.94, anchor: .bottomTrailing)),
                                            removal: .move(edge: .trailing).combined(with: .opacity)))
                    .zIndex(15)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func dim(_ close: @escaping () -> Void) -> some View {
        Color.black.opacity(p.dark ? 0.45 : 0.12)
            .onTapGesture { withAnimation(spring) { close() } }
            .transition(.opacity)
    }

    @ViewBuilder
    private var page: some View {
        switch ui.page {
        case .home: HomeView().transition(.opacity)
        case .schedule: ScheduleView().transition(.move(edge: .trailing))
        case .pickDay: PickDayView().transition(.move(edge: .trailing))
        case .notes: NotesView().transition(.move(edge: .trailing))
        case .note(let id): NoteDetailView(id: id).transition(.move(edge: .trailing))
        case .calendar: CalendarView().transition(.move(edge: .trailing))
        case .album: AlbumView().transition(.move(edge: .trailing))
        case .settings: SettingsView(demoVerified: Snap.active, demoEditBirth: Snap.active && ui.birthEditing).transition(.move(edge: .trailing))
        case .ask: HomeView().transition(.opacity)
        case .fortune: FortunePage().transition(.move(edge: .trailing))
        }
    }

    private func finishDraw() {
        ui.tagDropped = false
        withAnimation(.easeInOut(duration: 0.35)) {
            ui.page = .home
            ui.selectedDay = Days.todayKey
        }
        store.update { $0.tagCollapsed = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.58)) { ui.tagDropped = true }
            ui.drawFlipped = false
            ui.drawPulled = false
            ui.drawAngle = 0
        }
    }
}
