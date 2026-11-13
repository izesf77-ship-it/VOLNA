import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var query = ""
    @State private var filters = SearchFilters.default
    @FocusState private var isFocused: Bool
    @State private var showIssues = false
    @State private var showSettings = false

    private var service: SearchService { appState.searchService }
    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var queryTokens: [String] {
        CatalogQuality.normalized(trimmedQuery)
            .split(separator: " ")
            .map(String.init)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    searchField
                    filterRow

                    if trimmedQuery.isEmpty {
                        discovery
                    } else if service.isSearching && !hasAnyResult {
                        loadingState
                    } else {
                        resultsContent
                    }
                }
                .padding(.horizontal, VolnaLayout.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .volnaScreenLayout()
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Artist.self) { ArtistView(artist: $0) }
            .navigationDestination(for: Album.self) { AlbumView(album: $0) }
            .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlistID: $0.id) }
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
            .task {
                await appState.catalog.loadIfNeeded()
            }
            .task(id: searchKey) {
                guard !trimmedQuery.isEmpty else {
                    service.reset()
                    return
                }
                try? await Task.sleep(nanoseconds: 380_000_000)
                guard !Task.isCancelled else { return }
                appState.performSearch(query: trimmedQuery, filters: filters)
            }
        }
    }

    private var searchKey: String {
        let providers = appState.settings.enabledProviderIDs.sorted().joined(separator: ",")
        return "\(query)|\(filters.language ?? "-")|\(filters.genre ?? "-")|\(filters.onlyPlayable)|\(appState.settings.preferRussianMusic)|\(providers)"
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Поиск")
                    .font(VolnaFont.custom(32, weight: .bold, relativeTo: .largeTitle))
                    .foregroundStyle(Color.volnaTextPrimary)
                Text("По трекам, исполнителям, альбомам и плейлистам")
                    .font(VolnaFont.custom(14, weight: .regular, relativeTo: .subheadline))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(VolnaIconButtonStyle(size: 40))
            .accessibilityLabel("Настройки")
        }
        .padding(.top, 4)
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isFocused ? Color.volnaPurple : Color.volnaTextTertiary)

            TextField("Песня, исполнитель, альбом или плейлист", text: $query)
                .focused($isFocused)
                .font(VolnaFont.custom(16, weight: .regular, relativeTo: .body))
                .foregroundStyle(Color.volnaTextPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    recordCurrentQuery()
                    guard !trimmedQuery.isEmpty else { return }
                    appState.performSearch(query: trimmedQuery, filters: filters)
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    service.reset()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистить запрос")
            } else if service.isSearching {
                ProgressView()
                    .tint(Color.volnaPurple)
                    .scaleEffect(0.85)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.volnaSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isFocused ? Color.volnaPurple.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
                }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isFocused)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                VolnaChip(title: "Все", icon: "globe", isSelected: filters.language == nil) {
                    filters.language = nil
                }
                VolnaChip(title: "Русское", icon: "music.note", isSelected: filters.language == "ru") {
                    filters.language = filters.language == "ru" ? nil : "ru"
                }

                if !GenreCatalog.all.isEmpty {
                    Divider()
                        .frame(height: 20)
                        .overlay(Color.white.opacity(0.1))
                        .padding(.horizontal, 4)

                    ForEach(GenreCatalog.all) { genre in
                        VolnaChip(title: genre.title, isSelected: filters.genre == genre.id) {
                            filters.genre = filters.genre == genre.id ? nil : genre.id
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    // MARK: - Discovery

    private var discovery: some View {
        VStack(alignment: .leading, spacing: VolnaLayout.sectionSpacing) {
            if !appState.searchHistory.queries.isEmpty {
                historySection
            }

            popularQueriesSection

            if !appState.catalog.recentAlbums.isEmpty {
                catalogAlbumsDiscovery
            }

            if !appState.catalog.russianTracks.isEmpty {
                catalogTracksDiscovery
            }

            howItWorksCard
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Недавние запросы",
                subtitle: "Сохраняются только на этом iPhone",
                actionTitle: "Очистить"
            ) {
                appState.searchHistory.clear()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(appState.searchHistory.queries, id: \.self) { item in
                        HStack(spacing: 4) {
                            Button {
                                applySuggestion(item)
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(item)
                                        .font(VolnaFont.custom(13, weight: .medium, relativeTo: .footnote))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(Color.volnaTextPrimary)
                                .padding(.leading, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            Button {
                                appState.searchHistory.remove(item)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.volnaTextTertiary)
                                    .frame(width: 30, height: 38)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Удалить запрос \(item)")
                        }
                        .padding(.trailing, 2)
                        .background(Color.volnaSurface, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var popularQueriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Популярные запросы", subtitle: "Что ищут в открытой музыке")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                ForEach(SearchService.popularQueries, id: \.self) { item in
                    Button {
                        applySuggestion(item)
                    } label: {
                        HStack {
                            Text(item)
                                .font(VolnaFont.custom(14, weight: .medium, relativeTo: .subheadline))
                                .foregroundStyle(Color.volnaTextPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.volnaTextTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.volnaSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var catalogAlbumsDiscovery: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Новые релизы")
                        .font(VolnaFont.custom(22, weight: .semibold, relativeTo: .title2))
                        .foregroundStyle(Color.volnaTextPrimary)
                    Text("Реальные альбомы из открытого каталога")
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
                    ForEach(Array(appState.catalog.recentAlbums.prefix(10))) { album in
                        AlbumCard(album: album, width: 150)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var catalogTracksDiscovery: some View {
        let tracks = Array(appState.catalog.russianTracks.prefix(12))
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Русская волна")
                        .font(VolnaFont.custom(22, weight: .semibold, relativeTo: .title2))
                        .foregroundStyle(Color.volnaTextPrimary)
                    Text("Открытые релизы на русском языке")
                        .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                Spacer(minLength: 8)
                NavigationLink {
                    CatalogTracksView(
                        title: "Русская волна",
                        subtitle: "Открытые релизы на русском языке",
                        tracks: appState.catalog.russianTracks
                    )
                } label: {
                    Text("Все")
                        .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Color.volnaPurple)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(tracks) { track in
                        TrackCard(track: track, queue: tracks, width: 150)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.volnaPurple)
                Text("Как работает поиск")
                    .font(VolnaFont.custom(17, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(Color.volnaTextPrimary)
            }
            Text("VOLNA ищет в открытом каталоге и во всех включённых источниках параллельно. Сначала показываются проверенные релизы с обложкой и лицензией, затем остальные результаты. Несуществующие треки не добавляются.")
                .font(VolnaFont.custom(14, weight: .regular, relativeTo: .subheadline))
                .foregroundStyle(Color.volnaTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Активно: \(appState.settings.enabledProviderIDs.count) из \(MusicSourceCatalog.all.count)")
                    .font(VolnaFont.custom(13, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(Color.volnaTextTertiary)
                Spacer()
                NavigationLink {
                    SourcesView()
                } label: {
                    Text("Настроить")
                        .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Color.volnaPurple)
                }
            }
        }
        .volnaCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Results

    private var resultsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            resultsHeader

            if !service.stats.isEmpty { providerStats }
            if !service.issues.isEmpty { issuesSection }

            if !catalogTracks.isEmpty {
                localTracksSection
            }

            if !playlistMatches.isEmpty {
                playlistMatchesSection
            }

            if !catalogAlbums.isEmpty {
                localAlbumsSection
            }

            if !catalogArtists.isEmpty {
                localArtistsSection
            }

            if !service.artists.isEmpty {
                providerArtistsSection
            }

            if !service.albums.isEmpty {
                providerAlbumsSection
            }

            if !service.tracks.isEmpty {
                providerTracksSection
            }

            if !hasAnyResult && !service.isSearching {
                noResults
            }
        }
    }

    private var resultsHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Результаты")
                    .font(VolnaFont.custom(22, weight: .semibold, relativeTo: .title2))
                    .foregroundStyle(Color.volnaTextPrimary)
                if hasAnyResult {
                    Text("Найдено: \(resultCount)")
                        .font(VolnaFont.custom(12, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
            }
            if service.isSearching {
                ProgressView()
                    .tint(Color.volnaPurple)
                    .scaleEffect(0.8)
                    .padding(.leading, 4)
            }
            Spacer()
            if let completed = service.lastCompletedAt, !service.isSearching {
                Text(completed.formatted(date: .omitted, time: .shortened))
                    .font(VolnaFont.custom(11, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(Color.volnaTextTertiary)
            }
        }
    }

    private var providerStats: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(service.stats) { stat in
                    HStack(spacing: 6) {
                        Circle().fill(color(for: stat.id)).frame(width: 6, height: 6)
                        Text(stat.name)
                            .font(VolnaFont.custom(12, weight: .medium, relativeTo: .caption))
                            .foregroundStyle(Color.volnaTextSecondary)
                        Text("\(stat.count)")
                            .font(VolnaFont.custom(12, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(Color.volnaTextPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.volnaSurface, in: Capsule())
                }
            }
        }
        .scrollClipDisabled()
    }

    private var localTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("В каталоге VOLNA")
                        .font(VolnaFont.custom(20, weight: .semibold, relativeTo: .title3))
                        .foregroundStyle(Color.volnaTextPrimary)
                    Text("Проверенные открытые релизы")
                        .font(VolnaFont.custom(12, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                Spacer()
                Button {
                    guard let first = catalogTracks.first else { return }
                    appState.play(first, in: catalogTracks)
                } label: {
                    Label("Играть", systemImage: "play.fill")
                }
                .buttonStyle(VolnaPrimaryButtonStyle())
            }

            VStack(spacing: 0) {
                ForEach(Array(catalogTracks.enumerated()), id: \.element.id) { index, track in
                    TrackRow(track: track, queue: catalogTracks)
                    if index < catalogTracks.count - 1 {
                        Divider()
                            .overlay(Color.volnaSeparator)
                            .padding(.leading, 68)
                    }
                }
            }
            .padding(.vertical, 4)
            .volnaCard(cornerRadius: 20, padding: 8)
        }
    }

    private var playlistMatchesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Ваши плейлисты", subtitle: "Совпадения в медиатеке")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(playlistMatches) { playlist in
                        PlaylistCard(playlist: playlist, width: 142)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var localAlbumsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Альбомы в каталоге", subtitle: "Совпадения по названию или исполнителю")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(catalogAlbums) { album in
                        AlbumCard(album: album, width: 142)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var localArtistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Исполнители в каталоге", subtitle: "Реальные имена из открытых релизов")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(catalogArtists) { artist in
                        ArtistCard(artist: artist, width: 84)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var providerArtistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Исполнители в источниках")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(service.artists) { ArtistCard(artist: $0, width: 84) }
                }
            }
            .scrollClipDisabled()
        }
    }

    private var providerAlbumsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Альбомы в источниках")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(service.albums) { AlbumCard(album: $0, width: 142) }
                }
            }
            .scrollClipDisabled()
        }
    }

    private var providerTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Треки из источников")
                Spacer()
                if let first = service.tracks.first {
                    Button { appState.play(first, in: service.tracks) } label: {
                        Label("Играть", systemImage: "play.fill")
                    }
                    .buttonStyle(VolnaPrimaryButtonStyle())
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(service.tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRow(track: track, queue: service.tracks)
                    if index < service.tracks.count - 1 {
                        Divider()
                            .overlay(Color.volnaSeparator)
                            .padding(.leading, 68)
                    }
                }
            }
            .padding(.vertical, 4)
            .volnaCard(cornerRadius: 20, padding: 8)
        }
    }

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showIssues.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.volnaWarning)
                    Text("Недоступные источники: \(service.issues.count)")
                        .font(VolnaFont.custom(14, weight: .medium, relativeTo: .subheadline))
                        .foregroundStyle(Color.volnaTextSecondary)
                    Spacer()
                    Image(systemName: showIssues ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showIssues {
                ForEach(service.issues) { issue in
                    ErrorBanner(message: "\(issue.providerName): \(issue.message)")
                }
            }
        }
    }

    private var noResults: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "Ничего не найдено",
            message: "Попробуйте другой запрос или измените фильтры. VOLNA не добавляет несуществующие треки, чтобы заполнить выдачу.",
            actionTitle: filters.language == "ru" ? "Искать на всех языках" : "Открыть источники",
            action: {
                if filters.language == "ru" { filters.language = nil }
                else { showSettings = true }
            }
        )
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProgressView().tint(Color.volnaPurple)
                Text("Ищем в открытом каталоге и источниках…")
                    .font(VolnaFont.custom(15, weight: .regular, relativeTo: .body))
                    .foregroundStyle(Color.volnaTextSecondary)
            }
            .padding(.vertical, 8)

            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.volnaSurfaceSecondary)
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.volnaSurfaceSecondary).frame(height: 12)
                        RoundedRectangle(cornerRadius: 4).fill(Color.volnaSurfaceSecondary).frame(width: 140, height: 10)
                    }
                }
            }
        }
        .redacted(reason: .placeholder)
    }

    // MARK: - Local matching

    private var catalogTracks: [Track] {
        guard trimmedQuery.count >= 2, !queryTokens.isEmpty else { return [] }
        var items = appState.catalog.searchLocal(trimmedQuery, limit: 40)

        if filters.language == "ru" {
            items = items.filter(\.isRussian)
        }
        if let genreID = filters.genre, let option = GenreCatalog.option(for: genreID) {
            items = items.filter { track in
                let haystack = "\(track.genre ?? "") \(track.title) \(track.artist) \(track.album ?? "")"
                    .lowercased()
                return option.keywords.contains { haystack.contains($0.lowercased()) }
            }
        }

        let providerKeys = Set(service.tracks.map { CatalogQuality.dedupKey(for: $0) })
        return items
            .filter { !providerKeys.contains(CatalogQuality.dedupKey(for: $0)) }
            .prefix(8)
            .map { $0 }
    }

    private var catalogAlbums: [Album] {
        guard trimmedQuery.count >= 2, !queryTokens.isEmpty else { return [] }
        return appState.catalog.albums
            .filter { matches("\($0.title) \($0.artist)") }
            .prefix(8)
            .map { $0 }
    }

    private var catalogArtists: [Artist] {
        guard trimmedQuery.count >= 2, !queryTokens.isEmpty else { return [] }
        return appState.catalog.artists
            .filter { matches($0.name) }
            .prefix(8)
            .map { $0 }
    }

    private var playlistMatches: [Playlist] {
        guard trimmedQuery.count >= 2, !queryTokens.isEmpty else { return [] }
        return appState.library.playlists
            .filter { matches($0.title) }
            .prefix(6)
            .map { $0 }
    }

    private func matches(_ value: String) -> Bool {
        let haystack = CatalogQuality.normalized(value)
        guard !haystack.isEmpty else { return false }
        return queryTokens.allSatisfy { haystack.contains($0) }
    }

    private var hasAnyResult: Bool {
        service.hasResults
            || !catalogTracks.isEmpty
            || !catalogAlbums.isEmpty
            || !catalogArtists.isEmpty
            || !playlistMatches.isEmpty
    }

    private var resultCount: Int {
        service.tracks.count
            + service.albums.count
            + service.artists.count
            + catalogTracks.count
            + catalogAlbums.count
            + catalogArtists.count
            + playlistMatches.count
    }

    private func applySuggestion(_ value: String) {
        query = value
        appState.searchHistory.record(value)
        isFocused = false
    }

    private func recordCurrentQuery() {
        guard trimmedQuery.count >= 2 else { return }
        appState.searchHistory.record(trimmedQuery)
    }

    private func color(for providerID: String) -> Color {
        switch providerID {
        case "jamendo": return .volnaMint
        case "internet_archive": return .volnaBlue
        case "wikimedia_commons": return .volnaAmber
        case "openverse": return .volnaMagenta
        case "direct": return .volnaCyan
        default: return .volnaTextTertiary
        }
    }
}

#Preview {
    SearchView()
        .environment(AppState())
}
