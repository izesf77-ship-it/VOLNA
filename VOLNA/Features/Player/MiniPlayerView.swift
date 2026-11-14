import SwiftUI

struct MiniPlayerView: View {
    @Environment(AppState.self) private var appState

    private var player: PlayerService { appState.player }
    private var isRadio: Bool { player.mode == .radio }
    private var station: RadioStation? { player.radioStation }

    private var progress: Double {
        guard !isRadio else { return 0 }
        guard player.duration > 0 else { return 0 }
        return min(max(player.currentTime / player.duration, 0), 1)
    }

    private var artworkURL: URL? {
        isRadio ? station?.favicon : player.currentTrack?.artworkURL
    }

    private var artworkIcon: String {
        isRadio ? "dot.radiowaves.left.and.right" : "music.note"
    }

    private var title: String {
        if isRadio {
            return station?.displayName ?? "Радио"
        }
        return player.currentTrack?.title ?? "Не воспроизводится"
    }

    private var subtitle: String {
        if isRadio {
            if let metadata = player.radioMetadata {
                return metadata.displayText
            }
            guard let station else { return "Прямой эфир" }
            return station.locationText.isEmpty
                ? "Прямой эфир"
                : "Прямой эфир · \(station.locationText)"
        }
        return player.currentTrack?.artist ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if isRadio {
                    // У прямого эфира нет длительности и прогресса. Полоса
                    // остаётся акцентом, но не изображает несуществующий seek.
                    Rectangle()
                        .fill(Color.volnaAccentGradient.opacity(0.65))
                } else {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                            Rectangle()
                                .fill(Color.volnaAccentGradient)
                                .frame(width: max(0, geometry.size.width * progress))
                        }
                    }
                }
            }
            .frame(height: 3)

            HStack(spacing: 12) {
                Button {
                    appState.showPlayer()
                } label: {
                    HStack(spacing: 12) {
                        ArtworkView(
                            url: artworkURL,
                            size: 48,
                            cornerRadius: 10,
                            showProgress: false,
                            placeholderIcon: artworkIcon
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(VolnaFont.custom(16, weight: .semibold, relativeTo: .headline))
                                .foregroundStyle(Color.volnaTextPrimary)
                                .lineLimit(1)

                            Text(subtitle)
                                .font(VolnaFont.custom(14, weight: .regular, relativeTo: .subheadline))
                                .foregroundStyle(Color.volnaTextSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.volnaTextPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(player.isPlaying ? "Пауза" : "Воспроизвести")

                    if isRadio, let station {
                        Button {
                            appState.radioFavorites.toggle(station)
                        } label: {
                            Image(systemName: appState.radioFavorites.isFavorite(station) ? "heart.fill" : "heart")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(
                                    appState.radioFavorites.isFavorite(station)
                                        ? Color.volnaMagenta
                                        : Color.volnaTextPrimary
                                )
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                                .symbolEffect(.bounce, value: appState.radioFavorites.isFavorite(station))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            appState.radioFavorites.isFavorite(station)
                                ? "Убрать станцию из избранного"
                                : "Добавить станцию в избранное"
                        )
                    } else {
                        Button {
                            player.next()
                        } label: {
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.volnaTextPrimary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Следующий трек")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(height: VolnaLayout.miniPlayerHeight - 3)
        }
        .frame(height: VolnaLayout.miniPlayerHeight)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.volnaSurfaceGlass)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 10)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.showPlayer()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isRadio ? "Мини-плеер, радио" : "Мини-плеер")
    }
}
