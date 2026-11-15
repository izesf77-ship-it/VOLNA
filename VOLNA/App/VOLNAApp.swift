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
                .onContinueUserActivity("com.volna.app.nowplaying") { activity in
                    handleNowPlayingActivity(activity)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                appState.player.saveState()
            }
        }
    }
    
    /// Обрабатывает нажатие на Now Playing в Dynamic Island / Lock Screen
    private func handleNowPlayingActivity(_ activity: NSUserActivity) {
        // Открываем полноэкранный плеер если есть что воспроизводить
        if appState.player.hasNowPlaying {
            appState.isPlayerPresented = true
        }
    }
}
