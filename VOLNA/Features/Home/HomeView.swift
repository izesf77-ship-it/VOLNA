import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showSettings = false

    private var historyTracks: [Track] { Array(appState.library.history.prefix(12)) }
    private var favoriteTracks: [Track] { Array(appState.library.favorites.prefix(12)) }
    private var recentPlaylists: [Playlist] { Array(appState.library.playlists.prefix(10)) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: VolnaLayout.sectionSpacing) {
                    header
                        .padding(.top, 4)

                    if let hero = appState.homeSections.first {
                        heroCard(section: hero)
                    }

                    if !historyTracks.isEmpty {
                        recentlyPlayedSection
                    }

                    if !recentPlaylists.isEmpty {
                        playlistsSection
                    }

                    if !favoriteTracks.isEmpty {
                        favoritesSection
                    }

                    if appState.isHomeLoading && appState.homeSections.isEmpty && historyTracks.isEmpty && favoriteTracks.isEmpty {
                        loadingState
                    } else if let error = appState.homeError, appState.homeSections.isEmpty && historyTracks.isEmpty {
                        ErrorBanner(message: error) {
                            Task { await appState.loadHome(force: true) }
                        }
                    }

                    ForEach(appState.homeSections.dropFirst()) { section in
                        discoveryShelf(section: section)
                    }

                    sourcesFooter
                }
                .padding(.horizontal, VolnaLayout.horizontalPadding)
                .padding(.bottom, 16)
            }
            .volnaScreenLayout()
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await appState.loadHome(force: true)
            }
            .navigationDestination(for: Artist.self) { ArtistView(artist: $0) }
            .navigationDestination(for: Album.self) { AlbumView(album: $0) }
            .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlistID: $0.id) }
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
            .task {
                await appState.loadHome()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("VOLNA")
                    .font(VolnaFont.custom(20, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .tracking(0.5)

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        appState.selectedTab = .search
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(VolnaIconButtonStyle(size: 40))
                    .accessibilityLabel("Поиск")

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(VolnaIconButtonStyle(size: 40))
                    .accessibilityLabel("Настройки")
                }
            }

            Text("Что послушать")
                .font(VolnaFont.custom(32, weight: .bold, relativeTo: .largeTitle))
                .foregroundStyle(Color.volnaTextPrimary)
                .lineLimit(2)
        }
    }

    // MARK: - Hero

    private func heroCard(section: HomeSection) -> some View {
        Button {
            guard let first = section.tracks.first else { return }
            appState.play(first, in: section.tracks)
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: section.colors.isEmpty ? [Color.volnaPurple, Color.volnaBlue] : section.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(.white.opacity(0.10))
                    .frame(width: 220, height: 220)
                    .blur(radius: 30)
                    .offset(x: 160, y: -40)

                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Подборка дня")
                            .font(VolnaFont.custom(12, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(.white.opacity(0.8))

                        Text(section.title)
                            .font(VolnaFont.custom(24, weight: .bold, relativeTo: .title2))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(section.subtitle)
                            .font(VolnaFont.custom(14, weight: .regular, relativeTo: .subheadline))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Слушать")
                                .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                        }
                        .foregroundStyle(Color(hex: "151515"))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(.white, in: Capsule())
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let artwork = section.tracks.first?.artworkURL {
                        ArtworkView(url: artwork, size: 116, cornerRadius: 18)
                            .shadow(color: .black.opacity(0.3), radius: 18, y: 10)
                            .rotationEffect(.degrees(4))
                    }
                }
                .padding(22)
            }
            .frame(minHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Library sections

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Недавно слушали", actionTitle: "Все") {
                appState.selectedTab = .library
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(historyTracks) { track in
                        TrackCard(track: track, queue: historyTracks, width: 156)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Твои плейлисты", actionTitle: "Все") {
                appState.selectedTab = .library
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(recentPlaylists) { playlist in
                        PlaylistCard(playlist: playlist, width: 156)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Избранные треки", actionTitle: "Все") {
                appState.selectedTab = .library
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(favoriteTracks) { track in
                        TrackCard(track: track, queue: favoriteTracks, width: 156)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Discovery shelves

    private func discoveryShelf(section: HomeSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: section.title, subtitle: section.subtitle)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(section.tracks) { track in
                        TrackCard(track: track, queue: section.tracks, width: 156)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 20) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.volnaSurface)
                .frame(height: 220)
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.volnaSurfaceSecondary).frame(width: 160, height: 18)
                    HStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 16).fill(Color.volnaSurfaceSecondary).frame(width: 140, height: 190)
                        }
                    }
                }
            }
        }
        .redacted(reason: .placeholder)
    }

    private var sourcesFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Открытая музыка")
                    .font(VolnaFont.custom(17, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(Color.volnaTextPrimary)
                Spacer()
                NavigationLink { SourcesView() } label: {
                    Text("Источники")
                        .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Color.volnaPurple)
                }
            }
            Text("VOLNA воспроизводит записи из открытых каталогов. Лицензия указывается для каждой композиции отдельно.")
                .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                .foregroundStyle(Color.volnaTextTertiary)
                .lineSpacing(3)
        }
        .volnaCard(cornerRadius: 20, padding: 16)
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
