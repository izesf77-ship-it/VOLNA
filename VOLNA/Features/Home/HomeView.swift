import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: VolnaLayout.sectionSpacing) {
                    header
                        .padding(.top, 8)

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

                        ForEach(appState.homeSections.dropFirst()) { section in
                            shelf(section: section)
                        }
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .foregroundStyle(Color.volnaTextSecondary)
                    Text("VOLNA")
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundStyle(Color.volnaTextPrimary)
                }
                Spacer()
                Button {
                    appState.selectedTab = .search
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(VolnaIconButtonStyle())
                .accessibilityLabel("Поиск")
            }

            Text("Музыка из открытых источников")
                .font(.system(size: 17, weight: .regular, design: .default))
                .foregroundStyle(Color.volnaTextSecondary)
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
                // Background gradient
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: section.colors.isEmpty ? [Color.volnaPurple, Color.volnaBlue] : section.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Decorative circles
                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                    .offset(x: 180, y: -60)

                Circle()
                    .fill(.black.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                    .offset(x: -20, y: 80)

                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ПОДБОРКА")
                            .font(.system(size: 11, weight: .bold, design: .default))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.75))

                        Text(section.title)
                            .font(.system(size: 26, weight: .bold, design: .default))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(section.subtitle)
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)

                        HStack(spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Слушать")
                                    .font(.system(size: 14, weight: .semibold, design: .default))
                            }
                            .foregroundStyle(Color(hex: "1A1030"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.white, in: Capsule())

                            Text("\(section.tracks.count) треков")
                                .font(.system(size: 13, weight: .medium, design: .default))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let artwork = section.tracks.first?.artworkURL {
                        ArtworkView(url: artwork, size: 110, cornerRadius: 16)
                            .rotationEffect(.degrees(6))
                            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                    }
                }
                .padding(20)
            }
            .frame(minHeight: 210)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            }
            .shadow(color: (section.colors.first ?? .volnaPurple).opacity(0.35), radius: 24, y: 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shelves

    private func shelf(section: HomeSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: section.title,
                subtitle: section.subtitle,
                actionTitle: section.tracks.isEmpty ? nil : "Играть"
            ) {
                guard let first = section.tracks.first else { return }
                appState.play(first, in: section.tracks)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(section.tracks) { track in
                        TrackCard(track: track, queue: section.tracks, width: 160)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 1)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(Color.volnaPurple)
                Text("Загружаем подборки…")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(Color.volnaTextSecondary)
            }
            .padding(.vertical, 8)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.volnaSurface)
                .frame(height: 210)

            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.volnaSurfaceSecondary)
                        .frame(width: 180, height: 20)
                    HStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.volnaSurfaceSecondary)
                                .frame(width: 140, height: 180)
                        }
                    }
                }
            }
        }
        .redacted(reason: .placeholder)
    }

    private var sourcesFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Открытая музыка")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundStyle(Color.volnaTextPrimary)
                Spacer()
                NavigationLink {
                    SourcesView()
                } label: {
                    Text("Источники")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(Color.volnaPurple)
                }
            }

            Text("VOLNA воспроизводит записи из открытых каталогов. Лицензия указывается для каждой композиции отдельно.")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundStyle(Color.volnaTextTertiary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(["jamendo", "internet_archive", "wikimedia_commons"], id: \.self) { id in
                    ProviderBadge(providerID: id, compact: false)
                }
            }
        }
        .volnaCard(cornerRadius: 20, padding: 16)
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
