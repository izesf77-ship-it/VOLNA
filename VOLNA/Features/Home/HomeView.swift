import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showSettings = false

    private var catalog: CatalogService { appState.catalog }
    private var historyTracks: [Track] { Array(appState.library.history.prefix(10)) }
    private var favoriteTracks: [Track] { Array(appState.library.favorites.prefix(10)) }
    private var recentPlaylists: [Playlist] { Array(appState.library.playlists.prefix(8)) }

    private var heroSection: CatalogSection? {
        catalog.sections.first(where: { $0.id == "russian" }) ?? catalog.sections.first
    }

    private var genreSections: [CatalogSection] {
        let order = ["rap", "rock", "pop", "electronic", "indie", "folk", "classical", "jazz"]
        return order.compactMap { id in catalog.sections.first(where: { $0.id == id }) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: VolnaLayout.sectionSpacing) {
                    header
                        .padding(.top, 6)

                    if let error = catalog.error, !catalog.isEmpty {
                        ErrorBanner(message: error) {
                            Task { await appState.refreshCatalog() }
                        }
                    }

                    if catalog.isLoading && catalog.isEmpty {
                        loadingState
                    } else if catalog.isEmpty {
                        emptyCatalogState
                        sourcesFooter
                    } else {
                        if let heroSection {
                            heroCard(section: heroSection)
                        }

                        if !catalog.recentAlbums.isEmpty {
                            newAlbumsSection
                        }

                        if let popular = section(id: "popular") {
                            chartSection(section: popular)
                        }

                        if let new = section(id: "new") {
                            trackShelf(section: new)
                        }

                        if !catalog.artists.isEmpty {
                            artistsSection
                        }

                        ForEach(genreSections) { section in
                            trackShelf(section: section)
                        }

                        if hasLibraryContent {
                            librarySection
                        }

                        sourcesFooter
                    }
                }
                .padding(.horizontal, VolnaLayout.horizontalPadding)
                .padding(.bottom, 20)
            }
            .volnaScreenLayout()
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await appState.refreshCatalog()
            }
            .navigationDestination(for: Artist.self) { ArtistView(artist: $0) }
            .navigationDestination(for: Album.self) { AlbumView(album: $0) }
            .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlistID: $0.id) }
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Text("VOLNA")
                    .font(VolnaFont.custom(20, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .tracking(2.6)

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

            VStack(alignment: .leading, spacing: 7) {
                Text("Сейчас в VOLNA")
                    .font(VolnaFont.custom(32, weight: .bold, relativeTo: .largeTitle))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(catalogSummary)
                    .font(VolnaFont.custom(14, weight: .regular, relativeTo: .subheadline))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var catalogSummary: String {
        if catalog.isEmpty {
            return "Открытые релизы с подтверждённой лицензией"
        }
        return "\(catalog.tracks.count) треков · \(catalog.russianTrackCount) на русском · \(catalog.albums.count) релизов"
    }

    // MARK: - Hero

    private func heroCard(section: CatalogSection) -> some View {
        let lead = section.tracks.first
        let queue = section.tracks

        return ZStack(alignment: .bottomLeading) {
            heroBackdrop(for: lead?.artworkURL)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.52),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ВЫБОР VOLNA")
                            .font(VolnaFont.custom(10, weight: .bold, relativeTo: .caption2))
                            .tracking(1.8)
                            .foregroundStyle(.white.opacity(0.72))

                        Text(section.title)
                            .font(VolnaFont.custom(29, weight: .bold, relativeTo: .title))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .minimumScaleFactor(0.82)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 4)

                    if let artwork = lead?.artworkURL {
                        ArtworkView(url: artwork, size: 112, cornerRadius: 18)
                            .shadow(color: .black.opacity(0.42), radius: 22, y: 12)
                            .rotationEffect(.degrees(3))
                            .accessibilityHidden(true)
                    }
                }

                Text(heroMetadata(for: section))
                    .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .padding(.top, 10)

                Text(section.subtitle)
                    .font(VolnaFont.custom(14, weight: .regular, relativeTo: .subheadline))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(2)
                    .padding(.top, 5)

                HStack(spacing: 10) {
                    Button {
                        guard let lead else { return }
                        appState.play(lead, in: queue)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Слушать")
                                .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                        }
                        .foregroundStyle(Color(hex: "101014"))
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Слушать подборку \(section.title)")

                    NavigationLink {
                        CatalogTracksView(
                            title: section.title,
                            subtitle: section.subtitle,
                            tracks: section.tracks
                        )
                    } label: {
                        Text("Вся подборка")
                            .font(VolnaFont.custom(13, weight: .semibold, relativeTo: .footnote))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 15)
                            .frame(minHeight: 42)
                            .background(.white.opacity(0.12), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(.white.opacity(0.18), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
            }
            .padding(20)
        }
        .frame(minHeight: 300, alignment: .bottom)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: Color.volnaPurple.opacity(0.18), radius: 28, y: 14)
    }

    @ViewBuilder
    private func heroBackdrop(for url: URL?) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "40308F"), Color(hex: "1B1635"), Color(hex: "0B0912")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.volnaMagenta.opacity(0.30))
                .frame(width: 260, height: 260)
                .blur(radius: 38)
                .offset(x: 130, y: -90)

            if let url {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 34)
                            .opacity(0.44)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .clipped()
    }

    private func heroMetadata(for section: CatalogSection) -> String {
        var names: [String] = []
        var seen = Set<String>()
        for track in section.tracks {
            let key = CatalogQuality.artistKey(track.artist)
            if seen.insert(key).inserted {
                names.append(track.artist)
            }
            if names.count == 3 { break }
        }
        return "\(section.tracks.count) треков · \(names.joined(separator: ", "))"
    }

    // MARK: - Albums

    private var newAlbumsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Новые релизы")
                        .font(VolnaFont.custom(22, weight: .semibold, relativeTo: .title2))
                        .foregroundStyle(Color.volnaTextPrimary)
                    Text("Свежие альбомы открытого каталога")
                        .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                Spacer(minLength: 8)
                NavigationLink {
                    CatalogAlbumsView(title: "Все альбомы")
                } label: {
                    Text("Все")
                        .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Color.volnaPurple)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(catalog.recentAlbums.prefix(10))) { album in
                        AlbumCard(album: album, width: 152)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Artists

    private var artistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Исполнители")
                        .font(VolnaFont.custom(22, weight: .semibold, relativeTo: .title2))
                        .foregroundStyle(Color.volnaTextPrimary)
                    Text("Реальные имена из открытых релизов")
                        .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                Spacer(minLength: 8)
                NavigationLink {
                    CatalogArtistsView(title: "Все исполнители")
                } label: {
                    Text("Все")
                        .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Color.volnaPurple)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 18) {
                    ForEach(Array(catalog.artists.prefix(14))) { artist in
                        ArtistCard(artist: artist, width: 92)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Track shelves

    private func trackShelf(section: CatalogSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(VolnaFont.custom(22, weight: .semibold, relativeTo: .title2))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .lineLimit(2)
                    Text(section.subtitle)
                        .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                        .foregroundStyle(Color.volnaTextTertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                NavigationLink {
                    CatalogTracksView(
                        title: section.title,
                        subtitle: section.subtitle,
                        tracks: section.tracks
                    )
                } label: {
                    Text("Все")
                        .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Color.volnaPurple)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(section.tracks.prefix(12))) { track in
                        TrackCard(track: track, queue: section.tracks, width: 150)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Chart

    private func chartSection(section: CatalogSection) -> some View {
        let chart = Array(section.tracks.prefix(6))
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Сейчас слушают")
                        .font(VolnaFont.custom(22, weight: .semibold, relativeTo: .title2))
                        .foregroundStyle(Color.volnaTextPrimary)
                    Text(section.subtitle)
                        .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                Spacer(minLength: 8)
                if let first = chart.first {
                    Button {
                        appState.play(first, in: chart)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.volnaAccentGradient, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Слушать чарт")
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(chart.enumerated()), id: \.element.id) { index, track in
                    HomeChartRow(index: index, track: track, queue: chart)
                    if index < chart.count - 1 {
                        Divider()
                            .overlay(Color.volnaSeparator)
                            .padding(.leading, 82)
                    }
                }
            }
            .padding(.vertical, 5)
            .volnaCard(cornerRadius: 20, padding: 8)
        }
    }

    // MARK: - Library

    private var hasLibraryContent: Bool {
        !historyTracks.isEmpty || !favoriteTracks.isEmpty || !recentPlaylists.isEmpty
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ваша музыка")
                        .font(VolnaFont.custom(22, weight: .semibold, relativeTo: .title2))
                        .foregroundStyle(Color.volnaTextPrimary)
                    Text("Хранится только на этом iPhone")
                        .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                Spacer(minLength: 8)
                Button {
                    appState.selectedTab = .library
                } label: {
                    Text("Медиатека")
                        .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Color.volnaPurple)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                NavigationLink {
                    FavoritesView()
                } label: {
                    HomeLibraryTile(
                        icon: "heart.fill",
                        value: "\(appState.library.favorites.count)",
                        title: "Избранное",
                        tint: .volnaMagenta
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HistoryView()
                } label: {
                    HomeLibraryTile(
                        icon: "clock.fill",
                        value: "\(appState.library.history.count)",
                        title: "История",
                        tint: .volnaBlue
                    )
                }
                .buttonStyle(.plain)

                Button {
                    appState.selectedTab = .library
                } label: {
                    HomeLibraryTile(
                        icon: "music.note.list",
                        value: "\(appState.library.playlists.count)",
                        title: "Плейлисты",
                        tint: .volnaPurple
                    )
                }
                .buttonStyle(.plain)
            }

            if !historyTracks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(historyTracks) { track in
                            TrackCard(track: track, queue: historyTracks, width: 150)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()
            } else if !recentPlaylists.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(recentPlaylists) { playlist in
                            PlaylistCard(playlist: playlist, width: 152)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()
            } else if !favoriteTracks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(favoriteTracks) { track in
                            TrackCard(track: track, queue: favoriteTracks, width: 150)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: VolnaLayout.sectionSpacing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.volnaSurface)
                .frame(height: 300)

            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.volnaSurfaceSecondary)
                        .frame(width: 180, height: 20)
                    HStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.volnaSurfaceSecondary)
                                .frame(width: 150, height: 186)
                        }
                    }
                }
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Загружаем каталог")
    }

    private var emptyCatalogState: some View {
        EmptyStateView(
            icon: "waveform.badge.exclamationmark",
            title: "Каталог пока пуст",
            message: "Не удалось получить открытые релизы. VOLNA не подставляет демо-треки: попробуйте обновить каталог при подключённом интернете.",
            actionTitle: "Обновить каталог"
        ) {
            Task { await appState.refreshCatalog() }
        }
    }

    private var sourcesFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.volnaMint)
                Text("Открытые лицензии")
                    .font(VolnaFont.custom(16, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(Color.volnaTextPrimary)
                Spacer()
                NavigationLink {
                    SourcesView()
                } label: {
                    Text("Источники")
                        .font(VolnaFont.custom(13, weight: .semibold, relativeTo: .footnote))
                        .foregroundStyle(Color.volnaPurple)
                }
            }

            Text("VOLNA воспроизводит музыку из открытых каталогов и не выдаёт чужие записи за свободные. Лицензия, источник и разрешение на поток указаны для каждого трека отдельно.")
                .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                .foregroundStyle(Color.volnaTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(catalog.countsText)
                    .font(VolnaFont.custom(11, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(Color.volnaTextTertiary)
                Spacer(minLength: 4)
                Text(lastUpdatedText)
                    .font(VolnaFont.custom(11, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(Color.volnaTextTertiary)
            }
        }
        .volnaCard(cornerRadius: 20, padding: 16)
    }

    private var lastUpdatedText: String {
        guard let date = catalog.lastUpdated else { return "Ещё не обновлялся" }
        return "Обновлено \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private func section(id: String) -> CatalogSection? {
        catalog.sections.first { $0.id == id }
    }
}

// MARK: - Home chart row

private struct HomeChartRow: View {
    @Environment(AppState.self) private var appState

    let index: Int
    let track: Track
    let queue: [Track]

    private var isCurrent: Bool {
        appState.player.currentTrack?.id == track.id
    }

    var body: some View {
        Button {
            appState.play(track, in: queue)
        } label: {
            HStack(spacing: 12) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isCurrent ? Color.volnaPurple : Color.volnaTextTertiary)
                    .frame(width: 22, alignment: .leading)

                ArtworkView(url: track.artworkURL, size: 46, cornerRadius: 9)

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(VolnaFont.custom(14, weight: isCurrent ? .semibold : .medium, relativeTo: .subheadline))
                        .foregroundStyle(isCurrent ? Color.volnaPurple : Color.volnaTextPrimary)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(VolnaFont.custom(12, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(Color.volnaTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                if let duration = track.durationFormatted {
                    Text(duration)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.volnaTextTertiary)
                }

                Image(systemName: isCurrent && appState.player.isPlaying ? "waveform" : "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isCurrent ? Color.volnaPurple : Color.volnaTextSecondary)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.06), in: Circle())
                    .symbolEffect(.variableColor.iterative, isActive: isCurrent && appState.player.isPlaying)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { appState.play(track, in: queue) } label: {
                Label("Слушать", systemImage: "play.fill")
            }
            Button { appState.player.playNext(track) } label: {
                Label("Следующим", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            Button { _ = appState.toggleFavorite(track) } label: {
                Label(
                    appState.library.isFavorite(track) ? "Убрать из избранного" : "В избранное",
                    systemImage: appState.library.isFavorite(track) ? "heart.slash" : "heart"
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(index + 1). \(track.title), \(track.artist)")
        .accessibilityHint("Запускает воспроизведение")
    }
}

// MARK: - Library tile

private struct HomeLibraryTile: View {
    let icon: String
    let value: String
    let title: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(VolnaFont.custom(21, weight: .bold, relativeTo: .title3))
                .foregroundStyle(Color.volnaTextPrimary)

            Text(title)
                .font(VolnaFont.custom(10, weight: .medium, relativeTo: .caption2))
                .foregroundStyle(Color.volnaTextTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.volnaSurface.opacity(0.86))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
        }
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
