import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState

    @State private var query = ""
    @State private var filters = SearchFilters.default
    @State private var isFocused = false
    @State private var showIssues = false

    private var service: SearchService { appState.searchService }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 22) {
                    header
                    searchField
                    filterRow

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        discovery
                    } else if service.isSearching && service.tracks.isEmpty && service.albums.isEmpty && service.artists.isEmpty {
                        loadingState
                    } else {
                        resultsContent
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 148)
            }
            .background(VolnaBackground())
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Artist.self) { artist in
                ArtistView(artist: artist)
            }
            .navigationDestination(for: Album.self) { album in
                AlbumView(album: album)
            }
            .navigationDestination(for: Playlist.self) { playlist in
                PlaylistDetailView(playlistID: playlist.id)
            }
            .task(id: searchKey) {
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    service.reset()
                    return
                }
                try? await Task.sleep(nanoseconds: 380_000_000)
                guard !Task.isCancelled else { return }
                appState.performSearch(query: trimmed, filters: filters)
            }
        }
    }

    private var searchKey: String {
        let providers = appState.settings.enabledProviderIDs.sorted().joined(separator: ",")
        return "\(query)|\(filters.language ?? "-")|\(filters.genre ?? "-")|\(filters.onlyPlayable)|\(appState.settings.preferRussianMusic)|\(providers)"
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Поиск")
                    .font(.volnaDisplay(32))
                    .foregroundStyle(Color.volnaTextPrimary)
                Text("Один запрос — все открытые источники")
                    .font(.volnaBody(13))
                    .foregroundStyle(Color.volnaTextTertiary)
            }
            Spacer()
            NavigationLink {
                SourcesView()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(VolnaIconButtonStyle())
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isFocused ? Color.volnaPurple : Color.volnaTextTertiary)

            TextField("Песня, исполнитель или альбом", text: $query)
                .focused($isFocused)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.volnaTextPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    appState.performSearch(query: trimmed, filters: filters)
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    service.reset()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                .buttonStyle(.plain)
            } else if service.isSearching {
                ProgressView()
                    .tint(Color.volnaPurple)
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.volnaSurface.opacity(0.9))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(isFocused ? Color.volnaPurple.opacity(0.55) : Color.white.opacity(0.07), lineWidth: 1)
                }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                VolnaChip(
                    title: "Все языки",
                    icon: "globe",
                    isSelected: filters.language == nil
                ) {
                    filters.language = nil
                }
                VolnaChip(
                    title: "Русское",
                    icon: "character.book.closed",
                    isSelected: filters.language == "ru"
                ) {
                    filters.language = filters.language == "ru" ? nil : "ru"
                }
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1, height: 20)
                ForEach(GenreCatalog.all) { genre in
                    VolnaChip(
                        title: genre.title,
                        isSelected: filters.genre == genre.id
                    ) {
                        filters.genre = filters.genre == genre.id ? nil : genre.id
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    // MARK: - Discovery

    private var discovery: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Популярные запросы",
                    subtitle: "Реальные запросы к открытым каталогам"
                )
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 128), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(SearchService.popularQueries, id: \.self) { item in
                        Button {
                            query = item
                            isFocused = false
                        } label: {
                            HStack {
                                Text(item)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.volnaTextSecondary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.volnaTextTertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Русская музыка",
                    subtitle: "Приоритет русскоязычных записей: рок, рэп, инди, фолк и классика"
                )
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SearchService.russianQueries, id: \.self) { item in
                            Button {
                                query = item
                                filters.language = "ru"
                                isFocused = false
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(item)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(Color.volnaTextPrimary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 9)
                                .background {
                                    Capsule()
                                        .fill(Color.volnaPurple.opacity(0.16))
                                        .overlay {
                                            Capsule()
                                                .stroke(Color.volnaPurple.opacity(0.25), lineWidth: 1)
                                        }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            howItWorksCard
        }
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.volnaPurple)
                Text("Как работает поиск")
                    .font(.volnaHeadline(16))
                    .foregroundStyle(Color.volnaTextPrimary)
            }
            Text("Запрос уходит параллельно во все включённые источники. Результаты объединяются, дубликаты склеиваются, а несколько аудиопотоков одной записи сохраняются. Если один источник недоступен, остальные продолжают работать.")
                .font(.volnaBody(12))
                .foregroundStyle(Color.volnaTextSecondary)
                .lineSpacing(3)

            HStack(spacing: 8) {
                Text("Включено: \(appState.settings.enabledProviderIDs.count) из \(MusicSourceCatalog.all.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaTextTertiary)
                Spacer()
                NavigationLink {
                    SourcesView()
                } label: {
                    Text("Настроить")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.volnaPurple)
                }
            }
        }
        .volnaCard()
    }

    // MARK: - Results

    private var resultsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("Результаты")
                    .font(.volnaHeadline(20))
                    .foregroundStyle(Color.volnaTextPrimary)

                if service.isSearching {
                    ProgressView()
                        .tint(Color.volnaPurple)
                        .scaleEffect(0.7)
                }

                Spacer()

                if !service.tracks.isEmpty {
                    Text("\(service.tracks.count) треков")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
            }

            if !service.stats.isEmpty {
                providerStats
            }

            if !service.issues.isEmpty {
                issuesSection
            }

            if !service.artists.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Исполнители")
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 14) {
                            ForEach(service.artists) { artist in
                                ArtistCard(artist: artist)
                            }
                        }
                    }
                    .scrollClipDisabled()
                }
            }

            if !service.albums.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Альбомы")
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 14) {
                            ForEach(service.albums) { album in
                                AlbumCard(album: album)
                            }
                        }
                    }
                    .scrollClipDisabled()
                }
            }

            if !service.tracks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionHeader(title: "Треки")
                        Spacer()
                        if let first = service.tracks.first {
                            Button {
                                appState.play(first, in: service.tracks)
                            } label: {
                                Label("Играть", systemImage: "play.fill")
                            }
                            .buttonStyle(VolnaPrimaryButtonStyle())
                        }
                    }

                    VStack(spacing: 0) {
                        ForEach(service.tracks) { track in
                            TrackRow(track: track, queue: service.tracks)
                            if track.id != service.tracks.last?.id {
                                Divider()
                                    .overlay(Color.white.opacity(0.055))
                                    .padding(.leading, 62)
                            }
                        }
                    }
                    .volnaCard(cornerRadius: 20, padding: 8)
                }
            } else if !service.isSearching {
                noResults
            }

            if let completed = service.lastCompletedAt {
                Text("Поиск завершён в \(completed.formatted(date: .omitted, time: .shortened)). Источники и лицензии указаны рядом с каждой записью.")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.volnaTextTertiary)
            }
        }
    }

    private var providerStats: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(service.stats) { stat in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(color(for: stat.id))
                            .frame(width: 5, height: 5)
                        Text(stat.name)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.volnaTextSecondary)
                        Text("\(stat.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.volnaTextPrimary)
                        Text("\(stat.milliseconds) мс")
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.volnaTextTertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showIssues.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.volnaWarning)
                    Text("Недоступные источники: \(service.issues.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.volnaTextSecondary)
                    Spacer()
                    Image(systemName: showIssues ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
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
            message: "Попробуйте другой запрос, отключите фильтр «Русское» или включите дополнительные источники. Некоторые каталоги лучше ищут латиницей.",
            actionTitle: filters.language == "ru" ? "Искать на всех языках" : "Открыть источники",
            action: {
                if filters.language == "ru" {
                    filters.language = nil
                } else {
                    appState.selectedTab = .settings
                }
            }
        )
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ProgressView().tint(Color.volnaPurple)
                Text("Ищем во всех источниках…")
                    .font(.volnaBody(13))
                    .foregroundStyle(Color.volnaTextSecondary)
            }
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                            .frame(width: 190, height: 11)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .frame(width: 120, height: 9)
                    }
                }
            }
        }
        .padding(.top, 8)
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
