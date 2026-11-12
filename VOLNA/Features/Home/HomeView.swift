import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 26) {
                    header

                    if appState.isHomeLoading && appState.homeSections.isEmpty {
                        loadingState
                    } else if let error = appState.homeError, appState.homeSections.isEmpty {
                        ErrorBanner(message: error) {
                            Task { await appState.loadHome(force: true) }
                        }
                    } else {
                        if let hero = appState.homeSections.first {
                            heroCard(section: hero)
                        }

                        ForEach(appState.homeSections) { section in
                            shelf(section: section)
                        }
                    }

                    sourcesFooter
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 148)
            }
            .background(VolnaBackground())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await appState.loadHome(force: true)
            }
            .navigationDestination(for: Artist.self) { artist in
                ArtistView(artist: artist)
            }
            .navigationDestination(for: Album.self) { album in
                AlbumView(album: album)
            }
            .navigationDestination(for: Playlist.self) { playlist in
                PlaylistDetailView(playlistID: playlist.id)
            }
            .task {
                await appState.loadHome()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.volnaBody(14))
                        .foregroundStyle(Color.volnaTextTertiary)
                    HStack(spacing: 8) {
                        Text("VOLNA")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color(hex: "C7B9FF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Circle()
                            .fill(Color.volnaPurple)
                            .frame(width: 7, height: 7)
                    }
                }
                Spacer()
                Button {
                    appState.selectedTab = .search
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(VolnaIconButtonStyle())
            }

            Text("Музыка из открытых источников.\nБез рекламы и подписок.")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.volnaTextPrimary)
                .lineSpacing(3)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Доброе утро"
        case 12..<18: return "Добрый день"
        case 18..<23: return "Добрый вечер"
        default: return "Доброй ночи"
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
                            colors: section.colors.map { $0.opacity(0.92) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(.white.opacity(0.14))
                    .frame(width: 180, height: 180)
                    .blur(radius: 10)
                    .offset(x: 210, y: -80)

                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ВОЛНА · ВЫБОР VOLNA")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(section.title)
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(section.subtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            Label("Слушать", systemImage: "play.fill")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.white)
                                .foregroundStyle(Color(hex: "1A1030"))
                                .clipShape(Capsule())
                            Text("\(section.tracks.count) треков")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        .padding(.top, 2)
                    }

                    Spacer(minLength: 0)

                    if let artwork = section.tracks.first?.artworkURL {
                        ArtworkView(url: artwork, size: 104, cornerRadius: 22)
                            .rotationEffect(.degrees(4))
                            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
                    }
                }
                .padding(20)
            }
            .frame(height: 202)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: section.colors.first?.opacity(0.30) ?? .clear, radius: 28, y: 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shelves

    private func shelf(section: HomeSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: section.title,
                subtitle: section.subtitle,
                actionTitle: "Играть"
            ) {
                guard let first = section.tracks.first else { return }
                appState.play(first, in: section.tracks)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(section.tracks) { track in
                        TrackCard(track: track, queue: section.tracks)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(Color.volnaPurple)
                Text("Собираем музыку из открытых источников…")
                    .font(.volnaBody(13))
                    .foregroundStyle(Color.volnaTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .frame(height: index == 0 ? 190 : 110)
            }
        }
    }

    private var sourcesFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Открытая музыка")
                    .font(.volnaHeadline(16))
                    .foregroundStyle(Color.volnaTextPrimary)
                Spacer()
                NavigationLink {
                    SourcesView()
                } label: {
                    Text("Источники")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.volnaPurple)
                }
            }
            Text("VOLNA не хранит музыкальные файлы. Записи воспроизводятся напрямую из Jamendo, Internet Archive, Wikimedia Commons и других открытых каталогов. Лицензия указывается для каждой композиции отдельно.")
                .font(.volnaBody(12))
                .foregroundStyle(Color.volnaTextTertiary)
                .lineSpacing(3)

            HStack(spacing: 10) {
                ForEach(["jamendo", "internet_archive", "wikimedia_commons"], id: \.self) { id in
                    ProviderBadge(providerID: id, compact: false)
                }
            }
        }
        .volnaCard()
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
