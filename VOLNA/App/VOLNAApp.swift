import SwiftUI

@main
struct VOLNAApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .tint(.volnaPurple)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                appState.player.saveState()
            }
        }
    }
}
