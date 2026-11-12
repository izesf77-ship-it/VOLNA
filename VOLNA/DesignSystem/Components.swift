import SwiftUI

// MARK: - Artwork

struct ArtworkView: View {
    let url: URL?
    var size: CGFloat
    var cornerRadius: CGFloat = 12
    var showProgress = true
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(
            url: url,
            transaction: Transaction(animation: .easeInOut(duration: 0.25))
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder
            case .empty:
                ZStack {
                    placeholder
                    if showProgress {
                        ProgressView()
                            .tint(.white.opacity(0.5))
                            .scaleEffect(0.75)
                    }
                }
            @unknown default:
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(Color.volnaSurfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.volnaElevated,
                    Color.volnaSurfaceSecondary,
                    Color.volnaPurple.opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: max(18, size * 0.28), weight: .medium))
                .foregroundStyle(.white.opacity(0.25))
        }
    }
}

// MARK: - Headers

struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var eyebrow: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .tracking(1.4)
                    .foregroundStyle(Color.volnaTextTertiary)
            }
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundStyle(Color.volnaTextPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold, design: .default))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundStyle(Color.volnaTextTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(Color.volnaPurple)
                }
                .buttonStyle(.plain)
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
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.volnaTextSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(Color.volnaAccentGradient) : AnyShapeStyle(Color.white.opacity(0.06)))
            }
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(isSelected ? 0.0 : 0.08), lineWidth: 1)
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
                .font(.system(size: compact ? 10 : 11, weight: .medium, design: .default))
                .foregroundStyle(Color.volnaTextSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 4)
        .background(Color.white.opacity(0.06))
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
            .font(.system(size: 10, weight: .medium, design: .default))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .lineLimit(1)
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
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(Color.volnaTextSecondary)

            Spacer(minLength: 12)

            if let value {
                Text(value)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
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
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.volnaAccentGradient.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Color.volnaPurple)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(VolnaPrimaryButtonStyle())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .volnaCard(cornerRadius: 24, padding: 20, style: .glass)
    }
}

// MARK: - Error banner

struct ErrorBanner: View {
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.volnaWarning)
                .padding(.top, 1)

            Text(message)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(Color.volnaTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if let retry {
                Button("Повторить", action: retry)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(Color.volnaPurple)
            }
        }
        .padding(14)
        .background(Color.volnaWarning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.volnaWarning.opacity(0.18), lineWidth: 1)
        }
    }
}

// MARK: - Cards

struct AlbumCard: View {
    let album: Album
    var width: CGFloat = 160

    var body: some View {
        NavigationLink(value: album) {
            VStack(alignment: .leading, spacing: 10) {
                ArtworkView(url: album.artworkURL, size: width, cornerRadius: 16)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)

                VStack(alignment: .leading, spacing: 3) {
                    Text(album.title)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(album.artist)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundStyle(Color.volnaTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

struct ArtistCard: View {
    let artist: Artist
    var width: CGFloat = 100

    var body: some View {
        NavigationLink(value: artist) {
            VStack(spacing: 10) {
                ArtworkView(url: artist.artworkURL, size: width, cornerRadius: width / 2)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)

                VStack(spacing: 2) {
                    Text(artist.name)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: width + 8)

                    Text("Исполнитель")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
            }
            .frame(width: width + 8)
        }
        .buttonStyle(.plain)
    }
}

struct PlaylistCard: View {
    let playlist: Playlist
    var width: CGFloat = 160

    var body: some View {
        NavigationLink(value: playlist) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    if let url = playlist.artworkURL {
                        ArtworkView(url: url, size: width, cornerRadius: 16)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.volnaAccentGradient.opacity(0.7))
                            .frame(width: width, height: width)
                            .overlay {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 36, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                    }
                }
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(playlist.title)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .lineLimit(2)

                    Text("\(playlist.trackCount) треков")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundStyle(Color.volnaTextSecondary)
                }
            }
            .frame(width: width, alignment: .leading)
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
        HStack(spacing: 12) {
            Button {
                appState.play(track, in: queue ?? [track])
            } label: {
                HStack(spacing: 12) {
                    if showArtwork {
                        ZStack {
                            ArtworkView(url: track.artworkURL, size: 52, cornerRadius: 10)
                            if isCurrent {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.black.opacity(0.5))
                                    .frame(width: 52, height: 52)
                                Image(systemName: appState.player.isPlaying ? "waveform" : "pause.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .symbolEffect(.variableColor.iterative, isActive: appState.player.isPlaying)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.system(size: 15, weight: isCurrent ? .semibold : .medium, design: .default))
                            .foregroundStyle(isCurrent ? Color.volnaPurple : Color.volnaTextPrimary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(track.artist)
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .foregroundStyle(Color.volnaTextSecondary)
                                .lineLimit(1)

                            if showProvider {
                                ProviderBadge(providerID: track.providerID)
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    if let duration = track.durationFormatted {
                        Text(duration)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
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
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(appState.library.isFavorite(track) ? Color.volnaMagenta : Color.volnaTextTertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button { appState.play(track, in: queue ?? [track]) } label: {
                Label("Слушать", systemImage: "play.fill")
            }
            Button { appState.player.playNext(track) } label: {
                Label("Следующим", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            Button { appState.player.appendToQueue(track) } label: {
                Label("В очередь", systemImage: "text.badge.plus")
            }
            Divider()
            Button { _ = appState.toggleFavorite(track) } label: {
                Label(
                    appState.library.isFavorite(track) ? "Убрать из избранного" : "В избранное",
                    systemImage: appState.library.isFavorite(track) ? "heart.slash" : "heart"
                )
            }
            Button { showPlaylistDialog = true } label: {
                Label("Добавить в плейлист", systemImage: "music.note.list")
            }
            if let page = track.sourcePageURL {
                Divider()
                ShareLink(item: page) {
                    Label("Открыть страницу источника", systemImage: "safari")
                }
            }
        }
        .confirmationDialog("Добавить в плейлист", isPresented: $showPlaylistDialog, titleVisibility: .visible) {
            ForEach(appState.library.playlists) { playlist in
                Button(playlist.title) { appState.library.addTrack(track, to: playlist.id) }
            }
            Button("Создать новый плейлист") {
                let playlist = appState.library.createPlaylist(title: "Мой плейлист")
                appState.library.addTrack(track, to: playlist.id)
            }
            Button("Отмена", role: .cancel) {}
        }
    }
}

// MARK: - Large track card

struct TrackCard: View {
    @Environment(AppState.self) private var appState
    let track: Track
    var queue: [Track] = []
    var width: CGFloat = 160

    var body: some View {
        Button {
            appState.play(track, in: queue.isEmpty ? [track] : queue)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    ArtworkView(url: track.artworkURL, size: width, cornerRadius: 16)
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)

                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay { Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5) }
                        .padding(10)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(track.artist)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundStyle(Color.volnaTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { appState.player.playNext(track) } label: {
                Label("Следующим", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            Button { appState.player.appendToQueue(track) } label: {
                Label("В очередь", systemImage: "text.badge.plus")
            }
            Button { _ = appState.toggleFavorite(track) } label: {
                Label("В избранное", systemImage: "heart")
            }
        }
    }
}