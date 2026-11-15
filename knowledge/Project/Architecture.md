# Architecture

**Паттерн:** MVVM + Services  
**Фреймворки:** SwiftUI, AVFoundation, MediaPlayer  
**Минимум:** iOS 17.0  
**Язык:** Swift 5.0  

---

## 🏗️ Структура проекта

```
VOLNA/
├── App/
│   ├── VOLNAApp.swift           — точка входа
│   └── AppState.swift           — глобальное состояние
│
├── Services/
│   ├── PlayerService.swift      — AVPlayer, воспроизведение
│   ├── RadioService.swift       — управление радио
│   ├── RadioAPIClient.swift     — API клиент Radio Browser
│   └── Providers/               — провайдеры музыки
│       ├── JamendoProvider.swift
│       ├── InternetArchiveProvider.swift
│       └── ...
│
├── Models/
│   ├── Track.swift              — модель композиции
│   ├── RadioStation.swift       — модель радиостанции
│   ├── Album.swift
│   └── Playlist.swift
│
├── Features/
│   ├── Home/                    — главный экран
│   ├── Search/                  — поиск
│   ├── Player/                  — плееры
│   ├── Radio/                   — радио
│   ├── Library/                 — медиатека
│   ├── Track/                   — детали композиции
│   └── Settings/                — настройки
│
└── DesignSystem/
    ├── Components.swift         — переиспользуемые компоненты
    ├── VolnaFont.swift          — типографика
    ├── Colors.swift             — цветовая палитра
    └── Layout.swift             — константы отступов
```

---

## 🎵 AppState — Центральное состояние

```swift
@Observable
final class AppState {
    var player: PlayerService
    var radio: RadioService
    var library: LibraryService
    var radioFavorites: RadioFavorites
    var providerRegistry: ProviderRegistry
    
    // Navigation state
    var isPlayerPresented: Bool
    var selectedTab: Tab
    
    // ... и т.д.
}
```

**Особенности:**
- Один экземпляр на всё приложение
- Использует `@Observable` (iOS 17+)
- Инжектится через `.environment()`
- Не использует Combine Publishers

---

## 🎧 [[PlayerService]] — Единый плеер

**Ответственность:**
- Воспроизведение музыки и радио
- Управление очередью
- Now Playing Info Center
- Remote Command Center
- AVAudioSession

**Ключевые особенности:**
- **Один AVPlayer** для музыки И радио
- **Два режима:** `.music` и `.radio`
- **MusicResumeSnapshot** — возврат к музыке из радио
- **Не использует две аудиосессии одновременно**

**Файл:** `VOLNA/Services/PlayerService.swift`

### Режимы:
```swift
enum PlaybackMode {
    case music  // AVPlayerItem с треком
    case radio  // AVPlayerItem с HTTP Live Stream
}
```

### Ключевые методы:
```swift
func play(_ track: Track, in queue: [Track])
func playRadio(_ station: RadioStation)
func returnToMusic()  // восстановление музыки из snapshot
func togglePlayPause()
```

---

## 📻 [[RadioService]] — Управление радио

**Ответственность:**
- Поиск станций через Radio Browser API
- Кеширование результатов
- История воспроизведения
- Навигация между станциями одной страны

**Файл:** `VOLNA/Services/RadioService.swift`

### Новые методы (с `652910e`):
```swift
func playNextStationInCountry(player: PlayerService) async
func playPreviousStationInCountry(player: PlayerService) async
func playRandomStationInCountry(player: PlayerService) async
```

**Принцип работы:**
1. Получает текущую станцию из [[PlayerService]]
2. Запрашивает станции той же страны
3. Фильтрует по `isPlayable` и истории
4. Переключает через `player.playRadio()`

---

## 🌐 [[RadioAPIClient]] — HTTP клиент

**API:** https://de1.api.radio-browser.info  
**Документация:** https://api.radio-browser.info

**Endpoints:**
```swift
/json/stations/search           — поиск станций
/json/stations/bycountrycode    — по коду страны
/json/stations/bytag            — по тегу
/json/stations/byuuid/{uuid}    — по ID
/json/stations/topclick         — популярные
```

**Особенности:**
- Асинхронные методы через async/await
- Автоматический retry при ошибках
- Обработка unavailable серверов
- Кеширование запросов

**Файл:** `VOLNA/Services/RadioAPIClient.swift`

---

## 🎵 Music Providers

**Интерфейс:** `MusicProvider` protocol

```swift
protocol MusicProvider {
    var id: String { get }
    var name: String { get }
    
    func search(query: String, type: SearchType) async throws -> SearchResults
    func getTrackStreamURL(_ trackId: String) async throws -> URL
    func getAlbum(_ albumId: String) async throws -> Album
    // ...
}
```

### Провайдеры:
1. **JamendoProvider** — основной каталог
2. **InternetArchiveProvider** — архивные записи
3. **CommunityCatalogsProvider** — кастомные каталоги

**Реестр:** `ProviderRegistry` в AppState

---

## 📱 Навигация

**Структура:**
```swift
NavigationStack {
    TabView {
        HomeView()
        SearchView()
        RadioView()
        LibraryView()
    }
}
.navigationDestination(for: Track.self) { TrackDetailView(track: $0) }
.navigationDestination(for: Album.self) { AlbumView(album: $0) }
.sheet(isPresented: $appState.isPlayerPresented) { PlayerView() }
```

**Особенности:**
- SwiftUI NavigationStack (iOS 16+)
- Type-safe navigation через `.navigationDestination(for:)`
- Модальные окна через `.sheet()` и `.fullScreenCover()`

---

## 🎨 Design System

### Компоненты:
- `ArtworkView` — обложки с placeholder
- `TrackRow` — строка трека
- `SectionHeader` — заголовок секции
- `ProviderBadge` — бейдж провайдера
- `SourceDetailRow` — строка детальной информации
- `RadioStationCard` — карточка радиостанции

### Типографика:
```swift
VolnaFont.custom(size, weight: .semibold, relativeTo: .headline)
```

### Цвета:
```swift
Color.volnaPurple      // основной акцент
Color.volnaBackground  // фон
Color.volnaTextPrimary // основной текст
Color.volnaSurface     // карточки
```

---

## 🔧 Сборка

**XcodeGen:** `project.yml`

```yaml
targets:
  VOLNA:
    type: application
    platform: iOS
    sources:
      - path: VOLNA
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.volna.app
      SWIFT_VERSION: "5.0"
```

**Команды:**
```bash
xcodegen generate          # генерация .xcodeproj
xcodebuild build           # сборка
xcodebuild test            # тесты
xcodebuild archive         # архив для IPA
```

---

## 🔗 Связи между компонентами

```
VOLNAApp
  └── AppState
       ├── PlayerService ←→ RadioService
       ├── LibraryService
       ├── ProviderRegistry
       │    ├── JamendoProvider
       │    ├── InternetArchiveProvider
       │    └── ...
       └── RadioService
            └── RadioAPIClient
```

**Важно:**
- [[PlayerService]] и [[RadioService]] взаимодействуют через AppState
- RadioService передаёт player: PlayerService в async методы
- Провайдеры изолированы и не зависят друг от друга

---

## 🔗 Связанные заметки

- [[PlayerService]] — детали плеера
- [[RadioService]] — детали радио
- [[RadioAPIClient]] — API клиент
- [[Music Player]] — функциональность плеера
- [[Radio]] — функциональность радио
- [[Track]] — модель композиции
- [[Navigation]] — навигация приложения

---

*Эта заметка описывает высокоуровневую архитектуру. Для деталей реализации см. отдельные компоненты.*
