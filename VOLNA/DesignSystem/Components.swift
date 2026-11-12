import SwiftUI

// MARK: - Artwork

struct ArtworkView: View {
    let url: URL?
    var size: CGFloat
    var cornerRadius: CGFloat = 16
    var showProgress = true

    var body: some View {
        AsyncImage(
            url: url,
            transaction: Transaction(animation: .easeInOut(duration: 0.22))
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholder
            case .empty:
                ZStack {
                    placeholder
                    if showProgress {
                        ProgressView()
                            .tint(.white.opacity(0.55))
                            .scaleEffect(0.8)
                    }
                }
            @unknown default:
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.volnaElevated,
                    Color.volnaSurfaceSecondary,
                    Color.volnaPurple.opacity(0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "waveform")
                .font(.system(size: max(20, size * 0.24), weight: .medium))
                .foregroundStyle(.white.opacity(0.30))
        }
    }
}

// MARK: - Headers

struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var eyebrow: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(Color.volnaPurple)
            }
            Text(title)
                .font(.volnaDisplay(32))
                .foregroundStyle(Color.volnaTextPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.volnaBody(14))
                    .foregroundStyle(Color.volnaTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.volnaHeadline(20))
                    .foregroundStyle(Color.volnaTextPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.volnaBody(12))
                        .foregroundStyle(Color.volnaTextTertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 12)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaPurple)
            }
        }
    }
}

// MARK: - Chips / badges

struct VolnaChip: View {
    let title: String
    var icon: String? = nil
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? Color.white : Color.volnaTextSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(Color.volnaAccentGradient) : AnyShapeStyle(Color.white.opacity(0.06)))
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(isSelected ? 0.12 : 0.07), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ProviderBadge: View {
    let providerID: String
    var compact = true

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(MusicSourceCatalog.info(for: providerID)?.shortName ?? providerID)
                .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.volnaTextSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 4)
        .background(Color.white.opacity(0.055))
        .clipShape(Capsule())
    }

    private var color: Color {
        switch providerID {
        case "jamendo": return .volnaMint
        case "internet_archive": return .volnaBlue
        case "wikimedia_commons": return .volnaAmber
        case "openverse": return .volnaMagenta
        case "direct": return .volnaCyan
        default: return .volnaTextTertiary
        }
    }
}

struct LicenseBadge: View {
    let license: LicenseType

    var body: some View {
        Text(license.shortDisplayName)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.11))
            .clipShape(Capsule())
    }

    private var color: Color {
        switch license {
        case .cc0, .publicDomain: return .volnaMint
        case .ccBy, .ccBySa, .ccByNd, .ccByNc, .ccByNcSa, .ccByNcNd: return .volnaBlue
        case .unknown, .other: return .volnaTextTertiary
        case .restricted: return .volnaError
        }
    }
}

struct SourceDetailRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var tint: Color = .volnaPurple

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12))
                .clipShape(Circle())
            Text(title)
                .font(.volnaBody(14))
                .foregroundStyle(Color.volnaTextSecondary)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.volnaAccentGradient)
                    .opacity(0.16)
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.volnaPurple)
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.volnaHeadline(17))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.volnaBody(13))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(VolnaPrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 22)
        .volnaCard()
    }
}

// MARK: - Cards

struct AlbumCard: View {
    let album: Album
    var width: CGFloat = 152

