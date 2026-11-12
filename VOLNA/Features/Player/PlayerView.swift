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
                playerBackground(width: geometry.size.width, height: geometry.size.height)

                if let track = player.currentTrack {
                    VStack(spacing: 0) {
                        topBar
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 24) {
                                artworkSection(track: track, containerWidth: geometry.size.width)
                                trackInfo(track: track)
                                progressSection
                                controls
                                secondaryActions(track: track)
                                queuePreview
                                sourceCard(track: track)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .padding(.bottom, 40)
                        }
                    }
                } else {
                    emptyState
                }
            }
        }
        .preferredColorScheme(.dark)
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

    private func playerBackground(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Color.volnaBackground

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
                .blur(radius: 100)
                .opacity(0.35)
                .scaleEffect(1.3)
                .saturation(1.2)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.2),
                    Color.volnaBackground.opacity(0.6),
                    Color.volnaBackground.opacity(0.95)
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
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay { Circle().stroke(Color.white.opacity(0.1), lineWidth: 1) }
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("Сейчас играет")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(Color.volnaTextTertiary)
                if let track = player.currentTrack {
                    Text(MusicSourceCatalog.info(for: track.providerID)?.name ?? "VOLNA")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundStyle(Color.volnaTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Menu {
                Button { showLyrics = true } label: {
                    Label("Текст песни", systemImage: "quote.bubble")
                }
                Button { showQueue = true } label: {
                    Label("Очередь", systemImage: "list.bullet")
                }
                if let page = player.currentTrack?.sourcePageURL {
                    ShareLink(item: page) {
                        Label("Страница источника", systemImage: "safari")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay { Circle().stroke(Color.white.opacity(0.1), lineWidth: 1) }
            }
        }
    }

    // MARK: - Artwork / info

    private func artworkSection(track: Track, containerWidth: CGFloat) -> some View {
        let size = min(containerWidth - 48, 340)
        return ArtworkView(url: track.artworkURL, size: size, cornerRadius: 24)
            .shadow(color: .black.opacity(0.4), radius: 40, y: 20)
            .shadow(color: Color.volnaPurple.opacity(0.2), radius: 30, y: 10)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .animation(.easeInOut(duration: 0.3), value: track.id)
    }

    private func trackInfo(track: Track) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 24, weight: .bold, design: .default))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(track.artist)
                        .font(.system(size: 18, weight: .medium, design: .default))
                        .foregroundStyle(Color.volnaTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    _ = appState.toggleFavorite(track)
                } label: {
                    Image(systemName: appState.library.isFavorite(track) ? "heart.fill" : "heart")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(appState.library.isFavorite(track) ? Color.volnaMagenta : Color.volnaTextSecondary)
                        .frame(width: 44, height: 44)
                        .symbolEffect(.bounce, value: appState.library.isFavorite(track))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appState.library.isFavorite(track) ? "Убрать из избранного" : "В избранное")
            }

            HStack(spacing: 8) {
                ProviderBadge(providerID: track.providerID, compact: false)
                if track.license.isKnownOpenLicense {
                    LicenseBadge(license: track.license)
                } else {
                    Text("Лицензия неизвестна")
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundStyle(Color.volnaTextTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
                Spacer()
            }

            if let error = player.playbackError {
                ErrorBanner(message: error)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 8) {
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
            .tint(.white)
            .disabled(player.duration <= 0)
            .opacity(player.duration <= 0 ? 0.4 : 1)

            HStack {
                Text(formatTime(isScrubbing ? scrubValue : player.currentTime))
                Spacer()
                if player.isBuffering {
                    ProgressView().tint(Color.volnaTextTertiary).scaleEffect(0.6)
                    Spacer()
                }
                Text(player.duration > 0 ? formatTime(player.duration) : "--:--")
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.volnaTextTertiary)
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            Button { player.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(player.isShuffled ? Color.volnaPurple : Color.volnaTextSecondary)
                    .frame(width: 44, height: 44)
                    .symbolEffect(.bounce, value: player.isShuffled)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Перемешивание")

            Button { player.previous() } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Предыдущий трек")

            Button { player.togglePlayPause() } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 76, height: 76)
                        .shadow(color: .white.opacity(0.18), radius: 18, y: 6)
                    if player.isBuffering {
                        ProgressView().tint(.black).scaleEffect(1.1)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.black)
                            .offset(x: player.isPlaying ? 0 : 2)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(player.isPlaying ? "Пауза" : "Воспроизвести")

            Button { player.next() } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Следующий трек")

            Button { player.cycleRepeatMode() } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(player.repeatMode == .off ? Color.volnaTextSecondary : Color.volnaPurple)
                    .frame(width: 44, height: 44)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Повтор")
        }
        .padding(.vertical, 8)
    }

    private func secondaryActions(track: Track) -> some View {
        HStack(spacing: 0) {
            Button { showLyrics = true } label: {
                VStack(spacing: 6) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 20, weight: .medium))
                    Text("Текст")
                        .font(.system(size: 11, weight: .medium, design: .default))
                }
                .foregroundStyle(Color.volnaTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.plain)

            Button { showQueue = true } label: {
                VStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20, weight: .medium))
                    Text("Очередь")
                        .font(.system(size: 11, weight: .medium, design: .default))
                }
                .foregroundStyle(Color.volnaTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.plain)

            if let page = track.sourcePageURL {
                ShareLink(item: page) {
                    VStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .medium))
                        Text("Источник")
                            .font(.system(size: 11, weight: .medium, design: .default))
                    }
                    .foregroundStyle(Color.volnaTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
            } else {
                Button {
                    if let page = track.sourcePageURL { /* no-op fallback */ }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20, weight: .medium))
                        Text("Инфо")
                            .font(.system(size: 11, weight: .medium, design: .default))
                    }
                    .foregroundStyle(Color.volnaTextTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                .disabled(true)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Queue preview

    private var queuePreview: some View {
        Group {
            if player.queue.count > 1 {
                Button { showQueue = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.volnaPurple)
                            .frame(width: 36, height: 36)
                            .background(Color.volnaPurple.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Очередь · \(player.queue.count)")
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundStyle(Color.volnaTextPrimary)
                            if let next = nextTrack {
                                Text("Далее: \(next.title)")
                                    .font(.system(size: 13, weight: .regular, design: .default))
                                    .foregroundStyle(Color.volnaTextSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.volnaTextTertiary)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var nextTrack: Track? {
        let queue = player.queue
        guard queue.count > 1 else { return nil }
        let nextIndex = player.currentIndex + 1
        if queue.indices.contains(nextIndex) { return queue[nextIndex] }
        if player.repeatMode == .all { return queue.first }
        return nil
    }

    // MARK: - Source card

    private func sourceCard(track: Track) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Источник и лицензия")
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(Color.volnaTextPrimary)
                Spacer()
                ProviderBadge(providerID: track.providerID, compact: false)
            }

            VStack(spacing: 12) {
                SourceDetailRow(icon: "waveform", title: "Формат", value: track.primaryStream?.format.displayName ?? "Недоступен", tint: .volnaBlue)
                SourceDetailRow(icon: "arrow.down.circle", title: "Скачивание", value: track.isDownloadAllowed ? "Разрешено" : "Не разрешено", tint: track.isDownloadAllowed ? .volnaMint : .volnaTextTertiary)
                SourceDetailRow(icon: "checkmark.seal", title: "Лицензия", value: track.license.isKnownOpenLicense ? track.license.displayName : "Неизвестна", tint: track.license.isKnownOpenLicense ? .volnaMint : .volnaWarning)
            }

            if let attribution = track.attribution, !attribution.isEmpty {
                Text(attribution)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if track.availableStreams.count > 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showStreams.toggle() }
                } label: {
                    HStack {
                        Text("Доступные потоки (\(track.availableStreams.count))")
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundStyle(Color.volnaPurple)
                        Spacer()
                        Image(systemName: showStreams ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.volnaTextTertiary)
                    }
                }
                .buttonStyle(.plain)

                if showStreams {
                    VStack(spacing: 8) {
                        ForEach(track.availableStreams) { stream in
                            HStack {
                                ProviderBadge(providerID: stream.providerID)
                                Text(stream.format.displayName)
                                    .font(.system(size: 13, weight: .regular, design: .default))
                                    .foregroundStyle(Color.volnaTextSecondary)
                                Spacer()
                                Text(stream.availability == .available ? "Доступен" : "Недоступен")
                                    .font(.system(size: 12, weight: .medium, design: .default))
                                    .foregroundStyle(stream.availability == .available ? Color.volnaMint : Color.volnaTextTertiary)
                            }
                        }
                    }
                }
            }

            if let page = track.sourcePageURL {
                Link(destination: page) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                        Text("Страница источника")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(Color.volnaBlue)
                }
            }
        }
        .volnaCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            EmptyStateView(
                icon: "play.circle",
                title: "Ничего не играет",
                message: "Выберите трек в поиске или на главной странице.",
                actionTitle: "Закрыть"
            ) { dismiss() }
            .padding(.horizontal, 24)
            Spacer()
        }
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
