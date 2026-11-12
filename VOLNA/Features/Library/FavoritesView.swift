import SwiftUI

struct FavoritesView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if appState.library.favorites.isEmpty {
                    EmptyStateView(
                        icon: "heart",
                        title: "В избранном пусто",
                        message: "Нажмите сердечко рядом с треком в поиске, на главной или в плеере.",
                        actionTitle: "Перейти к поиску"
                    ) {
                        appState.selectedTab = .search
                    }
                } else {
                    header
                    VStack(spacing: 0) {
                        ForEach(appState.library.favorites) { track in
                            TrackRow(track: track, queue: appState.library.favorites)
                            if track.id != appState.library.favorites.last?.id {
                                Divider()
                                    .overlay(Color.white.opacity(0.055))
                                    .padding(.leading, 62)
                            }
                        }
                    }
                    .volnaCard(cornerRadius: 20, padding: 8)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 148)
        }
        .background(VolnaBackground())
        .navigationTitle("Избранное")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.volnaMagenta, Color.volnaPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Избранное")
                        .font(.volnaDisplay(25))
                        .foregroundStyle(Color.volnaTextPrimary)
                    Text("\(appState.library.favorites.count) треков · только на этом iPhone")
                        .font(.volnaBody(12))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                Spacer()
            }

            if let first = appState.library.favorites.first {
                Button {
                    appState.play(first, in: appState.library.favorites)
                } label: {
                    Label("Слушать всё", systemImage: "play.fill")
                }
                .buttonStyle(VolnaPrimaryButtonStyle())
            }
        }
    }
}

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @State private var confirmClear = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if appState.library.history.isEmpty {
                    EmptyStateView(
                        icon: "clock",
                        title: "История пуста",
                        message: "Здесь появятся треки, которые вы слушали. История хранится только на устройстве.",
                        actionTitle: "Перейти к поиску"
                    ) {
                        appState.selectedTab = .search
                    }
                } else {
                    HStack {
                        Text("\(appState.library.history.count) записей")
                            .font(.volnaBody(12))
                            .foregroundStyle(Color.volnaTextTertiary)
                        Spacer()
                        Button("Очистить") {
                            confirmClear = true
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.volnaError)
                    }

                    VStack(spacing: 0) {
                        ForEach(appState.library.history) { track in
                            TrackRow(track: track, queue: appState.library.history)
                            if track.id != appState.library.history.last?.id {
                                Divider()
                                    .overlay(Color.white.opacity(0.055))
                                    .padding(.leading, 62)
                            }
                        }
                    }
                    .volnaCard(cornerRadius: 20, padding: 8)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 148)
        }
        .background(VolnaBackground())
        .navigationTitle("История")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .confirmationDialog(
            "Очистить историю?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Очистить", role: .destructive) {
                appState.library.clearHistory()
            }
            Button("Отмена", role: .cancel) {}
        }
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
            .environment(AppState())
    }
}
