import SwiftUI

/// Полный список релизов редакционного каталога. Все альбомы пришли из
/// открытого API вместе с обложкой, исполнителем и датой релиза.
struct CatalogAlbumsView: View {
    @Environment(AppState.self) private var appState

    let title: String
    var albums: [Album]? = nil

    private var items: [Album] {
        albums ?? appState.catalog.albums
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                if items.isEmpty {
                    EmptyStateView(
                        icon: "square.stack",
                        title: "Релизов пока нет",
                        message: "VOLNA загружает только те релизы, у которых есть обложка, открытая лицензия и доступный аудиопоток.",
                        actionTitle: "Обновить каталог"
                    ) {
                        Task { await appState.catalog.refresh(force: true) }
                    }
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, album in
                            CatalogAlbumRow(album: album)
                            if index < items.count - 1 {
                                Divider()
                                    .overlay(Color.volnaSeparator)
                                    .padding(.leading, 88)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .volnaCard(cornerRadius: 20, padding: 8)
                }
            }
            .padding(.horizontal, VolnaLayout.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .volnaScreenLayout()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .refreshable {
            await appState.catalog.refresh(force: true)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(VolnaFont.custom(30, weight: .bold, relativeTo: .title))
                .foregroundStyle(Color.volnaTextPrimary)
                .lineLimit(2)

            Text(items.isEmpty ? "Открытые релизы каталога" : "\(items.count) релизов · открытые лицензии")
                .font(VolnaFont.custom(14, weight: .regular, relativeTo: .subheadline))
                .foregroundStyle(Color.volnaTextSecondary)
        }
    }
}

private struct CatalogAlbumRow: View {
    let album: Album

    private var metadata: String {
        var parts: [String] = [album.artist]
        if let date = album.releaseDate {
            parts.append(String(Calendar.current.component(.year, from: date)))
        }
        if album.trackCount > 0 {
            parts.append("\(album.trackCount) треков")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationLink(value: album) {
            HStack(spacing: 14) {
                ArtworkView(url: album.artworkURL, size: 64, cornerRadius: 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(album.title)
                        .font(VolnaFont.custom(15, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(metadata)
                        .font(VolnaFont.custom(12, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(Color.volnaTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.volnaTextTertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
