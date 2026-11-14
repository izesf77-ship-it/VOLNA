import SwiftUI

/// Список станций по произвольному запросу с постепенной подгрузкой.
/// Используется странами, жанрами и языками. Весь каталог не запрашивается:
/// каждая страница ограничена `RadioStationQuery.limit`.
struct RadioStationListView: View {
    @Environment(AppState.self) private var appState

    let title: String
    let subtitle: String
    let query: RadioStationQuery
    var internationalOnly = false

    @State private var stations: [RadioStation] = []
    @State private var nextOffset: Int?
    @State private var hasMore = false
    @State private var isLoading = false
    @State private var didLoad = false
    @State private var error: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 20) {
                header

                if let error, stations.isEmpty {
                    ErrorBanner(message: error) {
                        Task { await load(reset: true) }
                    }
                }

                if stations.isEmpty {
                    if isLoading {
                        RadioLoadingView()
                    } else if didLoad, hasMore {
                        Button {
                            Task { await loadMoreIfNeeded(force: true) }
                        } label: {
                            Text("Показать ещё")
                                .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                                .foregroundStyle(Color.volnaPurple)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    } else if didLoad, error == nil {
                        EmptyStateView(
                            icon: "dot.radiowaves.left.and.right",
                            title: "Станции не найдены",
                            message: "В этом разделе пока нет доступных станций. Попробуйте другой жанр или страну."
                        )
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(stations.enumerated()), id: \.element.id) { index, station in
                            RadioStationRow(station: station)
                                .onAppear {
                                    guard station.id == stations.last?.id else { return }
                                    Task { await loadMoreIfNeeded() }
                                }
                            if index < stations.count - 1 {
                                Divider()
                                    .overlay(Color.volnaSeparator)
                                    .padding(.leading, 66)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .volnaCard(cornerRadius: 20, padding: 8)

                    paginationFooter
                }
            }
            .padding(.horizontal, VolnaLayout.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .volnaScreenLayout()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await loadIfNeeded()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(VolnaFont.custom(30, weight: .bold, relativeTo: .title))
                .foregroundStyle(Color.volnaTextPrimary)
                .lineLimit(2)

            Text(subtitle)
                .font(VolnaFont.custom(14, weight: .regular, relativeTo: .subheadline))
                .foregroundStyle(Color.volnaTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !stations.isEmpty {
                Text("\(stations.count) станций загружено")
                    .font(VolnaFont.custom(12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(Color.volnaTextTertiary)
            }
        }
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if isLoading {
            HStack(spacing: 10) {
                ProgressView().tint(Color.volnaPurple)
                Text("Загружаем ещё…")
                    .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                    .foregroundStyle(Color.volnaTextTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else if let error {
            ErrorBanner(message: error) {
                Task { await loadMoreIfNeeded(force: true) }
            }
        } else if hasMore {
            Button {
                Task { await loadMoreIfNeeded(force: true) }
            } label: {
                Text("Показать ещё")
                    .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Color.volnaPurple)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Loading

    private func loadIfNeeded() async {
        guard !didLoad else { return }
        await load(reset: true)
    }

    private func loadMoreIfNeeded(force: Bool = false) async {
        guard hasMore, !isLoading else { return }
        if !force {
            // Пагинация запускается по появлению последней строки. Небольшая
            // задержка защищает от лишнего запроса при быстром скролле.
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
        }
        await load(reset: false)
    }

    private func load(reset: Bool) async {
        guard !isLoading else { return }

        var pageQuery = query
        if !reset {
            guard hasMore, let nextOffset else { return }
            pageQuery.offset = nextOffset
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let page = try await appState.radio.stations(for: pageQuery)
            var incoming = page.stations
            if internationalOnly {
                incoming = RadioStationFilter.internationalOnly(incoming)
            }

            if reset {
                stations = incoming
            } else {
                appendUnique(incoming)
            }
            nextOffset = page.nextOffset
            hasMore = page.hasMore
            didLoad = true
        } catch is CancellationError {
            // Экран закрыли или запрос заменили — это не ошибка каталога.
        } catch {
            self.error = RadioErrorText.message(for: error)
        }
    }

    private func appendUnique(_ incoming: [RadioStation]) {
        var seen = Set(stations.map(\.id))
        for station in incoming where seen.insert(station.id).inserted {
            stations.append(station)
        }
    }
}
