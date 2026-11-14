import SwiftUI

struct RadioSearchView: View {
    @Environment(AppState.self) private var appState

    @State private var query = ""
    @State private var stations: [RadioStation] = []
    @State private var nextOffset: Int?
    @State private var hasMore = false
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var error: String?
    @State private var activeSearchID = UUID()
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    private var radio: RadioService { appState.radio }
    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 16) {
                searchField

                if let error, stations.isEmpty {
                    ErrorBanner(message: error) {
                        submitSearch()
                    }
                }

                if trimmedQuery.isEmpty {
                    prompt
                } else if isLoading && stations.isEmpty {
                    RadioLoadingView(message: "Ищем станции…")
                } else if stations.isEmpty, hasSearched, error == nil {
                    EmptyStateView(
                        icon: "dot.radiowaves.left.and.right",
                        title: "Станции не найдены",
                        message: "Попробуйте другое название. Поиск идёт по именам станций в каталоге Radio Browser."
                    )
                } else if !stations.isEmpty {
                    resultHeader
                    stationList
                    paginationFooter
                }
            }
            .padding(.horizontal, VolnaLayout.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .volnaScreenLayout()
        .navigationTitle("Поиск радио")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onChange(of: query) { _, newValue in
            scheduleSearch(newValue)
        }
        .onSubmit {
            submitSearch()
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.volnaTextTertiary)

            TextField("Название станции", text: $query)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .font(VolnaFont.custom(15, weight: .regular, relativeTo: .subheadline))
                .foregroundStyle(Color.volnaTextPrimary)

            if !query.isEmpty {
                Button {
                    query = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистить поиск")
            }

            if isFocused {
                Button("Найти") {
                    submitSearch()
                }
                .font(VolnaFont.custom(13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(Color.volnaPurple)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.volnaSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isFocused ? Color.volnaPurple.opacity(0.55) : Color.white.opacity(0.07),
                            lineWidth: 1
                        )
                }
        }
    }

    // MARK: - Results

    private var prompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.volnaPurple)
            Text("Найдите свою волну")
                .font(VolnaFont.custom(20, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(Color.volnaTextPrimary)
            Text("Введите название станции. Например: Europa, Jazz FM или Radio Record.")
                .font(VolnaFont.custom(14, weight: .regular, relativeTo: .subheadline))
                .foregroundStyle(Color.volnaTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var resultHeader: some View {
        HStack {
            Text("Результаты")
                .font(VolnaFont.custom(20, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(Color.volnaTextPrimary)
            Spacer()
            Text("\(stations.count) станций")
                .font(VolnaFont.custom(12, weight: .medium, relativeTo: .caption))
                .foregroundStyle(Color.volnaTextTertiary)
        }
    }

    private var stationList: some View {
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

    // MARK: - Actions

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            activeSearchID = UUID()
            stations = []
            nextOffset = nil
            hasMore = false
            hasSearched = false
            isLoading = false
            error = nil
            return
        }

        let id = UUID()
        activeSearchID = id
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(reset: true, id: id)
        }
    }

    private func submitSearch() {
        searchTask?.cancel()
        let trimmed = trimmedQuery
        guard !trimmed.isEmpty else { return }
        isFocused = false
        let id = UUID()
        activeSearchID = id
        Task {
            await performSearch(reset: true, id: id)
        }
    }

    private func performSearch(reset: Bool, id: UUID) async {
        let text = trimmedQuery
        guard !text.isEmpty, activeSearchID == id else { return }

        var query = RadioStationQuery.search(text, limit: 30)
        if !reset {
            guard hasMore, let nextOffset else { return }
            query.offset = nextOffset
        }

        isLoading = true
        error = nil
        defer {
            if activeSearchID == id {
                isLoading = false
            }
        }

        do {
            let page = try await radio.stations(for: query)
            guard activeSearchID == id, trimmedQuery == text else { return }
            if reset {
                stations = page.stations
                hasSearched = true
            } else {
                appendUnique(page.stations)
            }
            nextOffset = page.nextOffset
            hasMore = page.hasMore
        } catch is CancellationError {
            // Запрос заменён новым — результат не нужен.
        } catch {
            guard activeSearchID == id, trimmedQuery == text else { return }
            if reset {
                stations = []
                hasSearched = true
            }
            self.error = RadioErrorText.message(for: error)
        }
    }

    private func loadMoreIfNeeded(force: Bool = false) async {
        guard hasMore, !isLoading else { return }
        if !force {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
        }
        await performSearch(reset: false, id: activeSearchID)
    }

    private func appendUnique(_ incoming: [RadioStation]) {
        var seen = Set(stations.map(\.id))
        for station in incoming where seen.insert(station.id).inserted {
            stations.append(station)
        }
    }
}
