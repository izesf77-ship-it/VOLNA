import SwiftUI

struct MiniPlayerView: View {
    @Environment(AppState.self) private var appState

    private var player: PlayerService { appState.player }
    private var progress: Double {
        guard player.duration > 0 else { return 0 }
        return min(max(player.currentTime / player.duration, 0), 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                    Rectangle()
                        .fill(Color.volnaAccentGradient)
                        .frame(width: max(0, geometry.size.width * progress))
                }
            }
            .frame(height: 3)

            HStack(spacing: 12) {
                Button {
                    appState.showPlayer()
                } label: {
                    HStack(spacing: 12) {
                        ArtworkView(
                            url: player.currentTrack?.artworkURL,
                            size: 48,
                            cornerRadius: 10,
                            showProgress: false
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.currentTrack?.title ?? "Не воспроизводится")
                                .font(VolnaFont.custom(16, weight: .semibold, relativeTo: .headline))
                                .foregroundStyle(Color.volnaTextPrimary)
                                .lineLimit(1)

                            Text(player.currentTrack?.artist ?? "")
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
        .accessibilityLabel("Мини-плеер")
    }
}
