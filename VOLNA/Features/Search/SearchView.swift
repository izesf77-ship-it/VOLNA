import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState

    @State private var query = ""
    @State private var filters = SearchFilters.default
    @FocusState private var isFocused: Bool
    @State private var showIssues = false

    private var service: SearchService { appState.searchService }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
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
                .padding(.horizontal, VolnaLayout.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .volnaScreenLayout()
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Artist.self) { ArtistView(artist: $0) }
            .navigationDestination(for: Album.self) { AlbumView(album: $0) }
            .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlistID: $0.id) }
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Поиск")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundStyle(Color.volnaTextPrimary)
                Text("Музыка из открытых источников")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(Color.volnaTextSecondary)
            }
            Spacer()
            NavigationLink { SourcesView() } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(VolnaIconButtonStyle())
            .accessibilityLabel("Источники")
        }
        .padding(.top, 4)
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isFocused ? Color.volnaPurple : Color.volnaTextTertiary)

            TextField("Песня, исполнитель или альбом", text: $query)
                .focused($isFocused)
                .font(.system(size: 16, weight: .regular, design: .default))
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
                        .font(.system(size: 18))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                .buttonStyle(.plain)
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
        .animation(.easeInOut(duration: 0.2), value: isFocused)
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
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Популярные запросы")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(SearchService.popularQueries, id: \.self) { item in
                        Button {
                            query = item
                            isFocused = false
                        } label: {
                            HStack {
                                Text(item)
                                    .font(.system(size: 14, weight: .medium, design: .default))
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

            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Русская музыка", subtitle: "Подборки на русском языке")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(SearchService.russianQueries, id: \.self) { item in
                            Button {
                                query = item
                                filters.language = "ru"
                                isFocused = false
                            } label: {
                                Text(item)
                                    .font(.system(size: 14, weight: .medium, design: .default))
                                    .foregroundStyle(Color.volnaTextPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.volnaPurple.opacity(0.15), in: Capsule())
                                    .overlay { Capsule().stroke(Color.volnaPurple.opacity(0.25), lineWidth: 1) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollClipDisabled()
            }

            howItWorksCard
        }
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.volnaPurple)
                Text("Как работает поиск")
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(Color.volnaTextPrimary)
            }
            Text("VOLNA ищет одновременно во всех включённых источниках и объединяет результаты. Лицензия и доступность указаны для каждого трека.")
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(Color.volnaTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Активно: \(appState.settings.enabledProviderIDs.count) из \(MusicSourceCatalog.all.count)")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(Color.volnaTextTertiary)
                Spacer()
                NavigationLink { SourcesView() } label: {
                    Text("Настроить")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(Color.volnaPurple)
                }
            }
        }
        .volnaCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Results

    private var resultsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center) {
                Text("Результаты")
                    .font(.system(size: 22, weight: .semibold, design: .default))
                    .foregroundStyle(Color.volnaTextPrimary)
                if service.isSearching {
                    ProgressView().tint(Color.volnaPurple).scaleEffect(0.8)
                }
                Spacer()
                if !service.tracks.isEmpty {
                    Text("\(service.tracks.count)")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundStyle(Color.volnaTextSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
            }

            if !service.stats.isEmpty { providerStats }
            if !service.issues.isEmpty { issuesSection }

            if !service.artists.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Исполнители")
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(service.artists) { ArtistCard(artist: $0) }
                        }
                    }
                    .scrollClipDisabled()
                }
            }

            if !service.albums.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Альбомы")
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 14) {
                            ForEach(service.albums) { AlbumCard(album: $0) }
                        }
                    }
                    .scrollClipDisabled()
                }
            }

            if !service.tracks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionHeader(title: "Треки")
                        Spacer()
                        if let first = service.tracks.first {
                            Button { appState.play(first, in: service.tracks) } label: {
                                Label("Играть", systemImage: "play.fill")
                                    .font(.system(size: 14, weight: .semibold, design: .default))
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
            } else if !service.isSearching {
                noResults
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
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundStyle(Color.volnaTextSecondary)
                        Text("\(stat.count)")
                            .font(.system(size: 12, weight: .semibold, design: .default))
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

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showIssues.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.volnaWarning)
                    Text("Недоступные источники: \(service.issues.count)")
                        .font(.system(size: 14, weight: .medium, design: .default))
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
            message: "Попробуйте другой запрос или измените фильтры. Некоторые каталоги лучше ищут по названию на латинице.",
            actionTitle: filters.language == "ru" ? "Искать на всех языках" : "Открыть источники",
            action: {
                if filters.language == "ru" { filters.language = nil }
                else { appState.selectedTab = .settings }
            }
        )
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProgressView().tint(Color.volnaPurple)
                Text("Ищем во всех источниках…")
                    .font(.system(size: 15, weight: .regular, design: .default))
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
