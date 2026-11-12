import SwiftUI

/// Управление пользовательскими прямыми ссылками на аудио.
/// Ссылка проверяется по HTTPS, HTTP-статусу, Content-Type, редиректам и
/// поддержке Range-запросов. HTML и веб-страницы не принимаются.
struct DirectLinksView: View {
    @Environment(AppState.self) private var appState

    @State private var isFormVisible = false
    @State private var title = ""
    @State private var artist = ""
    @State private var urlString = ""
    @State private var license: LicenseType = .unknown
    @State private var licenseURLString = ""
    @State private var localError: String?
    @State private var confirmRemoveAll = false
    @State private var addedLink: DirectLink?

    private let licenseOptions: [LicenseType] = [
        .unknown, .cc0, .publicDomain, .ccBy, .ccBySa, .ccByNd,
        .ccByNc, .ccByNcSa, .ccByNcNd, .other
    ]

    private var store: DirectLinkStore { appState.directLinkStore }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                hintCard

                if isFormVisible {
                    formCard
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFormVisible = true
                        }
                    } label: {
                        Label("Добавить прямую ссылку", systemImage: "plus")
                    }
                    .buttonStyle(VolnaPrimaryButtonStyle())
                }

                if let error = localError ?? store.lastError {
                    ErrorBanner(message: error) {
                        localError = nil
                    }
                }

                if store.links.isEmpty {
                    EmptyStateView(
                        icon: "link.badge.plus",
                        title: "Прямых ссылок нет",
                        message: "Добавьте HTTPS-ссылку на MP3, AAC, M4A, WAV, FLAC или HLS. VOLNA проверит ответ сервера перед сохранением.",
                        actionTitle: "Добавить ссылку"
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFormVisible = true
                        }
                    }
                } else {
                    SectionHeader(
                        title: "Сохранённые ссылки",
                        subtitle: "\(store.links.count) шт. · хранятся только на iPhone"
                    )

                    VStack(spacing: 0) {
                        ForEach(store.links) { link in
                            linkRow(link)
                            if link.id != store.links.last?.id {
                                Divider()
                                    .overlay(Color.white.opacity(0.05))
                                    .padding(.leading, 54)
                            }
                        }
                    }
                    .volnaCard(cornerRadius: 20, padding: 8)

                    Button(role: .destructive) {
                        confirmRemoveAll = true
                    } label: {
                        Label("Удалить все ссылки", systemImage: "trash")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.volnaError)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, VolnaLayout.horizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .volnaScreenLayout()
        .navigationTitle("Прямые ссылки")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .confirmationDialog(
            "Удалить все прямые ссылки?",
            isPresented: $confirmRemoveAll,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                Task { await appState.removeAllDirectLinks() }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Будут удалены только записи из этого списка. Аудиофайлы на серверах не затрагиваются.")
        }
        .alert(
            "Ссылка добавлена",
            isPresented: Binding(
                get: { addedLink != nil },
                set: { if !$0 { addedLink = nil } }
            )
        ) {
            Button("OK", role: .cancel) { addedLink = nil }
        } message: {
            if let addedLink {
                Text("«\(addedLink.title)» проверена и сохранена. Формат: \(addedLink.format.displayName).")
            }
        }
    }

    // MARK: - Header / hint

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Свои ссылки")
                .font(.volnaDisplay(28))
                .foregroundStyle(Color.volnaTextPrimary)
            Text("Локальный источник для аудио, которое вы имеете право слушать. VOLNA не скачивает файл целиком и не хранит его копию.")
                .font(.volnaBody(12))
                .foregroundStyle(Color.volnaTextSecondary)
                .lineSpacing(3)
        }
    }

    private var hintCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.volnaMint)
                Text("Что проверяется")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaTextPrimary)
            }
            Text("Схема HTTPS, финальный URL после редиректов, HTTP 200/206, Content-Type, поддержка Range и формат, совместимый с AVPlayer. HTML, JSON и текстовые страницы отклоняются.")
                .font(.volnaBody(10))
                .foregroundStyle(Color.volnaTextTertiary)
                .lineSpacing(2)
            Text("Лицензию указываете вы. «Неизвестна» остаётся неизвестной и не считается свободной лицензией.")
                .font(.volnaBody(10))
                .foregroundStyle(Color.volnaTextTertiary)
                .lineSpacing(2)
        }
        .padding(13)
        .background(Color.volnaCyan.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Новая ссылка")
                    .font(.volnaHeadline(16))
                    .foregroundStyle(Color.volnaTextPrimary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFormVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.volnaTextTertiary)
                }
                .buttonStyle(.plain)
            }

            fieldLabel("Название *")
            TextField("Например, Ночная волна", text: $title)
                .textFieldStyle(.plain)
                .padding(11)
                .background(Color.white.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .foregroundStyle(Color.volnaTextPrimary)

            fieldLabel("Исполнитель")
            TextField("Необязательно", text: $artist)
                .textFieldStyle(.plain)
                .padding(11)
                .background(Color.white.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .foregroundStyle(Color.volnaTextPrimary)

            fieldLabel("HTTPS-ссылка на аудио *")
            TextField("https://example.com/audio.mp3", text: $urlString)
                .textFieldStyle(.plain)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(11)
                .background(Color.white.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .foregroundStyle(Color.volnaTextPrimary)

            fieldLabel("Лицензия")
            Picker("Лицензия", selection: $license) {
                ForEach(licenseOptions, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.volnaPurple)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            if license.requiresAttribution && license.isKnownOpenLicense {
                Text("Для этой лицензии требуется указание автора и источника. Добавьте атрибуцию в описание трека или на странице источника.")
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.volnaWarning)
                    .lineSpacing(2)
            }

            fieldLabel("Ссылка на лицензию")
            TextField(defaultLicenseURLHint, text: $licenseURLString)
                .textFieldStyle(.plain)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(11)
                .background(Color.white.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .foregroundStyle(Color.volnaTextPrimary)

            Button {
                Task { await add() }
            } label: {
                HStack(spacing: 8) {
                    if store.isAdding {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.7)
                    }
                    Text(store.isAdding ? "Проверяем ссылку…" : "Проверить и сохранить")
                }
            }
            .buttonStyle(VolnaPrimaryButtonStyle())
            .disabled(store.isAdding)
            .opacity(store.isAdding ? 0.7 : 1)
        }
        .volnaCard(cornerRadius: 20, padding: 15)
    }

    private var defaultLicenseURLHint: String {
        if let url = LicenseParser.defaultURL(for: license) {
            return url.absoluteString
        }
        return "Необязательно, если лицензия неизвестна"
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.volnaTextSecondary)
    }

    // MARK: - Link row

    private func linkRow(_ link: DirectLink) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.volnaCyan.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "waveform")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.volnaCyan)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(link.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(link.artist)
                        .lineLimit(1)
                    Text("·")
                    Text(link.format.displayName)
                    Text("·")
                    Text(link.license.shortDisplayName)
                }
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(Color.volnaTextTertiary)
                Text(link.url.host ?? link.url.absoluteString)
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.volnaTextTertiary.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button {
                appState.play(link.track, in: [link.track])
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.volnaAccentGradient)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button {
                Task { await appState.removeDirectLink(id: link.id) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .frame(width: 28, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 5)
        .contextMenu {
            Button {
                appState.play(link.track, in: [link.track])
            } label: {
                Label("Слушать", systemImage: "play.fill")
            }
            if let licenseURL = link.licenseURL {
                Link(destination: licenseURL) {
                    Label("Открыть лицензию", systemImage: "doc.text")
                }
            }
            ShareLink(item: link.url) {
                Label("Поделиться ссылкой", systemImage: "square.and.arrow.up")
            }
            Divider()
            Button(role: .destructive) {
                Task { await appState.removeDirectLink(id: link.id) }
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    // MARK: - Add

    private func add() async {
        localError = nil

        let cleanURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            localError = "Укажите название композиции"
            return
        }
        guard let url = URL(string: cleanURL),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false else {
            localError = "Введите корректную HTTPS-ссылку на аудио"
            return
        }

        let resolvedLicenseURL: URL?
        let cleanLicenseURL = licenseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanLicenseURL.isEmpty {
            resolvedLicenseURL = LicenseParser.defaultURL(for: license)
        } else if let url = URL(string: cleanLicenseURL),
                  url.scheme?.lowercased() == "https" {
            resolvedLicenseURL = url
        } else {
            localError = "Ссылка на лицензию должна начинаться с https://"
            return
        }

        let link = await appState.addDirectLink(
            title: title,
            artist: artist,
            url: url.absoluteString,
            license: license,
            licenseURL: resolvedLicenseURL
        )

        guard let link else {
            localError = store.lastError ?? "Не удалось проверить ссылку"
            return
        }

        title = ""
        artist = ""
        urlString = ""
        license = .unknown
        licenseURLString = ""
        isFormVisible = false
        addedLink = link
    }
}

#Preview {
    NavigationStack {
        DirectLinksView()
            .environment(AppState())
    }
}
