import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .scale(scale: 0.995)))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: appState.selectedTab)

            // Floating bottom controls (mini player + tab bar)
            VStack(spacing: VolnaLayout.floatingStackSpacing) {
                if appState.player.currentTrack != nil {
                    MiniPlayerView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                VolnaTabBar(selection: $state.selectedTab)
            }
            .padding(.horizontal, VolnaLayout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, VolnaLayout.tabBarBottomMargin)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: BottomControlsHeightKey.self,
                        value: proxy.size.height
                    )
                }
            }
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
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onPreferenceChange(BottomControlsHeightKey.self) { height in
            guard height > 0, abs(appState.bottomControlsHeight - height) > 0.5 else { return }
            appState.bottomControlsHeight = height
        }
        .fullScreenCover(isPresented: $state.isPlayerPresented) {
            PlayerView()
                .environment(appState)
        }
        // Каталог загружается один раз на уровне корня, а не только на
        // главной: поиск и настройки должны видеть те же реальные релизы,
        // даже если пользователь сразу переключил вкладку.
        .task {
            await appState.catalog.loadIfNeeded()
        }
        #if DEBUG
        .task {
            await applyScreenshotArguments()
        }
        #endif
    }

    #if DEBUG
    /// Управляет экраном для CI-скриншотов. Ждёт окончания загрузки каталога,
    /// потому что HomeView запускает её параллельно; без ожидания игрок мог
    /// открыться до появления первого трека.
    private func applyScreenshotArguments() async {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-uiScreenshotTab"),
           arguments.indices.contains(index + 1) {
            switch arguments[index + 1] {
            case "search": appState.selectedTab = .search
            case "library": appState.selectedTab = .library
            default: appState.selectedTab = .home
            }
        }

        let wantsPlayer = arguments.contains("-uiScreenshotPlayer")
        let wantsMiniPlayer = arguments.contains("-uiScreenshotMiniPlayer")
        let wantsSettings = arguments.contains("-uiScreenshotSettings")
        let wantsScroll = arguments.contains("-uiScreenshotScroll")
        let wantsKeyboard = arguments.contains("-uiScreenshotKeyboard")
        guard wantsPlayer
            || wantsMiniPlayer
            || wantsSettings
            || wantsScroll
            || wantsKeyboard
            || arguments.contains("-uiScreenshotTab")
            || arguments.contains("-uiScreenshotReadyFile") else {
            return
        }

        await waitForCatalog(timeout: (wantsPlayer || wantsMiniPlayer) ? 90 : 60)

        if wantsPlayer || wantsMiniPlayer, let track = appState.catalog.tracks.first {
            appState.play(track, in: Array(appState.catalog.tracks.prefix(20)))
            try? await Task.sleep(nanoseconds: 900_000_000)
            if wantsPlayer {
                appState.isPlayerPresented = true
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
        }

        if wantsSettings {
            appState.showSettings = true
            try? await Task.sleep(nanoseconds: 800_000_000)
        }

        if wantsScroll {
            appState.screenshotScrollToken += 1
            try? await Task.sleep(nanoseconds: 1_200_000_000)
        }

        if wantsKeyboard {
            try? await Task.sleep(nanoseconds: 700_000_000)
        }

        if let index = arguments.firstIndex(of: "-uiScreenshotReadyFile"),
           arguments.indices.contains(index + 1) {
            writeScreenshotMarker(named: arguments[index + 1])
        }
    }

    private func waitForCatalog(timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        var attempts = 0

        while Date() < deadline {
            if !appState.catalog.isEmpty, !appState.catalog.isLoading {
                return
            }
            if !appState.catalog.isLoading, !appState.isHomeLoading {
                guard attempts < 2 else { break }
                attempts += 1
                await appState.catalog.loadIfNeeded()
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    private func writeScreenshotMarker(named name: String) {
        let safeName = (name as NSString).lastPathComponent
        guard !safeName.isEmpty,
              let documents = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
              ).first else {
            return
        }
        let directory = documents.appendingPathComponent("VOLNA", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try? Data("ready".utf8).write(
            to: directory.appendingPathComponent(safeName),
            options: .atomic
        )
    }
    #endif
}

private struct BottomControlsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct VolnaTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var tabNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = tab == selection
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(Color.volnaAccentGradient.opacity(0.22))
                                    .frame(width: 58, height: 32)
                                    .matchedGeometryEffect(id: "tab-bg", in: tabNamespace)
                            }
                            Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                                .font(.system(size: 21, weight: isSelected ? .semibold : .regular))
                                .symbolRenderingMode(.hierarchical)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .frame(height: 32)

                        Text(tab.title)
                            .font(VolnaFont.custom(11, weight: isSelected ? .semibold : .medium, relativeTo: .caption2))
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
