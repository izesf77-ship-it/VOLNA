import SwiftUI

struct CatalogTracksView: View {
    @Environment(AppState.self) private var appState

    let title: String
    let subtitle: String
    let tracks: [Track]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                if tracks.isEmpty {
                    EmptyStateView(
                        icon: "music.note.list",
                        title: "Здесь пока пусто",
                        message: "В этой подборке нет треков с подтверждённой лицензией и доступным потоком."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            TrackRow(track: track, queue: tracks)
                            if index < tracks.count - 1 {
                                Divider()
                                    .overlay(Color.volnaSeparator)
                                    .padding(.leading, 68)
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(VolnaFont.custom(30, weight: .bold, relativeTo: .title))
                .foregroundStyle(Color.volnaTextPrimary)
                .lineLimit(2)

            Text(subtitle)
                .font(VolnaFont.custom(14, weight: .regular, relativeTo: .subheadline))
                .foregroundStyle(Color.volnaTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button {
                    guard let first = tracks.first else { return }
                    appState.play(first, in: tracks)
                    appState.showPlayer()
                } label: {
                    Label("Слушать", systemImage: "play.fill")
                }
                .buttonStyle(VolnaPrimaryButtonStyle())

                Text("\(tracks.count) треков")
                    .font(VolnaFont.custom(13, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(Color.volnaTextTertiary)
            }
            .padding(.top, 2)
        }
    }
}
