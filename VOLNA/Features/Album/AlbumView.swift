import SwiftUI

struct AlbumView: View {
    @Environment(AppState.self) private var appState

    let album: Album

    @State private var tracks: [Track]
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(album: Album) {
        self.album = album
        _tracks = State(initialValue: album.tracks)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView().tint(Color.volnaPurple)
                        Text("Загружаем треки альбома…")
                            .font(.volnaBody(13))
                            .foregroundStyle(Color.volnaTextSecondary)
                    }
                    .padding(.vertical, 18)
                } else if let errorMessage {
                    ErrorBanner(message: errorMessage) {
                        Task { await loadTracks(force: true) }
                    }
                } else if tracks.isEmpty {
                    EmptyStateView(
                        icon: "square.stack",
                        title: "Треки недоступны",
                        message: "Этот источник не отдаёт список треков альбома через публичный API. Найдите композиции через поиск.",
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
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 148)
        }
        .background(VolnaBackground())
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await loadTracks(force: false)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            ArtworkView(url: album.artworkURL, size: 132, cornerRadius: 22)
                .shadow(color: Color.volnaPurple.opacity(0.26), radius: 22, y: 10)

            VStack(alignment: .leading, spacing: 6) {
                Text(album.title)
                    .font(.volnaDisplay(23))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(3)
                Text(album.artist)
                    .font(.volnaBody(14))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    ProviderBadge(providerID: album.providerID, compact: false)
                    if let year = album.releaseDate {
                        Text(Calendar.current.component(.year, from: year).description)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.volnaTextTertiary)
                    }
                    if !tracks.isEmpty {
                        Text("\(tracks.count) треков")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.volnaTextTertiary)
                    }
                }
                if let first = tracks.first {
                    Button {
                        appState.play(first, in: tracks)
                    } label: {
                        Label("Слушать альбом", systemImage: "play.fill")
                    }
                    .buttonStyle(VolnaPrimaryButtonStyle())
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func loadTracks(force: Bool) async {
        guard force || tracks.isEmpty else { return }
        guard let provider = appState.providerRegistry.provider(for: album.providerID) else {
            if tracks.isEmpty {
                errorMessage = "Источник альбома недоступен."
            }
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            if let fullAlbum = try await provider.fetchAlbum(id: album.id),
               !fullAlbum.tracks.isEmpty {
                tracks = fullAlbum.tracks
                isLoading = false
                return
            }
        } catch {
            // Источник может не поддерживать fetchAlbum. Пробуем поиск.
        }

        do {
            let result = try await provider.search(
                query: "\(album.artist) \(album.title)",
                type: .track
            )
            let normalizedAlbum = RussianText.normalizedKey(album.title)
            let matched = result.tracks.filter { track in
                guard let name = track.album else { return false }
                let normalized = RussianText.normalizedKey(name)
                return normalized == normalizedAlbum
                    || normalized.contains(normalizedAlbum)
                    || normalizedAlbum.contains(normalized)
            }
            if !matched.isEmpty {
                tracks = SearchMerger.merge(tracks: matched, query: album.title)
            } else if tracks.isEmpty {
                errorMessage = "Источник не вернул треки альбома. Попробуйте найти их через поиск."
            }
        } catch {
            if tracks.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}
