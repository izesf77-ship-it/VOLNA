import SwiftUI

struct LyricsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let track: Track

    @State private var lyrics: Lyrics?
    @State private var syncedLines: [LyricLine] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                VolnaBackground()

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(Color.volnaPurple)
                        Text("Ищем текст в LRCLIB…")
                            .font(.volnaBody(13))
                            .foregroundStyle(Color.volnaTextSecondary)
                    }
                } else if let errorMessage {
                    VStack(spacing: 16) {
                        EmptyStateView(
                            icon: "text.quote",
                            title: "Текст недоступен",
                            message: errorMessage,
                            actionTitle: "Повторить"
                        ) {
                            Task { await load() }
                        }
                    }
                    .padding(20)
                } else if let lyrics {
                    content(lyrics: lyrics)
                }
            }
            .navigationTitle("Текст песни")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
            }
            .task(id: track.id) {
                await load()
            }
        }
    }

    private func content(lyrics: Lyrics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.volnaHeadline(16))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.volnaBody(12))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            if lyrics.instrumental {
                centeredMessage(
                    icon: "music.note",
                    title: "Инструментальная композиция",
                    message: "LRCLIB отмечает этот трек как инструментальный."
                )
            } else if lyrics.hasSyncedLyrics, !syncedLines.isEmpty {
                syncedView
            } else if let plain = lyrics.plainLyrics, !plain.isEmpty {
                ScrollView(showsIndicators: false) {
                    Text(plain)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.volnaTextPrimary.opacity(0.88))
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                }
            } else {
                centeredMessage(
                    icon: "text.quote",
                    title: "Текст не найден",
                    message: "В LRCLIB нет текста для этой записи. Попробуйте другой источник или добавьте текст позже."
                )
            }

            HStack(spacing: 5) {
                Image(systemName: "text.quote")
                Text("Текст: LRCLIB · точность зависит от исходной записи")
            }
            .font(.system(size: 9, weight: .regular, design: .rounded))
            .foregroundStyle(Color.volnaTextTertiary)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    private var syncedView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(syncedLines.indices, id: \.self) { index in
                        Text(syncedLines[index].text.isEmpty ? " " : syncedLines[index].text)
                            .font(.system(size: 20, weight: index == currentLineIndex ? .bold : .medium, design: .rounded))
                            .foregroundStyle(
                                index == currentLineIndex
                                    ? Color.volnaTextPrimary
                                    : Color.volnaTextPrimary.opacity(0.38)
                            )
                            .scaleEffect(index == currentLineIndex ? 1.02 : 1, anchor: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                            .animation(.easeInOut(duration: 0.25), value: currentLineIndex)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 26)
            }
            .onChange(of: currentLineIndex) { _, index in
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
            .onAppear {
                if let index = currentLineIndex {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }

    private func centeredMessage(icon: String, title: String, message: String) -> some View {
        EmptyStateView(icon: icon, title: title, message: message)
            .padding(.horizontal, 20)
            .padding(.top, 16)
    }

    private var currentLineIndex: Int? {
        guard !syncedLines.isEmpty else { return nil }
        let time = appState.player.currentTime
        var result: Int?
        for (index, line) in syncedLines.enumerated() {
            if line.timestamp <= time + 0.15 {
                result = index
            } else {
                break
            }
        }
        return result
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        lyrics = nil
        syncedLines = []

        do {
            let result = try await appState.lyricsService.searchLyrics(
                trackName: track.title,
                artistName: track.artist,
                albumName: track.album,
                duration: track.duration
            )
            if let result {
                lyrics = result
                syncedLines = result.parsedLines
            } else {
                errorMessage = "LRCLIB не нашёл текст для этой композиции. Это не ошибка приложения."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
