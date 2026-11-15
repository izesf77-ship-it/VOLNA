import SwiftUI

struct RadioView: View {
    @Environment(AppState.self) private var appState

    private var radio: RadioService { appState.radio }
    private var favoriteStations: [RadioStation] { appState.radioFavorites.stations }
    private var topCountries: [RadioCountry] { Array(radio.countries.prefix(10)) }
    private var featuredGenres: [RadioGenreOption] { Array(RadioGenreCatalog.all.prefix(10)) }
    /// Сохранённые станции видны всегда. Пустую карточку избранного прячем
    /// только на самой первой загрузке, чтобы она не мигала перед витриной.
    private var showsFavorites: Bool {
        !favoriteStations.isEmpty || !(radio.isFeedLoading && radio.popular.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: VolnaLayout.sectionSpacing) {
                    header
                        .padding(.top, 6)
                    searchLink

                    if let error = radio.feedError, radio.popular.isEmpty {
                        ErrorBanner(message: error) {
                            Task { await radio.loadFeedIfNeeded(force: true) }
                        }
                    }

                    if radio.isFeedLoading && radio.popular.isEmpty {
                        RadioLoadingView(message: "Настраиваем приёмники…")
                    } else if radio.popular.isEmpty {
                        if radio.feedError == nil {
                            emptyState
                        }
                    } else {
                        popularSection
                    }

                    // Избранное не зависит от каталога: сохранённые станции
                    // должны быть доступны даже при ошибке сети или пустом фиде.
                    if showsFavorites {
                        favoritesSection
                    }

                    if !radio.popular.isEmpty {
                        if !radio.russian.isEmpty {
                            russianSection
                        }
                        countriesSection
                        genresSection
                        if !radio.international.isEmpty {
                            internationalSection
                        }
                        if !radio.newStations.isEmpty {
                            newStationsSection
                        }
                        sourceFooter
                    }
                }
                .padding(.horizontal, VolnaLayout.horizontalPadding)
                .padding(.bottom, 24)
            }
            .volnaScreenLayout()
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await radio.loadFeedIfNeeded(force: true)
                await radio.loadDirectoryIfNeeded(force: true)
            }
            .task {
                async let feed: Void = radio.loadFeedIfNeeded()
                async let directory: Void = radio.loadDirectoryIfNeeded()
                _ = await (feed, directory)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ScreenHeader(
            title: "Радио",
            subtitle: "Прямые эфиры со всего мира: музыка, новости и разговорные станции.",
            eyebrow: "VOLNA · LIVE"
        )
    }

    private var searchLink: some View {
        NavigationLink {
            RadioSearchView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.volnaTextSecondary)

                Text("Название станции")
                    .font(VolnaFont.custom(15, weight: .regular, relativeTo: .subheadline))
                    .foregroundStyle(Color.volnaTextTertiary)

                Spacer(minLength: 8)

                Text("Найти")
                    .font(VolnaFont.custom(13, weight: .semibold, relativeTo: .footnote))
                    .foregroundStyle(Color.volnaPurple)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.volnaSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Поиск радиостанций")
    }

    // MARK: - Sections

    private var popularSection: some View {
        stationShelf(
            title: "Популярные станции",
            subtitle: "Слушают чаще всего",
            stations: radio.popular,
            destination: RadioStationListView(
                title: "Популярные станции",
                subtitle: "Самые слушаемые станции Radio Browser",
                query: .popular(limit: 40)
            )
        )
    }

    private var russianSection: some View {
        stationShelf(
            title: "Русскоязычные",
            subtitle: "Эфиры на русском языке",
            stations: radio.russian,
            destination: RadioStationListView(
                title: "Русскоязычные станции",
                subtitle: "Радиостанции с языком вещания «русский»",
                query: .russian(limit: 40)
            )
        )
    }

    private var internationalSection: some View {
        stationShelf(
            title: "Международные",
            subtitle: "Музыка и голос без границ",
            stations: radio.international,
            destination: RadioStationListView(
                title: "Международные станции",
                subtitle: "Эфиры из разных стран мира",
                query: .international(limit: 80),
                internationalOnly: true
            )
        )
    }

    private var newStationsSection: some View {
        stationShelf(
            title: "Новые станции",
            subtitle: "Недавно появились в каталоге",
            stations: radio.newStations,
            destination: RadioStationListView(
                title: "Новые станции",
                subtitle: "Недавно добавленные или обновлённые эфиры",
                query: .newStations(limit: 40)
            )
        )
    }

    private func stationShelf<Destination: View>(
        title: String,
        subtitle: String,
        stations: [RadioStation],
        destination: Destination
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            RadioShelfHeader(title: title, subtitle: subtitle) {
                destination
            }

            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(stations.prefix(12))) { station in
                        RadioStationCard(station: station, width: 152)
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 20)
            }
            .scrollClipDisabled()
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Избранные станции")
                        .font(VolnaFont.custom(22, weight: .semibold, relativeTo: .title2))
                        .foregroundStyle(Color.volnaTextPrimary)
                    Text("Сохраняются на этом iPhone")
                        .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                Spacer(minLength: 8)
                if !favoriteStations.isEmpty {
                    NavigationLink {
                        RadioFavoritesView()
                    } label: {
                        Text("Все")
                            .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                            .foregroundStyle(Color.volnaPurple)
                    }
                }
            }

            if favoriteStations.isEmpty {
                favoritesEmptyCard
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(Array(favoriteStations.prefix(12))) { station in
                            RadioStationCard(station: station, width: 152)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.trailing, 20)
                }
                .scrollClipDisabled()
            }
        }
    }

    private var favoritesEmptyCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "heart")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.volnaMagenta)
                .frame(width: 42, height: 42)
                .background(Color.volnaMagenta.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Пока пусто")
                    .font(VolnaFont.custom(15, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Color.volnaTextPrimary)
                Text("Нажмите сердечко у станции — она останется здесь после перезапуска.")
                    .font(VolnaFont.custom(12, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .volnaCard(cornerRadius: 18, padding: 0)
    }

    private var countriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            RadioShelfHeader(
                title: "Страны",
                subtitle: "Радио по всему миру",
                actionTitle: "Все страны"
            ) {
                RadioCountriesView()
            }

            if radio.countries.isEmpty {
                if radio.isDirectoryLoading {
                    RadioLoadingView(message: "Загружаем страны…")
                } else if let error = radio.directoryError {
                    ErrorBanner(message: error) {
                        Task { await radio.loadDirectoryIfNeeded(force: true) }
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    LazyHStack(spacing: 10) {
                        ForEach(topCountries) { country in
                            NavigationLink {
                                RadioStationListView(
                                    title: country.displayName,
                                    subtitle: "\(country.stationCount) станций · Radio Browser",
                                    query: .country(country.code)
                                )
                            } label: {
                                RadioCountryTile(country: country)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.trailing, 20)
                }
                .scrollClipDisabled()
            }
        }
    }

    private var genresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            RadioShelfHeader(
                title: "Жанры",
                subtitle: "От джаза до электроники",
                actionTitle: "Все жанры"
            ) {
                RadioGenresView()
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(featuredGenres) { option in
                    NavigationLink {
                        RadioStationListView(
                            title: option.title,
                            subtitle: "Жанр · \(option.id)",
                            query: .genre(option.id)
                        )
                    } label: {
                        RadioGenreTile(
                            option: option,
                            stationCount: RadioGenreCatalog.stationCount(for: option.id, in: radio.genres)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sourceFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.volnaAmber)
                Text("Каталог Radio Browser")
                    .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Color.volnaTextPrimary)
            }
            Text("VOLNA не хранит аудиопотоки: станции воспроизводятся напрямую из открытого каталога Radio Browser. Доступность эфира зависит от вещателя.")
                .font(VolnaFont.custom(12, weight: .regular, relativeTo: .caption))
                .foregroundStyle(Color.volnaTextSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .volnaCard(cornerRadius: 18, padding: 14)
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "dot.radiowaves.left.and.right",
            title: "Радио пока недоступно",
            message: "Не удалось получить станции. Проверьте соединение и попробуйте ещё раз — VOLNA не подставляет демо-эфиры.",
            actionTitle: "Повторить"
        ) {
            Task { await radio.loadFeedIfNeeded(force: true) }
        }
    }
}

// MARK: - Shelf header

private struct RadioShelfHeader<Destination: View>: View {
    let title: String
    let subtitle: String
    var actionTitle = "Все"
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(VolnaFont.custom(22, weight: .semibold, relativeTo: .title2))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            NavigationLink {
                destination()
            } label: {
                Text(actionTitle)
                    .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Color.volnaPurple)
            }
        }
    }
}

#Preview {
    RadioView()
        .environment(AppState())
}
