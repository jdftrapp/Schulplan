import SwiftUI

@main
struct SchulplanApp: App {
    @State private var store = Store()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task { await store.refresh() }
                .onChange(of: phase) { _, new in
                    if new == .active { Task { await store.refresh() } }
                }
        }
    }
}

struct RootView: View {
    @State private var showSettings = false
    @AppStorage("tab") private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            page { OverviewView() }
                .tabItem { Image(systemName: "house").accessibilityLabel("Morgen") }.tag(0)
            page { WeekView() }
                .tabItem { Image(systemName: "calendar").accessibilityLabel("Plan") }.tag(1)
            page { HomeworkView() }
                .tabItem { Image(systemName: "checklist").accessibilityLabel("Aufgaben") }.tag(2)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    /// No navigation bar: each page draws its own compact header with the settings button.
    private func page<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .environment(\.openSettings) { showSettings = true }
            // Scrolled content fades out under the status bar instead of running into the clock.
            // Solid page colour, so there is no visible band when nothing is scrolled (light or dark).
            .overlay(alignment: .top) {
                GeometryReader { g in
                    LinearGradient(stops: [.init(color: Color(.systemBackground), location: 0.55),
                                           .init(color: Color(.systemBackground).opacity(0), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: g.safeAreaInsets.top)
                        .offset(y: -g.safeAreaInsets.top)
                }
                .allowsHitTesting(false)
            }
    }
}
