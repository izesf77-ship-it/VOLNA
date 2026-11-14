import SwiftUI

// MARK: - Station card

struct RadioStationCard: View {
    @Environment(AppState.self) private var appState

    let station: RadioStation
    var width: CGFloat = 156

    private var isCurrent: Bool {
        appState.player.mode == .radio && appState.player.radioStation?.id == station.id
    }

    private var isPlaying: Bool {
        isCurrent && appState.player.isPlaying
    }

    private var detail: String {
        if isCurrent, let metadata = appState.player.radioMetadata {
            return metadata.displayText
        }
        if !station.locationText.isEmpty {
            return station.locationText
        }
        return station.primaryGenre ?? "Прямой эфир"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button(action: play) {
                ZStack(alignment: .bottomLeading) {
                    ArtworkView(
                        url: station.favicon,
                        size: width,
                        cornerRadius: 18,
                        showProgress: false,
                        placeholderIcon: "dot.radiowaves.left.and.right"
                    )

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.62)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    HStack(alignment: .bottom) {
                        if isCurrent {
                            RadioLiveBadge(isPlaying: isPlaying)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 32, height: 32)
                            .background(.white, in: Circle())
                            .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
                    }
                    .padding(9)
                }
                .frame(width: width, height: width)
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Пауза, \(station.displayName)" : "Слушать \(station.displayName)")

            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(station.displayName)
                        .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(isCurrent ? Color.volnaPurple : Color.volnaTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(detail)
                        .font(VolnaFont.custom(12, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(Color.volnaTextSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    appState.radioFavorites.toggle(station)
                } label: {
                    Image(systemName: appState.radioFavorites.isFavorite(station) ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            appState.radioFavorites.isFavorite(station)
                                ? Color.volnaMagenta
                                : Color.volnaTextTertiary
                        )
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    appState.radioFavorites.isFavorite(station)
                        ? "Убрать \(station.displayName) из избранного"
                        : "Добавить \(station.displayName) в избранное"
                )
            }
        }
        .frame(width: width, alignment: .leading)
        .contextMenu {
            Button(action: play) {
                Label(isPlaying ? "Пауза" : "Слушать", systemImage: isPlaying ? "pause.fill" : "play.fill")
            }
            Button {
                appState.radioFavorites.toggle(station)
            } label: {
                Label(
                    appState.radioFavorites.isFavorite(station) ? "Убрать из избранного" : "В избранное",
                    systemImage: appState.radioFavorites.isFavorite(station) ? "heart.slash" : "heart"
                )
            }
            if let homepage = station.homepage {
                ShareLink(item: homepage) {
                    Label("Ссылка на станцию", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private func play() {
        if isCurrent {
            appState.player.togglePlayPause()
        } else {
            appState.playRadio(station)
        }
    }
}

// MARK: - Station row

struct RadioStationRow: View {
    @Environment(AppState.self) private var appState

    let station: RadioStation
    var showsFavorite = true

    private var isCurrent: Bool {
        appState.player.mode == .radio && appState.player.radioStation?.id == station.id
    }

    private var isPlaying: Bool {
        isCurrent && appState.player.isPlaying
    }

    private var detail: String {
        if isCurrent, let metadata = appState.player.radioMetadata {
            return metadata.displayText
        }
        var parts: [String] = []
        if !station.locationText.isEmpty {
            parts.append(station.locationText)
        }
        if let genre = station.genreDisplay {
            parts.append(genre)
        }
        if let quality = station.streamQualityText {
            parts.append(quality)
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: play) {
                HStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        ArtworkView(
                            url: station.favicon,
                            size: 54,
                            cornerRadius: 12,
                            showProgress: false,
                            placeholderIcon: "dot.radiowaves.left.and.right"
                        )
                        if isCurrent {
                            Circle()
                                .fill(isPlaying ? Color.volnaMint : Color.volnaTextTertiary)
                                .frame(width: 9, height: 9)
                                .overlay { Circle().stroke(Color.volnaBackground, lineWidth: 2) }
                                .offset(x: 2, y: 2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(station.displayName)
                            .font(VolnaFont.custom(15, weight: isCurrent ? .semibold : .medium, relativeTo: .subheadline))
                            .foregroundStyle(isCurrent ? Color.volnaPurple : Color.volnaTextPrimary)
                            .lineLimit(1)

                        Text(detail)
                            .font(VolnaFont.custom(12, weight: .regular, relativeTo: .caption))
                            .foregroundStyle(Color.volnaTextSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Пауза, \(station.displayName)" : "Слушать \(station.displayName)")

            if isCurrent {
                Image(systemName: isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.volnaPurple)
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                    .frame(width: 28)
            }

            if showsFavorite {
                Button {
                    appState.radioFavorites.toggle(station)
                } label: {
                    Image(systemName: appState.radioFavorites.isFavorite(station) ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(
                            appState.radioFavorites.isFavorite(station)
                                ? Color.volnaMagenta
                                : Color.volnaTextTertiary
                        )
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    appState.radioFavorites.isFavorite(station)
                        ? "Убрать \(station.displayName) из избранного"
                        : "Добавить \(station.displayName) в избранное"
                )
            }
        }
        .padding(.vertical, 5)
        .contextMenu {
            Button(action: play) {
                Label(isPlaying ? "Пауза" : "Слушать", systemImage: isPlaying ? "pause.fill" : "play.fill")
            }
            Button {
                appState.radioFavorites.toggle(station)
            } label: {
                Label(
                    appState.radioFavorites.isFavorite(station) ? "Убрать из избранного" : "В избранное",
                    systemImage: appState.radioFavorites.isFavorite(station) ? "heart.slash" : "heart"
                )
            }
            if let homepage = station.homepage {
                ShareLink(item: homepage) {
                    Label("Ссылка на станцию", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private func play() {
        if isCurrent {
            appState.player.togglePlayPause()
        } else {
            appState.playRadio(station)
        }
    }
}

// MARK: - Small pieces

struct RadioLiveBadge: View {
    var isPlaying = true

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isPlaying ? Color.volnaMint : Color.volnaTextTertiary)
                .frame(width: 6, height: 6)
            Text(isPlaying ? "LIVE" : "ПАУЗА")
                .font(.system(size: 9, weight: .bold, design: .default))
                .tracking(0.8)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.48), in: Capsule())
        .overlay { Capsule().stroke(.white.opacity(0.14), lineWidth: 1) }
    }
}

struct RadioCountryTile: View {
    let country: RadioCountry
    var width: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(country.flagEmoji ?? "🌍")
                    .font(.system(size: 24))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.volnaTextTertiary)
            }

            Text(country.displayName)
                .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(Color.volnaTextPrimary)
                .lineLimit(1)

            Text("\(country.stationCount) станций")
                .font(VolnaFont.custom(11, weight: .medium, relativeTo: .caption2))
                .foregroundStyle(Color.volnaTextTertiary)
                .lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.volnaSurface.opacity(0.9))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(country.displayName), \(country.stationCount) станций")
    }
}

struct RadioGenreTile: View {
    let option: RadioGenreOption
    let stationCount: Int?

    private var tint: Color {
        switch option.id {
        case "pop": return .volnaMagenta
        case "rock": return .volnaRed
        case "electronic", "dance": return .volnaMint
        case "jazz", "blues": return .volnaAmber
        case "classical": return .volnaBlue
        case "news", "talk": return .volnaCyan
        default: return .volnaPurple
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: option.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(1)
                Text(stationCount.map { "\($0) станций" } ?? "Станции")
                    .font(VolnaFont.custom(11, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.volnaSurface.opacity(0.9))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(option.title)
    }
}

// MARK: - Loading / error helpers

struct RadioLoadingView: View {
    var message = "Загружаем радиостанции…"

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.volnaPurple)
            Text(message)
                .font(VolnaFont.custom(13, weight: .regular, relativeTo: .footnote))
                .foregroundStyle(Color.volnaTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

enum RadioErrorText {
    static func message(for error: Error) -> String {
        if let radioError = error as? RadioAPIError {
            return radioError.localizedDescription
        }
        if error is CancellationError {
            return ""
        }
        return "Не удалось загрузить каталог радио. Проверьте соединение и повторите попытку."
    }
}
