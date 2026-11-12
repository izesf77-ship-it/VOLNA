import SwiftUI

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreatePlaylist = false
    @State private var newPlaylistTitle = ""

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    stats
                    playlistsSection
                    favoritesSection
                    historySection
                    localDataFooter
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 148)
            }
            .background(VolnaBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Playlist.self) { playlist in
                PlaylistDetailView(playlistID: playlist.id)
            }
            .alert("Новый плейлист", isPresented: $showCreatePlaylist) {
                TextField("Название", text: $newPlaylistTitle)
                Button("Создать") {
                    _ = appState.library.createPlaylist(title: newPlaylistTitle)
                    newPlaylistTitle = ""
                }
                Button("Отмена", role: .cancel) {
                    newPlaylistTitle = ""
                }
            } message: {
                Text("Плейлист сохранится только на этом iPhone.")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            ScreenHeader(
                title: "Медиатека",
                subtitle: "Избранное, плейлисты и история — только на этом устройстве",
                eyebrow: "Ваша коллекция"
            )
            Spacer()
            Button {
                newPlaylistTitle = ""
                showCreatePlaylist = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(VolnaIconButtonStyle())
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            NavigationLink {
                FavoritesView()
            } label: {
                LibraryStatCard(
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
                LibraryStatCard(
                    icon: "clock.fill",
                    value: "\(appState.library.history.count)",
                    title: "История",
                    tint: .volnaBlue
                )
            }
            .buttonStyle(.plain)

            LibraryStatCard(
                icon: "music.note.list",
                value: "\(appState.library.playlists.count)",
                title: "Плейлисты",
                tint: .volnaPurple
            )
        }
    }

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeader(
                title: "Плейлисты",
                subtitle: "Создавайте собственные подборки",
                actionTitle: "Создать"
            ) {
                newPlaylistTitle = ""
                showCreatePlaylist = true
            }

            if appState.library.playlists.isEmpty {
                EmptyStateView(
                    icon: "music.note.list",
                    title: "Плейлистов пока нет",
                    message: "Создайте первый плейлист и добавляйте в него треки из поиска.",
                    actionTitle: "Создать плейлист"
                ) {
                    newPlaylistTitle = ""
                    showCreatePlaylist = true
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(appState.library.playlists) { playlist in
                            PlaylistCard(playlist: playlist)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Избранное")
                Spacer()
                NavigationLink {
                    FavoritesView()
                } label: {
                    Text("Все")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.volnaPurple)
                }
            }

            if appState.library.favorites.isEmpty {
                Text("Отмечайте треки сердечком — они появятся здесь.")
                    .font(.volnaBody(12))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.library.favorites.prefix(4))) { track in
                        TrackRow(track: track, queue: appState.library.favorites)
                        if track.id != appState.library.favorites.prefix(4).last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.055))
                                .padding(.leading, 62)
                        }
                    }
                }
                .volnaCard(cornerRadius: 20, padding: 8)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Недавно слушали")
                Spacer()
                if !appState.library.history.isEmpty {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Text("Все")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.volnaPurple)
                    }
                }
            }

            if appState.library.history.isEmpty {
                Text("История появится после первого воспроизведения.")
                    .font(.volnaBody(12))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.library.history.prefix(5))) { track in
                        TrackRow(track: track, queue: appState.library.history)
                        if track.id != appState.library.history.prefix(5).last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.055))
                                .padding(.leading, 62)
                        }
                    }
                }
                .volnaCard(cornerRadius: 20, padding: 8)
            }
        }
    }

    private var localDataFooter: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.volnaMint)
            Text("Все данные медиатеки хранятся в JSON-файле на iPhone. Аккаунт, сервер и облачная база не используются.")
                .font(.volnaBody(11))
                .foregroundStyle(Color.volnaTextTertiary)
                .lineSpacing(2)
        }
        .padding(14)
        .background(Color.volnaMint.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct LibraryStatCard: View {
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
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(Color.volnaTextPrimary)
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.volnaTextTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.volnaSurface.opacity(0.85))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
        }
    }
}

#Preview {
    LibraryView()
        .environment(AppState())
}
