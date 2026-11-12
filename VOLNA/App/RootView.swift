import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        TabView(selection: Binding(
            get: { appState.selectedTab },
            set: { appState.selectedTab = $0 }
        )) {
            HomeView()
                .tabItem {
                    Label(AppTab.home.rawValue, systemImage: AppTab.home.icon)
                }
                .tag(AppTab.home)
            
            SearchView()
                .tabItem {
                    Label(AppTab.search.rawValue, systemImage: AppTab.search.icon)
                }
                .tag(AppTab.search)
            
            LibraryView()
                .tabItem {
                    Label(AppTab.library.rawValue, systemImage: AppTab.library.icon)
                }
                .tag(AppTab.library)
            
            SettingsView()
                .tabItem {
                    Label(AppTab.settings.rawValue, systemImage: AppTab.settings.icon)
                }
                .tag(AppTab.settings)
        }
        .tint(.volnaPurple)
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
