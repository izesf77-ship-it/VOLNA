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
                VolnaBackground().ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 14) {
                        ProgressView().tint(Color.volnaPurple)
                        Text("Ищем текст песни…")
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundStyle(Color.volnaTextSecondary)
                    }
                } else if let errorMessage {
                    VStack {
                        Spacer()
                        EmptyStateView(
                            icon: "quote.bubble",
                            title: "Текст недоступен",
                            message: errorMessage,
                            actionTitle: "Повторить"
                        ) { Task { await load() } }
                        .padding(.horizontal, 24)
                        Spacer()
                    }
                } else if let lyrics {
                    content(lyrics: lyrics)
                }
            }
            .navigationTitle("Текст")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.volnaBackground.opacity(0.96), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .font(.system(size: 15, weight: .medium, design: .default))
                }
            }
            .task(id: track.id) { await load() }
        }
    }

    private func content(lyrics: Lyrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if lyrics.instrumental {
                Spacer()
                EmptyStateView(
                    icon: "music.note",
                    title: "Инструментал",
                    message: "Эта композиция отмечена как инструментальная."
                )
                .padding(.horizontal, 24)
                Spacer()
            } else if lyrics.hasSyncedLyrics, !syncedLines.isEmpty {
                syncedView
            } else if let plain = lyrics.plainLyrics, !plain.isEmpty {
                ScrollView(showsIndicators: false) {
                    Text(plain)
                        .font(.system(size: 20, weight: .medium, design: .default))
                        .foregroundStyle(Color.volnaTextPrimary.opacity(0.9))
                        .lineSpacing(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                        .padding(.bottom, 20)
                }
            } else {
                Spacer()
                EmptyStateView(
                    icon: "quote.bubble",
                    title: "Текст не найден",
                    message: "Для этой записи нет текста в LRCLIB."
                )
                .padding(.horizontal, 24)
                Spacer()
            }
        }
    }

    private var syncedView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(syncedLines.indices, id: \.self) { index in
                        let isActive = index == currentLineIndex
                        Text(syncedLines[index].text.isEmpty ? "♪" : syncedLines[index].text)
                            .font(.system(size: isActive ? 24 : 20, weight: isActive ? .semibold : .medium, design: .default))
                            .foregroundStyle(isActive ? Color.volnaTextPrimary : Color.volnaTextPrimary.opacity(0.35))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                            .animation(.easeInOut(duration: 0.25), value: currentLineIndex)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .padding(.bottom, 40)
            }
            .onChange(of: currentLineIndex) { _, index in
                guard let index else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }

    private var currentLineIndex: Int? {
        guard !syncedLines.isEmpty else { return nil }
        let time = appState.player.currentTime
        var result: Int?
        for (index, line) in syncedLines.enumerated() {
            if line.timestamp <= time + 0.15 { result = index } else { break }
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
                errorMessage = "Текст для этой композиции не найден."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
