import SwiftUI

/// Компактный контрол воспроизведения радио для встраивания в различные экраны.
/// Показывает текущую станцию и предоставляет управление: play/pause, prev/next.
struct RadioPlaybackControl: View {
    @Environment(AppState.self) private var appState
    
    private var player: PlayerService { appState.player }
    private var radio: RadioService { appState.radio }
    
    var body: some View {
        guard player.mode == .radio, let station = player.radioStation else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Сейчас играет")
                            .font(VolnaFont.custom(22, weight: .semibold, relativeTo: .title2))
                            .foregroundStyle(Color.volnaTextPrimary)
                        Text(station.locationText)
                            .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                            .foregroundStyle(Color.volnaTextTertiary)
                    }
                    Spacer(minLength: 8)
                    Button {
                        appState.isPlayerPresented = true
                    } label: {
                        Text("Открыть")
                            .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                            .foregroundStyle(Color.volnaPurple)
                    }
                }
                
                currentStationCard(station)
            }
        )
    }
    
    private func currentStationCard(_ station: RadioStation) -> some View {
        VStack(spacing: 0) {
            // Station info
            HStack(spacing: 14) {
                // Artwork/Icon
                if let artwork = station.favicon {
                    AsyncImage(url: artwork) { phase in
                        switch phase {
                        case .empty:
                            stationPlaceholder
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            stationPlaceholder
                        @unknown default:
                            stationPlaceholder
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    stationPlaceholder
                        .frame(width: 64, height: 64)
                }
                
                // Title and metadata
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.displayName)
                        .font(VolnaFont.custom(16, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .lineLimit(2)
                    
                    if let metadata = player.radioMetadata {
                        Text(metadata.displayText)
                            .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                            .foregroundStyle(Color.volnaTextSecondary)
                            .lineLimit(1)
                    } else {
                        Text("Прямой эфир")
                            .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                            .foregroundStyle(Color.volnaTextSecondary)
                    }
                }
                
                Spacer()
            }
            .padding(14)
            
            Divider()
                .overlay(Color.white.opacity(0.06))
            
            // Playback controls
            HStack(spacing: 20) {
                // Previous station (from same country)
                Button {
                    Task {
                        await radio.playPreviousStationInCountry(player: player)
                    }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(player.isBuffering || player.isRadioReconnecting)
                .opacity((player.isBuffering || player.isRadioReconnecting) ? 0.4 : 1.0)
                
                Spacer()
                
                // Play/Pause
                Button {
                    player.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.volnaPurple)
                            .frame(width: 56, height: 56)
                        
                        if player.isBuffering || player.isRadioReconnecting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Next station (from same country)
                Button {
                    Task {
                        await radio.playNextStationInCountry(player: player)
                    }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(player.isBuffering || player.isRadioReconnecting)
                .opacity((player.isBuffering || player.isRadioReconnecting) ? 0.4 : 1.0)
                
                // Random station from same country
                Button {
                    Task {
                        await radio.playRandomStationInCountry(player: player)
                    }
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.volnaTextSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(player.isBuffering || player.isRadioReconnecting)
                .opacity((player.isBuffering || player.isRadioReconnecting) ? 0.4 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .volnaCard(cornerRadius: 18, padding: 0)
    }
    
    private var stationPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.volnaSurface)
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color.volnaTextTertiary)
        }
    }
}
