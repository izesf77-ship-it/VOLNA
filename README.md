# VOLNA 🎵

**Нативный iPhone-плеер открытой музыки. Без рекламы, подписок и обязательной регистрации.**

VOLNA ищет музыку в легальных открытых каталогах, объединяет результаты в один список и воспроизводит их через AVPlayer. Приложение написано на SwiftUI для iOS 17+, не использует WebView и не является обёрткой над сайтом.

![Platform](https://img.shields.io/badge/platform-iOS%2017.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5%20language%20mode-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-1.0.0-yellow)

---

## Что умеет приложение

- **Поиск по нескольким источникам одновременно** — Jamendo, Internet Archive, Wikimedia Commons, Openverse и собственные прямые ссылки. Ошибка одного каталога не ломает выдачу остальных.
- **Русскоязычный приоритет** — кириллические запросы, транслитерация, фильтры языка и жанра, подъём русскоязычных записей в ранжировании.
- **Настоящее воспроизведение** — AVPlayer, play/pause, следующий/предыдущий трек, seek, очередь, перемешивание, повтор, фоновое аудио, экран блокировки и Control Center.
- **Восстановление состояния** — текущий трек, очередь и позиция сохраняются между запусками.
- **Медиатека без базы данных** — избранное, плейлисты и история лежат в JSON-файлах на устройстве.
- **Тексты песен** — LRCLIB, синхронные LRC-строки с подсветкой текущей строки.
- **Лицензии на уровне трека** — тип лицензии, ссылка, атрибуция и отдельные разрешения на поток и скачивание. Неизвестная лицензия остаётся `UNKNOWN` и не выдаётся за свободную.
- **Прямые ссылки** — пользователь может добавить HTTPS-ссылку на MP3/AAC/M4A/WAV/FLAC/HLS. Перед сохранением проверяются HTTP-статус, Content-Type, редиректы, Range-запросы и доступность; HTML вместо аудио не принимается.
- **Русский интерфейс по умолчанию**, тёмная тема, iPhone-only.

---

## Источники музыки

| Источник | Поиск | Поток | Лицензии | Примечание |
|---|---|---|---|---|
| Jamendo | ✅ | ✅ | по каждому треку | Публичный Client ID, без секрета |
| Internet Archive | ✅ | ✅ | только элементы с `licenseurl` | MP3/M4A, метаданные на элемент |
| Wikimedia Commons | ✅ | ✅ | из `extmetadata` | OGG/Opus через официальную MP3-транскодию |
| Openverse | ✅ | ✅ | CC/PD | Дополнительный агрегатор, анонимный лимит |
| Прямые ссылки | ✅ | ✅ | указывает пользователь | Локальный источник, проверка по HTTP |

Подробный статус, включая источники, которые **не** интегрированы и почему: [Documentation/PROVIDER_STATUS.md](Documentation/PROVIDER_STATUS.md).

### Почему не все каталоги подключены

VOLNA использует только официально доступные API и не обходит защиту, Cloudflare, Referer-проверки или запреты robots.txt. ccMixter, Audius, Musopen, Free Music Archive, Muxiv и OpenGameArt задокументированы как неподключённые — с причинами, а не имитацией работы. См. [Documentation/PROVIDER_STATUS.md](Documentation/PROVIDER_STATUS.md).

---

## Честный статус

- Код приложения, тесты и CI-конфигурация подготовлены.
- **Сборка и 26 unit-тестов зелёные в GitHub Actions** на `macos-latest` (XcodeGen, iOS Simulator).
- **Локальной сборки на Windows не было.**
- **Проверка на физическом iPhone не выполнялась.** Фоновое воспроизведение, экран блокировки и прерывания реализованы через стандартные API, но требуют проверки на устройстве.
- Неподписанная IPA собирается автоматически, но не устанавливается сама по себе: нужна ваша подпись (AltStore, Sideloadly, Xcode) и ваша учётная запись Apple.
- Если в репозитории нет сертификата и provisioning profile, workflow собирает **неподписанную** IPA и честно называет её `VOLNA-unsigned.ipa`.

Текущий аудит проекта: [Documentation/AUDIT.md](Documentation/AUDIT.md).

---

## Сборка

Требования: macOS, Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/izesf77-ship-it/VOLNA.git
cd VOLNA
xcodegen generate
open VOLNA.xcodeproj
```

В Xcode выберите свою команду разработчика в **Signing & Capabilities**. Bundle ID по умолчанию — `com.volna.app`.

Сборка из терминала:

```bash
xcodebuild \
  -project VOLNA.xcodeproj \
  -scheme VOLNA \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

Тесты:

```bash
xcodebuild test \
  -project VOLNA.xcodeproj \
  -scheme VOLNA \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Подробно, включая unsigned IPA и signing secrets: [Documentation/BUILD.md](Documentation/BUILD.md).

### API-ключи

Секреты не требуются. Jamendo работает через публичный Client ID `b488b912`, который предназначен для клиентских приложений. **Client Secret Jamendo в проекте отсутствует и в IPA не попадает.** У Internet Archive, Wikimedia Commons, Openverse и LRCLIB ключей нет.

---

## Архитектура

```
VOLNA/
├── App/              # Точка входа, AppState, RootView
├── Domain/           # Track, Album, Artist, Playlist, License, Language
├── Providers/        # Jamendo, Internet Archive, Wikimedia, Openverse, Direct
├── Services/         # Search, Player, Library, Lyrics, Settings, DirectLinks
├── Features/         # Home, Search, Artist, Album, Playlist, Player, Library, Settings
├── DesignSystem/     # Цвета, компоненты, типографика
└── Resources/        # Info.plist, Assets.xcassets
```

- SwiftUI + Observation, iOS 17+.
- Провайдеры — `actor` с общим протоколом `MusicProvider`.
- Сеть — `URLSession`; аудио — только `AVPlayer`.
- Хранение — JSON в Documents и UserDefaults. **Нет** SQLite/Core Data/SwiftData/Realm и облачных баз.
- Нет сторонних Swift-пакетов и SPM-зависимостей.
- Swift 5 language mode, минимальная строгая конкурентность.

---

## Приватность

- Нет аккаунтов, аналитики, трекинга и рекламы.
- Поисковые запросы уходят только выбранным музыкальным каталогам.
- Избранное, плейлисты, история и прямые ссылки хранятся локально.
- Приложение не содержит серверной части и не собирает пользовательские данные.

---

## Лицензии и правовая часть

VOLNA не обходит DRM, не использует пиратские источники и не выдаёт неизвестные лицензии за свободные. Для каждого трека показываются доступные сведения о лицензии и атрибуции. Ответственность за соблюдение условий конкретной лицензии (в том числе некоммерческое использование и указание автора) лежит на пользователе.

Код проекта распространяется под MIT. См. [LICENSE](LICENSE).

---

## Документация

- [Сборка и CI](Documentation/BUILD.md)
- [Статус источников](Documentation/PROVIDER_STATUS.md)
- [Аудит проекта](Documentation/AUDIT.md)
- [Русскоязычный поиск](Documentation/RUSSIAN_CATALOG.md)

---

**VOLNA** — музыка без границ 🌊
