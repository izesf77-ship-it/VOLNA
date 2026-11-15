import SwiftUI

/// Полноэкранный режим радио. Намеренно не содержит прогресса, seek, очереди
/// и переключения треков: у прямого эфира нет длительности и следующего трека.
struct RadioPlayerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var player: PlayerService { appState.player }
    private var station: RadioStation? { player.radioStation }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                playerBackground(width: geometry.size.width, height: geometry.size.height)

                if let station {
                    VStack(spacing: 0) {
                        topBar(station: station)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 22) {
                                artworkSection(station: station, containerWidth: geometry.size.width)
                                stationInfo(station: station)
                                nowPlaying
                                playbackStatus
                                controls(station: station)
                                if player.hasMusicToResume {
                                    returnToMusicButton
                                }
                                detailsCard(station: station)
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
    }

    // MARK: - Background

    private func playerBackground(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Color.volnaBackground

            if let url = station?.favicon {
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
                .opacity(0.3)
                .scaleEffect(1.3)
                .saturation(1.1)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.volnaBackground.opacity(0.65),
                    Color.volnaBackground.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Top bar

    private func topBar(station: RadioStation) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay { Circle().stroke(Color.white.opacity(0.1), lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть плеер")

            Spacer()

            VStack(spacing: 2) {
                Text("Прямой эфир")
                    .font(VolnaFont.custom(12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(Color.volnaTextTertiary)
                Text(station.locationText.isEmpty ? "Радио" : station.locationText)
                    .font(VolnaFont.custom(13, weight: .semibold, relativeTo: .footnote))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                Button {
                    appState.radioFavorites.toggle(station)
                } label: {
                    Label(
                        appState.radioFavorites.isFavorite(station)
                            ? "Убрать из избранного"
                            : "В избранное",
                        systemImage: appState.radioFavorites.isFavorite(station) ? "heart.slash" : "heart"
                    )
                }

                Button {
                    player.retryRadioPlayback()
                } label: {
                    Label("Переподключить поток", systemImage: "arrow.clockwise")
                }

                if let homepage = station.homepage {
                    ShareLink(item: homepage) {
                        Label("Ссылка на станцию", systemImage: "square.and.arrow.up")
                    }
                }

                if player.hasMusicToResume {
                    Button {
                        player.returnToMusic()
                        dismiss()
                    } label: {
                        Label("Вернуться к музыке", systemImage: "music.note")
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

    private func artworkSection(station: RadioStation, containerWidth: CGFloat) -> some View {
        let size = min(containerWidth - 48, 320)
        return ZStack(alignment: .topLeading) {
            ArtworkView(
                url: station.favicon,
                size: size,
                cornerRadius: 26,
                placeholderIcon: "dot.radiowaves.left.and.right"
            )
            .shadow(color: .black.opacity(0.45), radius: 40, y: 20)
            .shadow(color: Color.volnaPurple.opacity(0.18), radius: 30, y: 10)

            RadioLiveBadge(isPlaying: player.isPlaying)
                .padding(14)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func stationInfo(station: RadioStation) -> some View {
        VStack(spacing: 7) {
            Text(station.displayName)
                .font(VolnaFont.custom(25, weight: .bold, relativeTo: .title2))
                .foregroundStyle(Color.volnaTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                if let genre = station.genreDisplay {
                    Text(genre)
                }
                if let quality = station.streamQualityText {
                    if station.genreDisplay != nil {
                        Text("·")
                            .foregroundStyle(Color.volnaTextTertiary)
                    }
                    Text(quality)
                }
            }
            .font(VolnaFont.custom(12, weight: .medium, relativeTo: .caption))
            .foregroundStyle(Color.volnaTextSecondary)
            .lineLimit(1)
        }
    }

    private var nowPlaying: some View {
        VStack(spacing: 6) {
            Text(player.radioMetadata == nil ? "ПРЯМОЙ ЭФИР" : "СЕЙЧАС В ЭФИРЕ")
                .font(.system(size: 10, weight: .bold, design: .default))
                .tracking(1.5)
                .foregroundStyle(Color.volnaTextTertiary)

            if let metadata = player.radioMetadata {
                Text(metadata.displayText)
                    .font(VolnaFont.custom(17, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            } else {
                Text("Информация о композиции недоступна")
                    .font(VolnaFont.custom(14, weight: .regular, relativeTo: .subheadline))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.25), value: player.radioMetadata?.rawTitle)
    }

    @ViewBuilder
    private var playbackStatus: some View {
        if player.isRadioReconnecting {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(Color.volnaAmber)
                Text(player.playbackError ?? "Восстанавливаем соединение…")
                    .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Color.volnaAmber.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.volnaAmber.opacity(0.18), lineWidth: 1)
            }
        } else if let error = player.playbackError {
            ErrorBanner(message: error) {
                player.retryRadioPlayback()
            }
        }
    }

    // MARK: - Controls

    private func controls(station: RadioStation) -> some View {
        VStack(spacing: 20) {
            // Main playback controls with navigation
            HStack(spacing: 18) {
                Button {
                    Task {
                        await appState.radio.playPreviousStationInCountry(player: player)
                    }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .frame(width: 60, height: 60)
                        .background(Color.white.opacity(0.09), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(player.isBuffering || player.isRadioReconnecting)
                .opacity(player.isBuffering || player.isRadioReconnecting ? 0.4 : 1)
                .accessibilityLabel("Предыдущая станция в стране")

                Button {
                    player.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 82, height: 82)
                            .shadow(color: .white.opacity(0.18), radius: 18, y: 6)

                        if player.isBuffering && player.isPlaying {
                            ProgressView()
                                .tint(.black)
                                .scaleEffect(1.15)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.black)
                                .offset(x: player.isPlaying ? 0 : 2)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "Пауза" : "Воспроизвести")

                Button {
                    Task {
                        await appState.radio.playNextStationInCountry(player: player)
                    }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .frame(width: 60, height: 60)
                        .background(Color.white.opacity(0.09), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(player.isBuffering || player.isRadioReconnecting)
                .opacity(player.isBuffering || player.isRadioReconnecting ? 0.4 : 1)
                .accessibilityLabel("Следующая станция в стране")
            }

            // Secondary controls
            HStack(spacing: 24) {
                Button {
                    appState.radioFavorites.toggle(station)
                } label: {
                    Image(systemName: appState.radioFavorites.isFavorite(station) ? "heart.fill" : "heart")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(
                            appState.radioFavorites.isFavorite(station)
                                ? Color.volnaMagenta
                                : Color.volnaTextSecondary
                        )
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.06), in: Circle())
                        .symbolEffect(.bounce, value: appState.radioFavorites.isFavorite(station))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    appState.radioFavorites.isFavorite(station)
                        ? "Убрать из избранного"
                        : "В избранное"
                )

                Button {
                    Task {
                        await appState.radio.playRandomStationInCountry(player: player)
                    }
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.volnaTextSecondary)
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(player.isBuffering || player.isRadioReconnecting)
                .opacity(player.isBuffering || player.isRadioReconnecting ? 0.4 : 1)
                .accessibilityLabel("Случайная станция в стране")

                Button {
                    player.retryRadioPlayback()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.volnaTextSecondary)
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Переподключить поток")
            }
        }
        .padding(.vertical, 4)
    }

    private var returnToMusicButton: some View {
        Button {
            player.returnToMusic()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 14, weight: .semibold))
                Text("Вернуться к музыке")
                    .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
            }
            .foregroundStyle(Color.volnaTextPrimary)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay { Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details

    private func detailsCard(station: RadioStation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("О станции")
                    .font(VolnaFont.custom(16, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(Color.volnaTextPrimary)
                Spacer()
                Text("Radio Browser")
                    .font(VolnaFont.custom(10, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }

            if !station.locationText.isEmpty {
                SourceDetailRow(
                    icon: "mappin.and.ellipse",
                    title: "Страна",
                    value: station.locationText,
                    tint: .volnaBlue
                )
            }

            if let languages = languageText(for: station) {
                SourceDetailRow(
                    icon: "globe",
                    title: "Язык",
                    value: languages,
                    tint: .volnaCyan
                )
            }

            if !station.tags.isEmpty {
                SourceDetailRow(
                    icon: "tag",
                    title: "Теги",
                    value: station.tags.prefix(6).joined(separator: " · "),
                    tint: .volnaPurple
                )
            }

            if let quality = station.streamQualityText {
                SourceDetailRow(
                    icon: "waveform",
                    title: "Поток",
                    value: quality,
                    tint: .volnaMint
                )
            }

            if let homepage = station.homepage {
                Link(destination: homepage) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                        Text("Сайт станции")
                    }
                    .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Color.volnaBlue)
                }
            }
        }
        .volnaCard(cornerRadius: 20, padding: 16)
    }

    private func languageText(for station: RadioStation) -> String? {
        let parts = station.language
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts.prefix(3)
            .map { String($0.prefix(1)).uppercased() + String($0.dropFirst()) }
            .joined(separator: ", ")
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack {
            Spacer()
            EmptyStateView(
                icon: "dot.radiowaves.left.and.right",
                title: "Станция не выбрана",
                message: "Откройте вкладку «Радио» и выберите эфир.",
                actionTitle: "Закрыть"
            ) {
                dismiss()
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}

#Preview {
    RadioPlayerView()
        .environment(AppState())
}
