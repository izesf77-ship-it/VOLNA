import SwiftUI

/// Полный список исполнителей, найденных в открытом каталоге. Имя и обложка
/// берутся из реальных релизов; портретов, которых нет в API, VOLNA не рисует.
struct CatalogArtistsView: View {
    @Environment(AppState.self) private var appState

    let title: String
    var artists: [Artist]? = nil

    private var items: [Artist] {
        artists ?? appState.catalog.artists
    }

    private var trackCounts: [String: Int] {
        Dictionary(grouping: appState.catalog.tracks, by: { CatalogQuality.artistKey($0.artist) })
            .mapValues(\.count)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                if items.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: "Исполнителей пока нет",
                        message: "Каталог обновляется из открытых релизов с подтверждённой лицензией.",
                        actionTitle: "Обновить каталог"
                    ) {
                        Task { await appState.catalog.refresh(force: true) }
                    }
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, artist in
                            CatalogArtistRow(
                                artist: artist,
                                trackCount: trackCounts[CatalogQuality.artistKey(artist.name)] ?? 0
                            )
                            if index < items.count - 1 {
                                Divider()
                                    .overlay(Color.volnaSeparator)
                                    .padding(.leading, 82)
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

            Text(items.isEmpty ? "Открытые исполнители каталога" : "\(items.count) исполнителей · открытые релизы")
                .font(VolnaFont.custom(14, weight: .regular, relativeTo: .subheadline))
                .foregroundStyle(Color.volnaTextSecondary)
        }
    }
}

private struct CatalogArtistRow: View {
    let artist: Artist
    let trackCount: Int

    var body: some View {
        NavigationLink(value: artist) {
            HStack(spacing: 14) {
                ArtworkView(url: artist.artworkURL, size: 58, cornerRadius: 29)

                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.name)
                        .font(VolnaFont.custom(15, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(trackCount > 0 ? "\(trackCount) треков в каталоге" : "Открытый исполнитель")
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
