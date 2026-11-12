import SwiftUI

struct PlayerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0
    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var showStreams = false

    private var player: PlayerService { appState.player }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VolnaBackground()
                artworkBackdrop(width: geometry.size.width, height: geometry.size.height)

                if let track = player.currentTrack {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            topBar
                            artwork(track: track, size: min(geometry.size.width - 64, 320))
                            trackInfo(track: track)
                            progressSection
                            controls
                            secondaryActions(track: track)
                            queuePreview
                            sourceCard(track: track)
                            Color.clear.frame(height: 20)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                } else {
                    emptyState
                }
            }
        }
        .sheet(isPresented: $showLyrics) {
            if let track = player.currentTrack {
                LyricsView(track: track)
                    .environment(appState)
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
                .environment(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Background

    private func artworkBackdrop(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if let url = player.currentTrack?.artworkURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.clear
                    }
                }
                .frame(width: width, height: height)
                .clipped()
                .blur(radius: 78)
                .opacity(0.34)
                .scaleEffect(1.25)
            }

            LinearGradient(
                colors: [
                    Color.volnaBackground.opacity(0.18),
                    Color.volnaBackground.opacity(0.72),
                    Color.volnaBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("СЕЙЧАС ИГРАЕТ")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(Color.volnaTextTertiary)
                Text(player.currentTrack?.providerDisplayName ?? "VOLNA")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaTextSecondary)
            }

            Spacer()

            Menu {
                Button {
                    showLyrics = true
                } label: {
                    Label("Текст песни", systemImage: "text.quote")
                }
                Button {
                    showQueue = true
                } label: {
                    Label("Очередь", systemImage: "list.bullet")
                }
                if let page = player.currentTrack?.sourcePageURL {
                    ShareLink(item: page) {
                        Label("Страница источника", systemImage: "safari")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    player.clearQueue()
                } label: {
                    Label("Очистить очередь", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Artwork / info

    private func artwork(track: Track, size: CGFloat) -> some View {
        ArtworkView(url: track.artworkURL, size: size, cornerRadius: 30)
            .shadow(color: Color.volnaPurple.opacity(0.28), radius: 34, y: 18)
            .padding(.top, 4)
    }

    private func trackInfo(track: Track) -> some View {
        VStack(spacing: 7) {
            Text(track.title)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(Color.volnaTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            Text(track.artist)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.volnaTextSecondary)
                .lineLimit(2)

            HStack(spacing: 7) {
                ProviderBadge(providerID: track.providerID, compact: false)
                if track.license.isKnownOpenLicense {
                    LicenseBadge(license: track.license)
                } else {
                    Text("Лицензия неизвестна")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.volnaTextTertiary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }
                if track.availableStreams.count > 1 {
                    Text("\(track.availableStreams.count) потока")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.volnaBlue)
                }
            }

            if let error = player.playbackError {
                ErrorBanner(message: error)
                    .padding(.top, 6)
            }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubValue : player.currentTime },
                    set: { scrubValue = $0 }
                ),
                in: 0...max(player.duration, 1),
                onEditingChanged: { editing in
                    if editing {
                        scrubValue = player.currentTime
                        isScrubbing = true
                    } else {
                        player.seek(to: scrubValue)
                        isScrubbing = false
                    }
                }
            )
            .tint(Color.volnaPurple)
            .disabled(player.duration <= 0)
            .opacity(player.duration <= 0 ? 0.4 : 1)

            HStack {
                Text(formatTime(isScrubbing ? scrubValue : player.currentTime))
                Spacer()
                if player.isBuffering {
                    ProgressView()
                        .tint(Color.volnaTextTertiary)
                        .scaleEffect(0.55)
                }
                Text(player.duration > 0 ? "-\(formatTime(max(0, player.duration - (isScrubbing ? scrubValue : player.currentTime))))" : "--:--")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.volnaTextTertiary)
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            Button {
                player.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(player.isShuffled ? Color.volnaPurple : Color.volnaTextSecondary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .frame(width: 58, height: 52)
            }
            .buttonStyle(.plain)

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.volnaAccentGradient)
                        .frame(width: 76, height: 76)
                        .shadow(color: Color.volnaPurple.opacity(0.5), radius: 20, y: 6)
                    if player.isBuffering {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.05)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 27, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .frame(width: 58, height: 52)
            }
            .buttonStyle(.plain)

            Button {
                player.cycleRepeatMode()
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(player.repeatMode == .off ? Color.volnaTextSecondary : Color.volnaPurple)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func secondaryActions(track: Track) -> some View {
        HStack(spacing: 26) {
            Button {
                _ = appState.toggleFavorite(track)
            } label: {
                Image(systemName: appState.library.isFavorite(track) ? "heart.fill" : "heart")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(appState.library.isFavorite(track) ? Color.volnaMagenta : Color.volnaTextSecondary)
            }
            .buttonStyle(.plain)

            Button {
                showLyrics = true
            } label: {
                Image(systemName: "text.quote")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.volnaTextSecondary)
            }
            .buttonStyle(.plain)

            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.volnaTextSecondary)
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    player.playNext(track)
                } label: {
                    Label("Играть следующим", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                Button {
                    player.appendToQueue(track)
                } label: {
                    Label("Добавить в очередь", systemImage: "text.badge.plus")
                }
                Button {
                    appState.library.createPlaylist(title: "Мой плейлист")
                    if let playlist = appState.library.playlists.first {
                        appState.library.addTrack(track, to: playlist.id)
                    }
                } label: {
                    Label("В новый плейлист", systemImage: "music.note.list")
                }
                if let page = track.sourcePageURL {
                    ShareLink(item: page) {
                        Label("Открыть источник", systemImage: "safari")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.volnaTextSecondary)
            }
        }
    }

    // MARK: - Queue preview

    private var queuePreview: some View {
        Group {
            if player.queue.count > 1 {
                Button {
                    showQueue = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.volnaPurple)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Очередь · \(player.queue.count)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.volnaTextPrimary)
                            if let next = nextTrack {
                                Text("Далее: \(next.title) — \(next.artist)")
                                    .font(.system(size: 10, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color.volnaTextTertiary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.volnaTextTertiary)
                    }
                    .padding(13)
                    .background(Color.white.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var nextTrack: Track? {
        let queue = player.queue
        guard queue.count > 1 else { return nil }
        let nextIndex = player.currentIndex + 1
        if queue.indices.contains(nextIndex) {
            return queue[nextIndex]
        }
        if player.repeatMode == .all {
            return queue.first
        }
        return nil
    }

    // MARK: - Source card

    private func sourceCard(track: Track) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Источник и лицензия")
                    .font(.volnaHeadline(14))
                    .foregroundStyle(Color.volnaTextPrimary)
                Spacer()
                ProviderBadge(providerID: track.providerID, compact: false)
            }

            SourceDetailRow(
                icon: "waveform",
                title: "Поток",
                value: track.primaryStream?.format.displayName ?? "Недоступен",
                tint: .volnaBlue
            )
            SourceDetailRow(
                icon: "arrow.down.circle",
                title: "Скачивание",
                value: track.isDownloadAllowed ? "Разрешено источником" : "Не разрешено",
                tint: track.isDownloadAllowed ? .volnaMint : .volnaTextTertiary
            )
            SourceDetailRow(
                icon: "checkmark.seal",
                title: "Лицензия",
                value: track.license.isKnownOpenLicense ? track.license.displayName : "Неизвестна — не считается свободной",
                tint: track.license.isKnownOpenLicense ? .volnaMint : .volnaWarning
            )

            if let attribution = track.attribution, !attribution.isEmpty {
                Text(attribution)
                    .font(.volnaBody(10))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .lineSpacing(2)
            }

            if track.availableStreams.count > 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showStreams.toggle()
                    }
                } label: {
                    HStack {
                        Text("Доступные потоки (\(track.availableStreams.count))")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.volnaPurple)
                        Spacer()
                        Image(systemName: showStreams ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.volnaTextTertiary)
                    }
                }
                .buttonStyle(.plain)

                if showStreams {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(track.availableStreams) { stream in
                            HStack {
                                ProviderBadge(providerID: stream.providerID)
                                Text(stream.format.displayName)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.volnaTextSecondary)
                                Spacer()
                                Text(stream.availability == .available ? "доступен" : "недоступен")
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(stream.availability == .available ? Color.volnaMint : Color.volnaTextTertiary)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }

            if let page = track.sourcePageURL {
                Link(destination: page) {
                    HStack(spacing: 5) {
                        Image(systemName: "safari")
                        Text("Страница источника")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaBlue)
                }
            }
        }
        .volnaCard(cornerRadius: 20, padding: 15)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            EmptyStateView(
                icon: "waveform",
                title: "Ничего не играет",
                message: "Выберите трек в поиске или на главной странице.",
                actionTitle: "Закрыть"
            ) {
                dismiss()
            }
            Spacer()
        }
        .padding(24)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let total = Int(time.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    PlayerView()
        .environment(AppState())
}
