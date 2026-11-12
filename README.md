# VOLNA 🎵

**Бесплатный музыкальный сервис для iOS**

VOLNA — это нативное приложение для iPhone, которое объединяет музыку из различных открытых источников в единый удобный интерфейс. Без рекламы, без подписок, без цензуры.

![Platform](https://img.shields.io/badge/platform-iOS%2017.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-в%20разработке-yellow)

---

## ✨ Особенности

- 🎵 **Многоисточниковый поиск** — единый поиск по Jamendo, Internet Archive и другим открытым каталогам
- 🎨 **Современный дизайн** — тёмная тема с фиолетовыми акцентами, вдохновлённая Яндекс Музыкой
- 🔊 **Полноценный плеер** — фоновое воспроизведение, управление с экрана блокировки, очередь
- 📱 **Нативный iOS** — Swift 6 + SwiftUI, без WebView и гибридных решений
- 🆓 **Полностью бесплатно** — никаких подписок, рекламы или платных функций
- 🔒 **Приватность** — всё хранится локально, никаких удалённых серверов или аналитики
- 🌍 **Открытая музыка** — только легальные источники с CC-лицензиями и публичным доменом
- 🇷🇺 **Русский интерфейс** — полная локализация

---

## 🚀 Статус разработки

**Текущая версия:** 0.1.0 (В разработке)

### Завершено ✅
- [x] Архитектура проекта
- [x] Доменные модели (Track, Album, Artist, Playlist)
- [x] Протокол MusicProvider
- [x] ProviderRegistry
- [x] Jamendo Provider (базовая реализация)

### В работе 🔨
- [ ] Internet Archive Provider
- [ ] SearchService с мультипровайдерным поиском
- [ ] PlayerService (AVPlayer + фоновое воспроизведение)
- [ ] LibraryService (избранное, плейлисты, история)
- [ ] Базовые UI экраны

### Планируется 📋
- [ ] LRCLIB интеграция (тексты песен)
- [ ] MusicBrainz интеграция (метаданные)
- [ ] Navidrome provider (опционально)
- [ ] Кэширование обложек
- [ ] Локальные рекомендации
- [ ] GitHub Actions CI/CD

---

## 📦 Требования

- **iOS:** 17.0+
- **Xcode:** 16.0+
- **Swift:** 6.0
- **macOS:** для разработки требуется macOS с Xcode

---

## 🛠 Сборка проекта

### Установка зависимостей

1. Установите [XcodeGen](https://github.com/yonaskolb/XcodeGen):
```bash
brew install xcodegen
```

2. Клонируйте репозиторий:
```bash
git clone https://github.com/yourusername/VOLNA.git
cd VOLNA
```

3. Сгенерируйте Xcode проект:
```bash
xcodegen generate
```

4. Откройте проект:
```bash
open VOLNA.xcodeproj
```

### Конфигурация

1. В Xcode выберите target `VOLNA`
2. В разделе **Signing & Capabilities** выберите свою команду разработчика
3. Замените `com.volna.app` на свой Bundle Identifier при необходимости

### API ключи

Для работы с некоторыми провайдерами требуются API ключи:

**Jamendo:**
1. Зарегистрируйтесь на [developer.jamendo.com](https://developer.jamendo.com)
2. Создайте приложение и получите Client ID
3. Замените `YOUR_CLIENT_ID` в `JamendoProvider.swift` на ваш ключ

> ⚠️ **Безопасность:** В production версии API ключи должны храниться в безопасном хранилище или конфигурационном файле, не включённом в репозиторий.

### Запуск

1. Выберите симулятор или подключённый iPhone
2. Нажмите **⌘R** или кнопку Run
3. Приложение запустится на выбранном устройстве

---

## 🏗 Архитектура

VOLNA использует модульную архитектуру с чёткимразделением ответственности:

```
VOLNA/
├── App/              # Точка входа, AppState
├── Domain/           # Модели данных (Track, Album, Artist)
├── Providers/        # Музыкальные провайдеры (Jamendo, Archive.org, etc.)
├── Services/         # Бизнес-логика (Player, Search, Library)
├── Features/         # Модули функций (Home, Search, Player, Library)
├── DesignSystem/     # UI компоненты, цвета, типографика
└── Resources/        # Ассеты, локализация
```

### Ключевые принципы

- **Swift Concurrency:** Все сетевые операции и тяжёлые вычисления асинхронны
- **Actor изоляция:** Провайдеры и сервисы используют actors для thread-safety
- **Protocol-oriented:** Провайдеры реализуют общий протокол `MusicProvider`
- **Нет базы данных:** Всё хранится в JSON файлах и UserDefaults
- **SwiftUI + Observation:** Современный подход к UI и состоянию

---

## 🎵 Музыкальные источники

### Текущие провайдеры

#### 1. **Jamendo** ✅
- **Статус:** Реализован
- **Каталог:** 500,000+ треков Creative Commons
- **API:** https://developer.jamendo.com
- **Лицензия:** CC (Free for non-commercial use)

#### 2. **Internet Archive** 🔨
- **Статус:** В разработке
- **Каталог:** 13M+ аудиозаписей
- **API:** https://archive.org/developers
- **Лицензия:** Varies (много публичного домена)

### Планируемые провайдеры

#### 3. **LRCLIB** (Тексты песен) 📋
- **Синхронизированные тексты**
- **API:** https://lrclib.net
- **Без API ключа**

#### 4. **MusicBrainz** (Метаданные) 📋
- **Обогащение метаданных**
- **API:** https://musicbrainz.org/ws/2
- **Открытая энциклопедия музыки**

#### 5. **Navidrome** (Опционально) 📋
- **Личная библиотека пользователя**
- **Self-hosted сервер**
- **OpenSubsonic API**

---

## 📱 Экраны приложения

- **🏠 Главная** — Персональные рекомендации, недавно прослушанное, популярное
- **🔍 Поиск** — Объединённый поиск по всем источникам с дедупликацией
- **🎵 Медиатека** — Избранное, плейлисты, альбомы, исполнители, история
- **⚙️ Настройки** — Источники, качество, кэш, информация о приложении
- **🎛 Плеер** — Мини-плеер и полноэкранный плеер с обложками и управлением

---

## 🤝 Вклад в проект

Проект находится на ранней стадии разработки. Вклады приветствуются!

### Как внести вклад

1. Fork репозитория
2. Создайте feature branch (`git checkout -b feature/amazing-feature`)
3. Commit изменений (`git commit -m 'Add amazing feature'`)
4. Push в branch (`git push origin feature/amazing-feature`)
5. Откройте Pull Request

### Области для помощи

- 🎨 **Дизайн:** App Icon, UI/UX улучшения
- 🎵 **Провайдеры:** Новые музыкальные источники
- 🧪 **Тестирование:** Unit tests, UI tests
- 📝 **Документация:** Улучшение документации, переводы
- 🐛 **Баг-фиксы:** Исправление найденных проблем

---

## 📄 Лицензия

Этот проект распространяется под лицензией **MIT**. См. файл [LICENSE](LICENSE) для подробностей.

### Зависимости

- **AudioStreaming** (MIT) — https://github.com/dimitris-c/AudioStreaming

Полный список зависимостей и их лицензий см. в [THIRD_PARTY_LICENSES.md](Documentation/THIRD_PARTY_LICENSES.md)

---

## 🔗 Ссылки

- **Документация:** [Documentation/](Documentation/)
- **Архитектура:** [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md)
- **Исследование:** [Documentation/RESEARCH.md](Documentation/RESEARCH.md)
- **Провайдеры:** [Documentation/PROVIDERS.md](Documentation/PROVIDERS.md)

---

## ⚖️ Юридическая информация

VOLNA использует только легальные источники музыки:
- Creative Commons лицензированную музыку
- Публичный домен
- Открытые API с разрешённым доступом

Приложение:
- ❌ НЕ обходит DRM или защиту контента
- ❌ НЕ нарушает авторские права
- ❌ НЕ использует пиратский контент
- ✅ Уважает условия использования всех API
- ✅ Отображает информацию о лицензиях

---

## 📞 Контакты

- **Issues:** [GitHub Issues](https://github.com/yourusername/VOLNA/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/VOLNA/discussions)

---

**VOLNA** — *Музыка без границ* 🌊🎵

---

*Сделано с ❤️ для любителей свободной музыки*
