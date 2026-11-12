import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var confirmReset = false
    @State private var showClearedCache = false

    private var settings: SettingsStore { appState.settings }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    sourcesCard
                    behaviorCard
                    directLinksCard
                    dataCard
                    aboutCard
                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 148)
            }
            .background(VolnaBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "sources": SourcesView()
                case "direct": DirectLinksView()
                case "licenses": LicensesView()
                default: EmptyView()
                }
            }
            .alert("Кэш очищен", isPresented: $showClearedCache) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Кэшированные обложки и ответы API удалены. Медиатека не затронута.")
            }
            .confirmationDialog(
                "Сбросить настройки?",
                isPresented: $confirmReset,
                titleVisibility: .visible
            ) {
                Button("Сбросить", role: .destructive) {
                    settings.resetToDefaults()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Будут включены все источники и восстановлены настройки по умолчанию. Медиатека останется на месте.")
            }
        }
    }

    private var header: some View {
        ScreenHeader(
            title: "Настройки",
            subtitle: "Без аккаунта, рекламы и облака",
            eyebrow: "VOLNA \(appState.appVersion)"
        )
    }

    private var sourcesCard: some View {
        VStack(spacing: 2) {
            NavigationLink(value: "sources") {
                SettingsNavigationRow(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Музыкальные источники",
                    subtitle: "\(settings.enabledProviderIDs.count) из \(MusicSourceCatalog.all.count) включено",
                    tint: .volnaPurple
                )
            }
            .buttonStyle(.plain)

            Divider().overlay(Color.white.opacity(0.05)).padding(.leading, 44)

            ForEach(MusicSourceCatalog.all) { source in
                HStack(spacing: 10) {
                    Circle()
                        .fill(providerColor(source.id))
                        .frame(width: 6, height: 6)
                    Text(source.name)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.volnaTextSecondary)
                    Spacer()
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { settings.isProviderEnabled(source.id) },
                            set: { settings.setProvider(source.id, enabled: $0) }
                        )
                    )
                    .labelsHidden()
                    .tint(Color.volnaPurple)
                    .scaleEffect(0.82)
                }
                .padding(.vertical, 3)
            }
        }
        .volnaCard(cornerRadius: 20, padding: 14)
    }

    private var behaviorCard: some View {
        VStack(spacing: 12) {
            SettingsToggleRow(
                icon: "character.book.closed",
                title: "Приоритет русской музыки",
                subtitle: "Поднимать русскоязычные записи в результатах",
                isOn: Binding(
                    get: { settings.preferRussianMusic },
                    set: { settings.preferRussianMusic = $0 }
                ),
                tint: .volnaMagenta
            )

            Divider().overlay(Color.white.opacity(0.05))

            SettingsToggleRow(
                icon: "checkmark.seal",
                title: "Показывать лицензии",
                subtitle: "Бейдж лицензии рядом с каждым треком",
                isOn: Binding(
                    get: { settings.showLicenseBadges },
                    set: { settings.showLicenseBadges = $0 }
                ),
                tint: .volnaMint
            )

            Divider().overlay(Color.white.opacity(0.05))

            SettingsToggleRow(
                icon: "eye",
                title: "Показывать пометку explicit",
                subtitle: "VOLNA не скрывает композиции — это только отображение метки",
                isOn: Binding(
                    get: { settings.showExplicitContent },
                    set: { settings.showExplicitContent = $0 }
                ),
                tint: .volnaBlue
            )
        }
        .volnaCard(cornerRadius: 20, padding: 14)
    }

    private var directLinksCard: some View {
        NavigationLink(value: "direct") {
            SettingsNavigationRow(
                icon: "link",
                title: "Прямые ссылки",
                subtitle: "\(appState.directLinkStore.links.count) добавлено · MP3, M4A, AAC, FLAC, HLS",
                tint: .volnaCyan
            )
        }
        .buttonStyle(.plain)
        .volnaCard(cornerRadius: 20, padding: 14)
    }

    private var dataCard: some View {
        VStack(spacing: 2) {
            SettingsValueRow(
                icon: "heart",
                title: "Избранное",
                value: "\(appState.library.favorites.count)",
                tint: .volnaMagenta
            )
            Divider().overlay(Color.white.opacity(0.05)).padding(.leading, 44)
            SettingsValueRow(
                icon: "music.note.list",
                title: "Плейлисты",
                value: "\(appState.library.playlists.count)",
                tint: .volnaPurple
            )
            Divider().overlay(Color.white.opacity(0.05)).padding(.leading, 44)
            SettingsValueRow(
                icon: "clock",
                title: "История",
                value: "\(appState.library.history.count)",
                tint: .volnaBlue
            )
            Divider().overlay(Color.white.opacity(0.05)).padding(.leading, 44)

            Button {
                URLCache.shared.removeAllCachedResponses()
                showClearedCache = true
            } label: {
                SettingsNavigationRow(
                    icon: "trash",
                    title: "Очистить кэш",
                    subtitle: "Обложки и ответы API",
                    tint: .volnaAmber,
                    showChevron: false
                )
            }
            .buttonStyle(.plain)

            Divider().overlay(Color.white.opacity(0.05)).padding(.leading, 44)

            Button {
                confirmReset = true
            } label: {
                SettingsNavigationRow(
                    icon: "arrow.counterclockwise",
                    title: "Сбросить настройки",
                    subtitle: "Медиатека останется на устройстве",
                    tint: .volnaError,
                    showChevron: false
                )
            }
            .buttonStyle(.plain)
        }
        .volnaCard(cornerRadius: 20, padding: 14)
    }

    private var aboutCard: some View {
        VStack(spacing: 2) {
            NavigationLink(value: "licenses") {
                SettingsNavigationRow(
                    icon: "doc.text",
                    title: "Лицензии и данные",
                    subtitle: "Как VOLNA определяет права на музыку",
                    tint: .volnaMint
                )
            }
            .buttonStyle(.plain)

            Divider().overlay(Color.white.opacity(0.05)).padding(.leading, 44)

            Link(destination: URL(string: "https://github.com/izesf77-ship-it/VOLNA")!) {
                SettingsNavigationRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "Исходный код",
                    subtitle: "github.com/izesf77-ship-it/VOLNA",
                    tint: .volnaTextSecondary
                )
            }

            Divider().overlay(Color.white.opacity(0.05)).padding(.leading, 44)

            SettingsValueRow(
                icon: "info.circle",
                title: "Версия",
                value: appState.appVersion,
                tint: .volnaTextSecondary
            )
        }
        .volnaCard(cornerRadius: 20, padding: 14)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("VOLNA — бесплатный плеер открытой музыки")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.volnaTextSecondary)
            Text("Ни рекламы, ни подписок, ни обязательной регистрации. Все настройки и медиатека хранятся на iPhone.")
                .font(.volnaBody(10))
                .foregroundStyle(Color.volnaTextTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func providerColor(_ id: String) -> Color {
        switch id {
        case "jamendo": return .volnaMint
        case "internet_archive": return .volnaBlue
        case "wikimedia_commons": return .volnaAmber
        case "openverse": return .volnaMagenta
        case "direct": return .volnaCyan
        default: return .volnaTextTertiary
        }
    }
}

// MARK: - Rows

struct SettingsNavigationRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = .volnaPurple
    var showChevron = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaTextPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.volnaTextTertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.volnaTextTertiary)
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}

struct SettingsValueRow: View {
    let icon: String
    let title: String
    let value: String
    var tint: Color = .volnaPurple

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.volnaTextPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.volnaTextTertiary)
        }
        .padding(.vertical, 7)
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var tint: Color = .volnaPurple

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaTextPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.volnaTextTertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(tint)
                .scaleEffect(0.82)
        }
        .padding(.vertical, 5)
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