    var body: some View {
        NavigationLink(value: album) {
            VStack(alignment: .leading, spacing: 9) {
                ArtworkView(url: album.artworkURL, size: width, cornerRadius: 18)
                Text(album.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(1)
                Text(album.artist)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .lineLimit(1)
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

struct ArtistCard: View {
    let artist: Artist
    var width: CGFloat = 96

    var body: some View {
        NavigationLink(value: artist) {
            VStack(spacing: 8) {
                ArtworkView(
                    url: artist.artworkURL,
                    size: width,
                    cornerRadius: width / 2
                )
                Text(artist.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(1)
                    .frame(width: width)
                Text("Исполнитель")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.volnaTextTertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct PlaylistCard: View {
    let playlist: Playlist

    var body: some View {
        NavigationLink(value: playlist) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    if let url = playlist.artworkURL {
                        ArtworkView(url: url, size: 150, cornerRadius: 20)
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.volnaAccentGradient)
                            .opacity(0.55)
                            .frame(width: 150, height: 150)
                            .overlay {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 34, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                    }
                }
                Text(playlist.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(1)
                Text("\(playlist.trackCount) треков")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.volnaTextTertiary)
            }
            .frame(width: 150, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Track row

struct TrackRow: View {
    @Environment(AppState.self) private var appState
    let track: Track
    var queue: [Track]? = nil
    var showFavorite = true
    var showArtwork = true
    var showProvider = true

    @State private var showPlaylistDialog = false

    private var isCurrent: Bool {
        appState.player.currentTrack?.id == track.id
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                appState.play(track, in: queue ?? [track])
            } label: {
                HStack(spacing: 12) {
                    if showArtwork {
                        ZStack {
                            ArtworkView(url: track.artworkURL, size: 52, cornerRadius: 12)
                            if isCurrent {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.black.opacity(0.45))
                                    .frame(width: 52, height: 52)
                                Image(systemName: appState.player.isPlaying ? "waveform" : "pause.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.system(size: 14, weight: isCurrent ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(isCurrent ? Color.volnaPurple : Color.volnaTextPrimary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(track.artist)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(Color.volnaTextSecondary)
                                .lineLimit(1)
                            if showProvider {
                                ProviderBadge(providerID: track.providerID)
                            }
                            if track.explicit, appState.settings.showExplicitContent {
                                Text("E")
                                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Color.volnaWarning)
                                    .frame(width: 14, height: 14)
                                    .background(Color.volnaWarning.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                            if appState.settings.showLicenseBadges, track.license.isKnownOpenLicense {
                                LicenseBadge(license: track.license)
                            }
                        }
                    }

                    Spacer(minLength: 4)

                    if let duration = track.durationFormatted {
                        Text(duration)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.volnaTextTertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showFavorite {
                Button {
                    _ = appState.toggleFavorite(track)
                } label: {
                    Image(systemName: appState.library.isFavorite(track) ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(appState.library.isFavorite(track) ? Color.volnaMagenta : Color.volnaTextTertiary)
                        .frame(width: 34, height: 38)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                appState.play(track, in: queue ?? [track])
            } label: {
                Label("Слушать", systemImage: "play.fill")
            }
            Button {
                appState.player.playNext(track)
            } label: {
                Label("Следующим", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            Button {
                appState.player.appendToQueue(track)
            } label: {
                Label("В очередь", systemImage: "text.badge.plus")
            }
            Divider()
            Button {
                _ = appState.toggleFavorite(track)
            } label: {
                Label(
                    appState.library.isFavorite(track) ? "Убрать из избранного" : "В избранное",
                    systemImage: appState.library.isFavorite(track) ? "heart.slash" : "heart"
                )
            }
            Button {
                showPlaylistDialog = true
            } label: {
                Label("Добавить в плейлист", systemImage: "music.note.list")
            }
            if let page = track.sourcePageURL {
                Divider()
                ShareLink(item: page) {
                    Label("Открыть страницу источника", systemImage: "safari")
                }
            }
        }
        .confirmationDialog(
            "Добавить в плейлист",
            isPresented: $showPlaylistDialog,
            titleVisibility: .visible
        ) {
            ForEach(appState.library.playlists) { playlist in
                Button(playlist.title) {
                    appState.library.addTrack(track, to: playlist.id)
                }
            }
            Button("Создать новый плейлист") {
                let playlist = appState.library.createPlaylist(title: "Мой плейлист")
                appState.library.addTrack(track, to: playlist.id)
            }
            Button("Отмена", role: .cancel) {}
        }
    }
}

// MARK: - Large track card (horizontal shelves)

struct TrackCard: View {
    @Environment(AppState.self) private var appState
    let track: Track
    var queue: [Track] = []
    var width: CGFloat = 156

    var body: some View {
        Button {
            appState.play(track, in: queue.isEmpty ? [track] : queue)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                ZStack(alignment: .bottomTrailing) {
                    ArtworkView(url: track.artworkURL, size: width, cornerRadius: 20)
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(8)
                }
                Text(track.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(track.artist)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.volnaTextTertiary)
                        .lineLimit(1)
                    ProviderBadge(providerID: track.providerID)
                }
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                appState.player.playNext(track)
            } label: {
                Label("Следующим", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            Button {
                appState.player.appendToQueue(track)
            } label: {
                Label("В очередь", systemImage: "text.badge.plus")
            }
            Button {
                _ = appState.toggleFavorite(track)
            } label: {
                Label("В избранное", systemImage: "heart")
            }
        }
    }
}

// MARK: - Error banner

struct ErrorBanner: View {
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.volnaWarning)
            Text(message)
                .font(.volnaBody(12))
                .foregroundStyle(Color.volnaTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let retry {
                Button("Повторить", action: retry)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaPurple)
            }
        }
        .padding(12)
        .background(Color.volnaWarning.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.volnaWarning.opacity(0.18), lineWidth: 1)
        }
    }
}
