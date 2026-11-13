import SwiftUI

struct ArtistView: View {
    @Environment(AppState.self) private var appState

    let artist: Artist

    @State private var tracks: [Track] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView().tint(Color.volnaPurple)
                        Text("Ищем треки исполнителя…")
                            .font(.volnaBody(13))
                            .foregroundStyle(Color.volnaTextSecondary)
                    }
                    .padding(.vertical, 18)
                } else if let errorMessage {
                    ErrorBanner(message: errorMessage) {
                        Task { await load() }
                    }
                } else if tracks.isEmpty {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.questionmark",
                        title: "Треки не найдены",
                        message: "В открытых источниках не удалось найти композиции этого исполнителя. Попробуйте поискать вручную.",
                        actionTitle: "Открыть поиск"
                    ) {
                        appState.selectedTab = .search
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(tracks) { track in
                            TrackRow(track: track, queue: tracks)
                            if track.id != tracks.last?.id {
                                Divider()
                                    .overlay(Color.white.opacity(0.055))
                                    .padding(.leading, 62)
                            }
                        }
                    }
                    .volnaCard(cornerRadius: 20, padding: 8)
                }
            }
            .padding(.horizontal, VolnaLayout.horizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .volnaScreenLayout()
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task(id: artist.id) {
            await load()
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                if let url = artist.artworkURL {
                    ArtworkView(url: url, size: 124, cornerRadius: 62)
                } else {
                    Circle()
                        .fill(Color.volnaAccentGradient)
                        .frame(width: 124, height: 124)
                        .overlay {
                            Text(String(artist.name.prefix(1)).uppercased())
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                }
            }
            .shadow(color: Color.volnaPurple.opacity(0.30), radius: 26, y: 10)

            VStack(spacing: 6) {
                Text(artist.name)
                    .font(.volnaDisplay(27))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    ProviderBadge(providerID: artist.providerID, compact: false)
                    if !tracks.isEmpty {
                        Text("\(tracks.count) треков")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.volnaTextTertiary)
                    }
                }
            }

            if !tracks.isEmpty {
                HStack(spacing: 10) {
                    Button {
                        if let first = tracks.first {
                            appState.play(first, in: tracks)
                        }
                    } label: {
                        Label("Слушать", systemImage: "play.fill")
                    }
                    .buttonStyle(VolnaPrimaryButtonStyle())

                    Button {
                        if let first = tracks.first {
                            appState.play(first, in: tracks)
                            if !appState.player.isShuffled {
                                appState.player.toggleShuffle()
                            }
                        }
                    } label: {
                        Label("Вперемешку", systemImage: "shuffle")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.volnaTextPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil

        let artistName = artist.name
        let normalizedArtist = RussianText.normalizedKey(artistName)
        let localTracks = appState.catalog.tracks.filter { track in
            let name = RussianText.normalizedKey(track.artist)
            return name == normalizedArtist
                || name.contains(normalizedArtist)
                || normalizedArtist.contains(name)
        }

        let providers = appState.providerRegistry.searchableProviders.filter {
            appState.settings.isProviderEnabled($0.id)
        }
        guard !providers.isEmpty else {
            tracks = Array(localTracks.prefix(60))
            if tracks.isEmpty {
                errorMessage = "Все источники отключены. Включите хотя бы один в настройках."
            }
            isLoading = false
            return
        }

        let collected = await withTaskGroup(of: [Track].self, returning: [Track].self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        let result = try await provider.search(query: artistName, type: .track)
                        return result.tracks
                    } catch {
                        return []
                    }
                }
            }
            var all: [Track] = []
            for await result in group {
                all.append(contentsOf: result)
            }
            return all
        }

        let merged = SearchMerger.merge(tracks: localTracks + collected, query: artistName)
        let filtered = merged.filter { track in
            let name = RussianText.normalizedKey(track.artist)
            return name == normalizedArtist
                || name.contains(normalizedArtist)
                || normalizedArtist.contains(name)
        }

        tracks = Array(filtered.filter { !$0.playableStreams.isEmpty }.prefix(60))
        if tracks.isEmpty {
            errorMessage = "Открытые источники не вернули композиции этого исполнителя."
        }
        isLoading = false
    }
}
