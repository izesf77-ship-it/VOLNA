import SwiftUI

@main
struct VOLNAApp: App {
    // Shared application state
    @State private var appState = AppState()
    
    init() {
        // Configure audio session on app launch
        configureAudioSession()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: []
            )
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
}

import AVFoundation
