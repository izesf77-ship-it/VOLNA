import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        ZStack(alignment: .bottom) {
            VolnaBackground()
                .ignoresSafeArea()

            Group {
                switch appState.selectedTab {
                case .home:
                    HomeView()
                case .search:
                    SearchView()
                case .library:
                    LibraryView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .scale(scale: 0.995)))
            .animation(.easeInOut(duration: 0.2), value: appState.selectedTab)

            // Floating bottom controls (mini player + tab bar)
            VStack(spacing: VolnaLayout.floatingStackSpacing) {
                if appState.player.currentTrack != nil {
                    MiniPlayerView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                VolnaTabBar(selection: $state.selectedTab)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, VolnaLayout.tabBarBottomMargin)
            .background {
                // Subtle fade so content doesn't clash with floating bar
                LinearGradient(
                    colors: [
                        Color.volnaBackground.opacity(0),
                        Color.volnaBackground.opacity(0.55),
                        Color.volnaBackground.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $state.isPlayerPresented) {
            PlayerView()
                .environment(appState)
        }
    }
}

struct VolnaTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = tab == selection
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(Color.volnaAccentGradient.opacity(0.22))
                                    .frame(width: 56, height: 32)
                                    .matchedGeometryEffect(id: "tab-bg", in: tabNamespace)
                            }
                            Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                                .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                                .symbolRenderingMode(.hierarchical)
                        }
                        .frame(height: 32)

                        Text(tab.title)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .default))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(isSelected ? Color.volnaTextPrimary : Color.volnaTextTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: VolnaLayout.tabBarHeight)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.volnaSurfaceGlass)
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.14), Color.white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
        }
        .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
