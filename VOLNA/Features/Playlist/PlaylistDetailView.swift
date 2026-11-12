import SwiftUI

struct PlaylistDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let playlistID: String

    @State private var showRename = false
    @State private var renameTitle = ""
    @State private var confirmDelete = false

    private var playlist: Playlist? {
        appState.library.playlist(id: playlistID)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let playlist {
                VStack(alignment: .leading, spacing: 20) {
                    header(playlist: playlist)

                    if playlist.tracks.isEmpty {
                        EmptyStateView(
                            icon: "music.note",
                            title: "Плейлист пуст",
                            message: "Добавляйте треки через контекстное меню в поиске или медиатеке.",
                            actionTitle: "Перейти к поиску"
                        ) {
                            dismiss()
                            appState.selectedTab = .search
                        }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(playlist.tracks) { track in
                                HStack(spacing: 0) {
                                    TrackRow(track: track, queue: playlist.tracks)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        appState.library.removeTrack(track.id, from: playlistID)
                                    } label: {
                                        Label("Убрать из плейлиста", systemImage: "minus.circle")
                                    }
                                }
                                if track.id != playlist.tracks.last?.id {
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
            } else {
                EmptyStateView(
                    icon: "questionmark.folder",
                    title: "Плейлист не найден",
                    message: "Возможно, он был удалён.",
                    actionTitle: "Назад"
                ) {
                    dismiss()
                }
                .padding(18)
            }
        }
        .volnaScreenLayout()
        .navigationTitle(playlist?.title ?? "Плейлист")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        renameTitle = playlist?.title ?? ""
                        showRename = true
                    } label: {
                        Label("Переименовать", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Удалить плейлист", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Переименовать плейлист", isPresented: $showRename) {
            TextField("Название", text: $renameTitle)
            Button("Сохранить") {
                appState.library.renamePlaylist(id: playlistID, title: renameTitle)
            }
            Button("Отмена", role: .cancel) {}
        }
        .confirmationDialog(
            "Удалить плейлист?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                appState.library.deletePlaylist(id: playlistID)
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Треки останутся в исходных источниках, но плейлист будет удалён с устройства.")
        }
    }

    private func header(playlist: Playlist) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 16) {
                ZStack {
                    if let url = playlist.artworkURL {
                        ArtworkView(url: url, size: 112, cornerRadius: 22)
                    } else {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.volnaAccentGradient)
                            .frame(width: 112, height: 112)
                            .overlay {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(playlist.title)
                        .font(.volnaDisplay(24))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .lineLimit(2)
                    Text("\(playlist.trackCount) треков")
                        .font(.volnaBody(12))
                        .foregroundStyle(Color.volnaTextSecondary)
                    if let duration = playlist.totalDurationFormatted {
                        Text(duration)
                            .font(.volnaBody(11))
                            .foregroundStyle(Color.volnaTextTertiary)
                    }
                }
                Spacer(minLength: 0)
            }

            if !playlist.tracks.isEmpty {
                HStack(spacing: 10) {
                    Button {
                        if let first = playlist.tracks.first {
                            appState.play(first, in: playlist.tracks)
                        }
                    } label: {
                        Label("Слушать", systemImage: "play.fill")
                    }
                    .buttonStyle(VolnaPrimaryButtonStyle())

                    Button {
                        if let first = playlist.tracks.first {
                            appState.play(first, in: playlist.tracks)
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
    }
}
