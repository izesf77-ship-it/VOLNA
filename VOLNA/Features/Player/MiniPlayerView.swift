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
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Color.volnaAccentGradient)
                        .frame(width: max(0, geometry.size.width * progress))
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 14)

            HStack(spacing: 10) {
                Button {
                    appState.showPlayer()
                } label: {
                    HStack(spacing: 10) {
                        ArtworkView(
                            url: player.currentTrack?.artworkURL,
                            size: 42,
                            cornerRadius: 11,
                            showProgress: false
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(player.currentTrack?.title ?? "")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.volnaTextPrimary)
                                .lineLimit(1)
                            HStack(spacing: 5) {
                                Text(player.currentTrack?.artist ?? "")
                                    .font(.system(size: 10, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color.volnaTextSecondary)
                                    .lineLimit(1)
                                if let track = player.currentTrack {
                                    ProviderBadge(providerID: track.providerID)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .frame(width: 34, height: 38)
                }
                .buttonStyle(.plain)

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .frame(width: 34, height: 38)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.volnaSurface.opacity(0.84))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
        .onTapGesture {
            appState.showPlayer()
        }
    }
}
