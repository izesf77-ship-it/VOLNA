import SwiftUI

// MARK: - Countries

struct RadioCountriesView: View {
    @Environment(AppState.self) private var appState
    @State private var query = ""

    private var radio: RadioService { appState.radio }
    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var filtered: [RadioCountry] {
        guard !trimmedQuery.isEmpty else { return radio.countries }
        return radio.countries.filter { country in
            country.displayName.localizedCaseInsensitiveContains(trimmedQuery)
                || country.name.localizedCaseInsensitiveContains(trimmedQuery)
                || country.code.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 16) {
                searchField

                if radio.countries.isEmpty {
                    if radio.isDirectoryLoading {
                        RadioLoadingView(message: "Загружаем страны…")
                    } else if let error = radio.directoryError {
                        ErrorBanner(message: error) {
                            Task { await radio.loadDirectoryIfNeeded(force: true) }
                        }
                    }
                } else if filtered.isEmpty {
                    Text("Страна не найдена")
                        .font(VolnaFont.custom(14, weight: .regular, relativeTo: .subheadline))
                        .foregroundStyle(Color.volnaTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, country in
                            NavigationLink {
                                RadioStationListView(
                                    title: country.displayName,
                                    subtitle: "\(country.stationCount) станций · Radio Browser",
                                    query: .country(country.code)
                                )
                            } label: {
                                countryRow(country)
                            }
                            .buttonStyle(.plain)

                            if index < filtered.count - 1 {
                                Divider()
                                    .overlay(Color.volnaSeparator)
                                    .padding(.leading, 48)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .volnaCard(cornerRadius: 20, padding: 8)
                }
            }
            .padding(.horizontal, VolnaLayout.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .volnaScreenLayout()
        .navigationTitle("Страны")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await radio.loadDirectoryIfNeeded()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.volnaTextTertiary)
            TextField("Найти страну", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(VolnaFont.custom(15, weight: .regular, relativeTo: .subheadline))
                .foregroundStyle(Color.volnaTextPrimary)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистить поиск")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.volnaSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                }
        }
    }

    private func countryRow(_ country: RadioCountry) -> some View {
        HStack(spacing: 12) {
            Text(country.flagEmoji ?? "🌍")
                .font(.system(size: 25))
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(country.displayName)
                    .font(VolnaFont.custom(15, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(1)
                Text("\(country.stationCount) станций")
                    .font(VolnaFont.custom(12, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(Color.volnaTextTertiary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.volnaTextTertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(country.displayName), \(country.stationCount) станций")
    }
}

// MARK: - Genres

struct RadioGenresView: View {
    @Environment(AppState.self) private var appState

    private var radio: RadioService { appState.radio }

    var body: some View {
        ScrollView(showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 16) {
                if let error = radio.directoryError, radio.genres.isEmpty {
                    ErrorBanner(message: error) {
                        Task { await radio.loadDirectoryIfNeeded(force: true) }
                    }
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(RadioGenreCatalog.all) { option in
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

                Text("Жанры соответствуют тегам Radio Browser. Если у станции несколько тегов, она может встречаться в нескольких подборках.")
                    .font(VolnaFont.custom(12, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .padding(.horizontal, VolnaLayout.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .volnaScreenLayout()
        .navigationTitle("Жанры")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await radio.loadDirectoryIfNeeded()
        }
    }
}

// MARK: - Favorites

struct RadioFavoritesView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                if appState.radioFavorites.stations.isEmpty {
                    EmptyStateView(
                        icon: "heart",
                        title: "Избранных станций пока нет",
                        message: "Нажмите сердечко у станции — она сохранится на этом iPhone и останется после перезапуска."
                    )
                    .padding(.top, 20)
                } else {
                    header

                    VStack(spacing: 0) {
                        ForEach(Array(appState.radioFavorites.stations.enumerated()), id: \.element.id) { index, station in
                            RadioStationRow(station: station)
                            if index < appState.radioFavorites.stations.count - 1 {
                                Divider()
                                    .overlay(Color.volnaSeparator)
                                    .padding(.leading, 66)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .volnaCard(cornerRadius: 20, padding: 8)
                }
            }
            .padding(.horizontal, VolnaLayout.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .volnaScreenLayout()
        .navigationTitle("Избранное радио")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Избранные станции")
                .font(VolnaFont.custom(28, weight: .bold, relativeTo: .title))
                .foregroundStyle(Color.volnaTextPrimary)
            Text("\(appState.radioFavorites.count) станций · хранятся локально")
                .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                .foregroundStyle(Color.volnaTextTertiary)
        }
    }
}
