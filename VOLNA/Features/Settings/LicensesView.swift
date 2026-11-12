import SwiftUI

/// Экран о лицензиях: объясняет, как VOLNA определяет права на каждую запись,
/// чем отличается поток от скачивания и почему неизвестная лицензия не
/// считается свободной.
struct LicensesView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                principleCard
                streamVsDownloadCard
                providerCard
                ccCard
                attributionCard
                linksCard
            }
            .padding(.horizontal, VolnaLayout.horizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .volnaScreenLayout()
        .navigationTitle("Лицензии и данные")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Права на музыку")
                .font(.volnaDisplay(27))
                .foregroundStyle(Color.volnaTextPrimary)
            Text("VOLNA — плеер, а не хранилище. Аудио остаётся на серверах источников, а лицензия читается для каждой записи отдельно.")
                .font(.volnaBody(12))
                .foregroundStyle(Color.volnaTextSecondary)
                .lineSpacing(3)
        }
    }

    private var principleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.volnaMint)
                Text("Одна запись — одна лицензия")
                    .font(.volnaHeadline(15))
                    .foregroundStyle(Color.volnaTextPrimary)
            }
            Text("VOLNA не назначает единую лицензию всему каталогу. Jamendo отдаёт license_ccurl и audiodownload_allowed для каждого трека, Internet Archive — licenseurl элемента, Wikimedia Commons — extmetadata файла, Openverse — поля license и license_url.")
                .font(.volnaBody(11))
                .foregroundStyle(Color.volnaTextSecondary)
                .lineSpacing(3)
            Text("Если источник не вернул лицензию, VOLNA показывает «Лицензия неизвестна» и не считает такую запись свободной.")
                .font(.volnaBody(11))
                .foregroundStyle(Color.volnaWarning)
                .lineSpacing(3)
        }
        .volnaCard(cornerRadius: 20, padding: 15)
    }

    private var streamVsDownloadCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Поток и скачивание — разные права")
                .font(.volnaHeadline(15))
                .foregroundStyle(Color.volnaTextPrimary)
            evidenceRow(
                icon: "waveform",
                color: .volnaBlue,
                title: "Поток",
                text: "Разрешение на воспроизведение в приложении. Даже открытая лицензия может разрешать поток, но запрещать скачивание файла."
            )
            evidenceRow(
                icon: "arrow.down.circle",
                color: .volnaMint,
                title: "Скачивание",
                text: "Показывается только там, где источник явно разрешает загрузку. VOLNA не обходит это ограничение и не сохраняет копию без разрешения."
            )
        }
        .volnaCard(cornerRadius: 20, padding: 15)
    }

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Что делает каждый источник")
                .font(.volnaHeadline(15))
                .foregroundStyle(Color.volnaTextPrimary)
            evidenceRow(
                icon: "waveform",
                color: .volnaMint,
                title: "Jamendo",
                text: "Лицензия и разрешение на скачивание берутся из ответа API для конкретного трека. Публичный Client ID не даёт доступа к закрытым данным."
            )
            evidenceRow(
                icon: "building.columns",
                color: .volnaBlue,
                title: "Internet Archive",
                text: "В поиск попадают только элементы с явно указанным licenseurl. Элементы без лицензии исключаются, а не помечаются «public domain» автоматически."
            )
            evidenceRow(
                icon: "globe.europe.africa",
                color: .volnaAmber,
                title: "Wikimedia Commons",
                text: "Лицензия и авторство читаются из extmetadata. Для OGG/Opus используется официальная MP3-транскодия Wikimedia, чтобы запись мог играть AVPlayer."
            )
            evidenceRow(
                icon: "circle.hexagongrid",
                color: .volnaMagenta,
                title: "Openverse",
                text: "Агрегатор CC-аудио. VOLNA оставляет только записи с известной открытой лицензией и прямой HTTPS-ссылкой; источник FMA исключён из выдачи."
            )
            evidenceRow(
                icon: "link",
                color: .volnaCyan,
                title: "Прямые ссылки",
                text: "Лицензию указывает пользователь. Приложение проверяет только техническую доступность файла и не подтверждает права на него."
            )
        }
        .volnaCard(cornerRadius: 20, padding: 15)
    }

    private var ccCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Лицензии Creative Commons")
                .font(.volnaHeadline(15))
                .foregroundStyle(Color.volnaTextPrimary)
            Text("Каждая лицензия состоит из условий. VOLNA показывает короткое имя, а решение о допустимом использовании остаётся за вами.")
                .font(.volnaBody(11))
                .foregroundStyle(Color.volnaTextSecondary)
                .lineSpacing(2)

            VStack(spacing: 6) {
                licenseRow("CC0", "Максимальная свобода: можно использовать без указания авторства.")
                licenseRow("CC BY", "Требуется указание автора.")
                licenseRow("CC BY-SA", "Указание автора и распространение производных под той же лицензией.")
                licenseRow("CC BY-ND", "Указание автора; производные запрещены.")
                licenseRow("CC BY-NC", "Только некоммерческое использование, с указанием автора.")
                licenseRow("CC BY-NC-SA", "Некоммерческое использование, указание автора, та же лицензия для производных.")
                licenseRow("CC BY-NC-ND", "Только некоммерческое использование без производных, с указанием автора.")
                licenseRow("Public Domain", "Произведение в общественном достоянии.")
            }
        }
        .volnaCard(cornerRadius: 20, padding: 15)
    }

    private var attributionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.volnaPurple)
                Text("Атрибуция")
                    .font(.volnaHeadline(15))
                    .foregroundStyle(Color.volnaTextPrimary)
            }
            Text("Для лицензий CC BY и производных VOLNA показывает автора, источник и лицензию в карточке трека и на экране плеера. Если вы используете запись за пределами приложения, сохраните эту информацию.")
                .font(.volnaBody(11))
                .foregroundStyle(Color.volnaTextSecondary)
                .lineSpacing(3)
        }
        .volnaCard(cornerRadius: 20, padding: 15)
    }

    private var linksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Полезные ссылки")
                .font(.volnaHeadline(15))
                .foregroundStyle(Color.volnaTextPrimary)
            link("Тексты лицензий Creative Commons", "https://creativecommons.org/licenses/")
            link("Jamendo", "https://www.jamendo.com/")
            link("Internet Archive", "https://archive.org/details/audio")
            link("Wikimedia Commons", "https://commons.wikimedia.org/")
            link("Openverse", "https://openverse.org/")
            link("Исходный код VOLNA", "https://github.com/izesf77-ship-it/VOLNA")
            Text("VOLNA не хранит музыку, не продаёт её и не выдаёт неизвестные лицензии за свободные. Приложение распространяется по лицензии MIT.")
                .font(.volnaBody(10))
                .foregroundStyle(Color.volnaTextTertiary)
                .lineSpacing(2)
                .padding(.top, 4)
        }
        .volnaCard(cornerRadius: 20, padding: 15)
    }

    // MARK: - Helpers

    private func evidenceRow(
        icon: String,
        color: Color,
        title: String,
        text: String
    ) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.11))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaTextPrimary)
                Text(text)
                    .font(.volnaBody(10))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .lineSpacing(2)
            }
        }
    }

    private func licenseRow(_ name: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(name)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.volnaBlue)
                .frame(width: 72, alignment: .leading)
            Text(text)
                .font(.volnaBody(10))
                .foregroundStyle(Color.volnaTextTertiary)
                .lineSpacing(2)
        }
    }

    private func link(_ title: String, _ urlString: String) -> some View {
        Group {
            if let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Spacer()
                    }
                    .foregroundStyle(Color.volnaBlue)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LicensesView()
    }
}
