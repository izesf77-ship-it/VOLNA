import SwiftUI

/// Экран музыкальных источников: включение провайдеров, реальная проверка
/// доступности API и честная документация того, что не интегрировано.
struct SourcesView: View {
    @Environment(AppState.self) private var appState

    @State private var health: [String: ProviderHealth] = [:]
    @State private var isChecking = false
    @State private var lastChecked: Date?
    @State private var checkingIDs: Set<String> = []

    private let unintegrated: [UnintegratedSource] = [
        UnintegratedSource(
            name: "ccMixter",
            reason: "Публичный JSON-поиск работает, но аудиофайлы отдают 403 без браузерного Referer. Обход этого ограничения недопустим."
        ),
        UnintegratedSource(
            name: "Free Music Archive",
            reason: "Публичный API закрыт, а условия сайта запрещают прямое hotlink-воспроизведение файлов."
        ),
        UnintegratedSource(
            name: "Musopen",
            reason: "Сайт и API защищены Cloudflare и не предоставляют стабильного публичного интерфейса для сторонних клиентов."
        ),
        UnintegratedSource(
            name: "Muxiv",
            reason: "Каталог заявляет бесплатные треки, но документированного публичного API нет, а robots.txt запрещает /api/."
        ),
        UnintegratedSource(
            name: "OpenGameArt",
            reason: "Открытые аудио CC0/CC-BY есть, но официального API нет. Массовый парсинг HTML не используется."
        ),
        UnintegratedSource(
            name: "SayaMusicAPI / JioSaavn (unofficial)",
            reason: "Проверенные маршруты дают в основном preview/метаданные или зависят от стороннего Worker/условий upstream. Не используется как источник полноценных защищённых стримов."
        ),
        UnintegratedSource(
            name: "Яндекс Музыка",
            reason: "Нет публичного API, разрешающего сторонним плеерам полный стриминг. Закрытые методы требуют OAuth и договора с правообладателями."
        ),
        UnintegratedSource(
            name: "VK Музыка",
            reason: "Публичный Audio API закрыт для новых сторонних клиентов. Полное воспроизведение требует лицензионного соглашения."
        ),
        UnintegratedSource(
            name: "Zaycev.net",
            reason: "У сайта нет публичного API для сторонних плееров, а музыка лицензирована для собственного сервиса."
        ),
        UnintegratedSource(
            name: "SoundCloud",
            reason: "API требует регистрации приложения и разрешения авторов; большая часть треков all rights reserved."
        ),
        UnintegratedSource(
            name: "Deezer",
            reason: "Публичный API отдаёт метаданные и 30-секундные preview; полный поток требует партнёрский/премиум-доступ."
        ),
        UnintegratedSource(
            name: "Apple Music / iTunes",
            reason: "iTunes Search даёт метаданные и preview, Apple Music требует MusicKit, developer token и подписку."
        )
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                policyCard

                SectionHeader(
                    title: "Подключённые источники",
                    subtitle: "Каждый провайдер можно отключить отдельно"
                )

                ForEach(MusicSourceCatalog.all) { source in
                    sourceCard(source)
                }

                healthSummary

                SectionHeader(
                    title: "Не интегрировано",
                    subtitle: "Причины указаны без обхода ограничений"
                )

                VStack(spacing: 2) {
                    ForEach(unintegrated) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.name)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.volnaTextPrimary)
                            Text(item.reason)
                                .font(.volnaBody(11))
                                .foregroundStyle(Color.volnaTextTertiary)
                                .lineSpacing(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 9)
                        if item.id != unintegrated.last?.id {
                            Divider().overlay(Color.white.opacity(0.05))
                        }
                    }
                }
                .volnaCard(cornerRadius: 20, padding: 14)

                Text("VOLNA не использует пиратские каталоги, не обходит DRM, Cloudflare, Referer-проверки и не подменяет User-Agent ради доступа к закрытым файлам.")
                    .font(.volnaBody(10))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .lineSpacing(2)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, VolnaLayout.horizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .volnaScreenLayout()
        .navigationTitle("Музыкальные источники")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .refreshable {
            await checkAll()
        }
        .task {
            if health.isEmpty {
                await checkAll()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Источники")
                .font(.volnaDisplay(28))
                .foregroundStyle(Color.volnaTextPrimary)
            Text("Поиск идёт параллельно по всем включённым каталогам. Если один источник недоступен, остальные продолжают работать.")
                .font(.volnaBody(12))
                .foregroundStyle(Color.volnaTextSecondary)
                .lineSpacing(3)
        }
    }

    private var policyCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.volnaMint)
            VStack(alignment: .leading, spacing: 4) {
                Text("Только официальные API")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaTextPrimary)
                Text("Публичный Client ID Jamendo не является секретом. Лицензия каждой записи читается из ответа источника отдельно.")
                    .font(.volnaBody(10))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .lineSpacing(2)
            }
        }
        .padding(13)
        .background(Color.volnaMint.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Source card

    private func sourceCard(_ source: MusicSourceInfo) -> some View {
        let isEnabled = appState.settings.isProviderEnabled(source.id)
        let status = health[source.id]
        let isCheckingThis = checkingIDs.contains(source.id)

        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: icon(for: source.id))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color(for: source.id))
                    .frame(width: 34, height: 34)
                    .background(color(for: source.id).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(source.name)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.volnaTextPrimary)
                        if source.requiresKey {
                            Text("КЛЮЧ")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.volnaWarning)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.volnaWarning.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text(source.description)
                        .font(.volnaBody(10))
                        .foregroundStyle(Color.volnaTextTertiary)
                        .lineSpacing(2)
                }

                Spacer(minLength: 4)

                Toggle(
                    "",
                    isOn: Binding(
                        get: { appState.settings.isProviderEnabled(source.id) },
                        set: { appState.settings.setProvider(source.id, enabled: $0) }
                    )
                )
                .labelsHidden()
                .tint(Color.volnaPurple)
                .scaleEffect(0.82)
            }

            HStack(spacing: 6) {
                tag("Русский", color: .volnaMagenta)
                tag(source.requiresKey ? "Нужен ключ" : "Без ключа", color: source.requiresKey ? .volnaWarning : .volnaMint)
                if source.id == "direct" {
                    tag("Локально", color: .volnaCyan)
                }
                Spacer(minLength: 0)
            }

            statusRow(
                status: status,
                isChecking: isCheckingThis,
                isEnabled: isEnabled
            ) {
                Task { await check(source.id) }
            }

            Text(source.licenseSummary)
                .font(.volnaBody(10))
                .foregroundStyle(Color.volnaTextTertiary)
                .lineSpacing(2)
            Text(source.rateLimitNote)
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(Color.volnaTextTertiary.opacity(0.9))

            if let website = source.websiteURL {
                Link(destination: website) {
                    HStack(spacing: 5) {
                        Image(systemName: "safari")
                        Text("Открыть сайт источника")
                    }
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaBlue)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.volnaSurface.opacity(0.85))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isEnabled ? Color.white.opacity(0.07) : Color.white.opacity(0.03), lineWidth: 1)
                }
        }
        .opacity(isEnabled ? 1 : 0.62)
    }

    private func statusRow(
        status: ProviderHealth?,
        isChecking: Bool,
        isEnabled: Bool,
        retry: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 7) {
            if isChecking {
                ProgressView()
                    .tint(Color.volnaPurple)
                    .scaleEffect(0.6)
                Text("Проверяем API…")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.volnaTextSecondary)
            } else if let status {
                Circle()
                    .fill(status.isAvailable ? Color.volnaSuccess : Color.volnaError)
                    .frame(width: 6, height: 6)
                Text(status.isAvailable ? "API доступен" : "API недоступен")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(status.isAvailable ? Color.volnaSuccess : Color.volnaError)
                if let latency = status.latencyText {
                    Text("· \(latency)")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                if let message = status.message, !status.isAvailable {
                    Text(message)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.volnaTextTertiary)
                        .lineLimit(1)
                }
            } else {
                Circle()
                    .fill(Color.volnaTextTertiary)
                    .frame(width: 6, height: 6)
                Text(isEnabled ? "Проверка не выполнялась" : "Источник выключен")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.volnaTextTertiary)
            }

            Spacer(minLength: 6)

            Button("Проверить", action: retry)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.volnaPurple)
                .disabled(isChecking)
        }
    }

    private var healthSummary: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.volnaTextTertiary)
            if isChecking {
                Text("Проверяем все источники…")
            } else if let lastChecked {
                Text("Последняя проверка: \(lastChecked.formatted(date: .omitted, time: .shortened))")
            } else {
                Text("Проверка ещё не выполнялась")
            }
            Spacer()
            Button {
                Task { await checkAll() }
            } label: {
                Text(isChecking ? "Проверка…" : "Проверить все")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaPurple)
            }
            .disabled(isChecking)
        }
        .font(.system(size: 10, weight: .regular, design: .rounded))
        .foregroundStyle(Color.volnaTextTertiary)
        .padding(.horizontal, 2)
    }

    private func tag(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 8, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    // MARK: - Health

    private func checkAll() async {
        guard !isChecking else { return }
        isChecking = true
        let result = await appState.checkAllProviders()
        health = result
        lastChecked = Date()
        isChecking = false
    }

    private func check(_ providerID: String) async {
        guard !checkingIDs.contains(providerID),
              let provider = appState.providerRegistry.provider(for: providerID) else {
            return
        }
        checkingIDs.insert(providerID)
        let result = await provider.healthCheck()
        health[providerID] = result
        lastChecked = Date()
        checkingIDs.remove(providerID)
    }

    private func icon(for id: String) -> String {
        switch id {
        case "jamendo": return "waveform"
        case "audius": return "music.note.list"
        case "internet_archive": return "building.columns"
        case "wikimedia_commons": return "globe.europe.africa"
        case "openverse": return "circle.hexagongrid"
        case "direct": return "link"
        default: return "antenna.radiowaves.left.and.right"
        }
    }

    private func color(for id: String) -> Color {
        switch id {
        case "jamendo": return .volnaMint
        case "audius": return .volnaPurple
        case "internet_archive": return .volnaBlue
        case "wikimedia_commons": return .volnaAmber
        case "openverse": return .volnaMagenta
        case "direct": return .volnaCyan
        default: return .volnaTextTertiary
        }
    }
}

private struct UnintegratedSource: Identifiable {
    let name: String
    let reason: String

    var id: String { name }
}

#Preview {
    NavigationStack {
        SourcesView()
            .environment(AppState())
    }
}
