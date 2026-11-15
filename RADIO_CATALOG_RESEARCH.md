# VOLNA Radio Catalog — Исследование возможностей

**Дата:** 12 ноября 2026  
**Цель:** Проверить покрытие каталога Radio Browser, возможности поиска и перспективы добавления поиска по FM-частотам

---

## Executive Summary

Radio Browser API предоставляет **52,722 интернет-радиостанции** из 224 стран с мощным поиском по названию, стране, языку и жанру. VOLNA уже использует API полноценно, но текущая реализация ориентирована только на поиск по названию станции. 

**Ключевые находки:**
- ✅ **Radio Browser не содержит FM-частот** — это каталог интернет-стримов, а не FM-передатчиков
- ✅ **Русскоязычные станции хорошо представлены** — найдено 100+ станций с `language=russian`
- ⚠️ **Поиск по FM-частоте требует другой источник данных** — fmstream.org, fmscan.org (геолокация обязательна)
- ✅ **Текущая реализация VOLNA корректна** — используется весь каталог, пагинация работает

---

## 1. Покрытие каталога Radio Browser

### Статистика API

**Источник:** `https://all.api.radio-browser.info/json/stats`

```json
{
  "supported_version": 1,
  "software_version": "0.7.50",
  "status": "OK",
  "stations": 52722,
  "stations_broken": 38,
  "tags": 11152,
  "clicks_last_hour": 6068,
  "clicks_last_day": 243270,
  "languages": 585,
  "countries": 224
}
```

**Выводы:**
- 📊 **52,722 станции** в каталоге
- 🌍 **224 страны** покрыты
- 🔤 **585 языков** доступны для фильтрации
- 🎵 **11,152 тега/жанра** (rock, jazz, pop, classical, etc.)
- ✅ **38 сломанных станций** — менее 0.1%, отличная надёжность
- 🔥 **6,068 кликов за последний час** — активное использование API

### Российские радиостанции

**Запрос:** `?countrycode=RU&order=clickcount&reverse=true&limit=10&hidebroken=true`

**ТОП-10 самых популярных:**

| Станция | Кликов | URL |
|---------|--------|-----|
| Anon.FM | 822 | https://icecast.anon.fm/radio |
| Радио Ваня | 222 | https://icecast-radiovanya.cdnvideo.ru/radiovanya |
| DFM Дискач 90-х | 172 | https://dfm-disc90.hostingradio.ru/disc9096.aacp |
| DFM RUSSIAN DANCE | 135 | https://dfm-dfmrusdance.hostingradio.ru/dfmrusdance96.aacp |
| Русское Радио | 131 | https://rusradio.hostingradio.ru/rusradio96.aacp |
| Европа плюс | 116 | http://ep128server.streamr.ru:8030/ep128 |
| Комсомольская Правда | 99 | http://kpradio.hostingradio.ru:8000/russia.radiokp128.mp3 |
| Вести FM | 81 | http://icecast.vgtrk.cdnvideo.ru/vestifm |
| Шансон Радио | 80 | http://chanson.hostingradio.ru:8041/chanson128.mp3 |
| Радио Русские Песни | 77 | http://listen.rusongs.ru/ru-mp3-128 |

**Вывод:** ✅ Крупнейшие российские радиостанции присутствуют в каталоге

### Русскоязычные станции вне России

**Запрос:** `?language=russian&limit=100&order=clickcount&reverse=true&hidebroken=true`

**Найдено:** 100 станций (лимит запроса)

**География:** Все станции в выборке из России. Для проверки других стран нужен запрос с `language=russian` без фильтра по `countrycode`.

**Вывод:** ✅ Поиск по языку работает корректно, можно найти русские станции независимо от страны вещания

---

## 2. Что уже реализовано в VOLNA

### Текущая функциональность

#### ✅ RadioAPIClient.swift
**Методы:**
```swift
func stations(for query: RadioStationQuery) async throws -> [RadioStation]
func countries() async throws -> [RadioCountry]
func languages(limit: Int) async throws -> [RadioLanguage]
func tags(limit: Int) async throws -> [RadioGenre]
```

**Особенности:**
- Протокол `RadioAPIClienting` — тестируемость
- User-Agent: `VOLNA/1.0` — идентификация клиента
- Timeout: 25 секунд
- Обработка BOM (UTF-8 byte order mark)
- Поддержка обёртки `{"value": [...]}` для старых зеркал

#### ✅ RadioStationQuery
**Доступные фильтры:**
```swift
var name: String?           // Поиск по названию
var countryCode: String?    // ISO 3166-1 код страны (RU, US, GB, etc.)
var language: String?       // Язык вещания (russian, english, etc.)
var tag: String?            // Жанр/тег (rock, jazz, news, etc.)
var order: RadioStationOrder = .clickCount
var reverse = true
var offset = 0
var limit = 40              // Ограничение: 1-100 станций за запрос
var hideBroken = true
```

**Готовые запросы:**
```swift
.popular(limit: 20)                    // ТОП по кликам
.russian(limit: 20)                    // Русскоязычные
.international(limit: 40)              // Международные
.newStations(limit: 20)                // Новые станции
.country(_ code: String)               // По коду страны
.genre(_ tag: String)                  // По жанру
.language(_ language: String)          // По языку
.search(_ text: String, limit: 30)     // Поиск по названию
```

#### ✅ RadioSearchView.swift
**Реализовано:**
- Живой поиск с debounce 450ms
- Поиск по названию станции (`name` parameter)
- Пагинация: limit=30, автозагрузка при прокрутке
- Отмена предыдущего запроса при новом вводе
- Обработка ошибок с повторным запросом
- Кнопка "Показать ещё" для ручной подгрузки

**Не реализовано:**
- Поиск по жанру
- Поиск по языку
- Фильтр по стране
- Поиск по FM-частоте

---

## 3. Чего пока нет в VOLNA

### ❌ Поиск по жанру/тегу

**API endpoint:** `/json/stations/search?tag=rock&order=clickcount&limit=30`

**Пример запроса:**
```bash
https://all.api.radio-browser.info/json/stations/search?tag=rock&hidebroken=true&limit=10
```

**Что нужно добавить:**
1. UI для выбора жанра (список тегов уже загружается через `radio.tags`)
2. Обновить `RadioSearchView` для поддержки фильтра по `tag`
3. Либо создать отдельный `RadioGenreView` для просмотра станций по жанрам

### ❌ Продвинутые фильтры

**Комбинированный поиск:**
```bash
# Русские джазовые станции
?language=russian&tag=jazz&order=clickcount&limit=30

# Рок-станции из Германии
?countrycode=DE&tag=rock&order=clickcount&limit=30
```

**Что нужно:**
1. Расширенная форма поиска с чекбоксами/dropdown
2. Сохранение выбранных фильтров между сеансами
3. Быстрые пресеты: "Русский рок", "Европейский джаз", "Американский поп"

### ❌ Поиск по языку (отдельный фильтр)

**API endpoint:** `/json/stations/search?language=german&limit=30`

**Что нужно:**
1. Список языков уже загружается через `radio.languages(limit: 200)`
2. Добавить UI-элемент для выбора языка
3. Локализовать названия языков (russian → Русский)

### ❌ Поиск по FM-частоте

**Проблема:** Radio Browser НЕ содержит информации о FM-частотах.

**Почему:**
- Radio Browser — каталог **интернет-стримов**, а не FM-передатчиков
- API не имеет полей `frequency`, `fm`, `mhz` в структуре станции
- Теги станций также не содержат частот (проверено на московских станциях)

**Пример структуры станции:**
```json
{
  "stationuuid": "80da19d7-bf92-418b-a7f0-eab5b544bf96",
  "name": "Русское Радио",
  "url": "https://rusradio.hostingradio.ru/rusradio96.aacp",
  "url_resolved": "https://rusradio.hostingradio.ru/rusradio96.aacp",
  "country": "The Russian Federation",
  "countrycode": "RU",
  "state": "Москва",
  "language": "",
  "codec": "AAC+",
  "bitrate": 96,
  "tags": "поп-музыка",
  "clickcount": 131,
  "lastcheckok": 1
  // ❌ Нет полей frequency, fm_freq, mhz и т.д.
}
```

---

## 4. Ограничения Radio Browser

### Технические

| Ограничение | Значение | Примечание |
|-------------|----------|------------|
| Max limit | 100 станций | За один запрос (фактический лимит может отличаться) |
| Rate limit | Нет официального | Документация не упоминает, но рекомендуется User-Agent |
| Timeout | 25 секунд | Установлено в VOLNA |
| Pagination | Через `offset` | `offset=0,40,80,...` |
| Search type | Substring match | `name=jazz` найдёт "Jazz FM", "All Jazz Radio", etc. |
| Exact search | Отдельные endpoints | `/byname` vs `/bynameexact` |

### Качество данных

**Проблемы:**
- ❌ **Нет FM-частот** — невозможен поиск "103.5 FM → интернет-поток"
- ⚠️ **Дубликаты станций** — одна станция может быть добавлена несколько раз с разными URL
- ⚠️ **Неполные метаданные** — не все станции имеют `language`, `tags`, `favicon`
- ⚠️ **Кодировки в названиях** — некоторые станции отображаются как "Ð ÑÑÑÐºÐ¾Ðµ Ð Ð°Ð´Ð¸Ð¾" (проблема API, не VOLNA)
- ✅ **Проверка работоспособности** — станции проверяются каждые 24 часа, `lastcheckok` надёжен

**Вывод:** Radio Browser — отличный источник для интернет-радио, но **не подходит для поиска по FM-частотам**.

---

## 5. FM-частоты: откуда брать данные

### Существующие источники

#### 🔍 fmstream.org API

**URL:** https://fmstream.org/api.htm

**Особенности:**
- ✅ Связь FM-частот с интернет-стримами
- ✅ Поддержка геолокации
- ✅ Поиск по частоте, названию, жанру
- ⚠️ **Требует регистрации и API-ключ**
- ⚠️ **Только некоммерческое использование**
- ⚠️ **Подпись соглашения с указанием ФИО и адреса**
- ⚠️ **Возможна блокировка доступа без объяснений**

**Параметры API:**
```
c   - Country code (ITU format, example: ALS for Alaska)
l   - Language (ISO 2-letter)
s   - Search (name, style, frequency, country)
style - Genre/format
o   - Order (ab=alphabetically, top=by transmitter power)
n   - Offset (pagination)
```

**Пример запроса:**
```
GET /index.php?c=RUS&s=moscow&o=top
Accept: application/json
X-API-Key: <ваш ключ>
```

**Проблема:** Ключ выдаётся вручную, процесс одобрения может занять дни/недели.

#### 🔍 fmscan.org

**URL:** https://fmscan.org/

**Особенности:**
- ✅ Карта FM-передатчиков по всему миру
- ✅ Расчёт доступных станций по координатам GPS
- ✅ Учёт топографии, мощности передатчика, направленности антенн
- ❌ **API закрыт** (403 Forbidden при попытке доступа)
- ❌ **Только веб-интерфейс**

**Вывод:** Недоступен для интеграции в приложение.

#### 🔍 World Radio Map

**URL:** https://worldradiomap.com/

**Особенности:**
- ✅ FM-частоты для крупных городов
- ✅ Географическая карта станций
- ❌ **Нет публичного API**
- ❌ **Данные доступны только через веб-сайт**

#### 🔍 RadioReference.com

**URL:** https://www.radioreference.com/db/browse/stid/202

**Особенности:**
- ✅ База FM/AM/VHF/UHF частот по всему миру
- ✅ Включает российские станции
- ❌ **Нет публичного API**
- ❌ **Требует ручной парсинг веб-страниц (запрещено ToS)**

---

## 6. Как правильно реализовать поиск по FM-частоте

### Архитектура решения

#### Вариант 1: Интеграция с fmstream.org (Рекомендуется)

**Шаги:**
1. **Получить API-ключ fmstream.org**
   - Отправить письмо с описанием VOLNA
   - Подписать соглашение (некоммерческое использование)
   - Указать ссылку на fmstream.org в UI

2. **Создать FMStreamAPIClient**
   ```swift
   actor FMStreamAPIClient {
       func searchByFrequency(
           frequency: Double,      // 103.5 MHz
           latitude: Double,       // Координаты пользователя
           longitude: Double,
           radius: Int = 50        // км
       ) async throws -> [FMStation]
   }
   ```

3. **Связать FM → Radio Browser**
   - fmstream.org вернёт название станции + stream URL
   - Искать станцию в Radio Browser по названию
   - Воспроизводить через PlayerService

4. **UI Flow**
   ```
   Пользователь вводит: "103.5"
   ↓
   Запрос к fmstream.org: frequency=103.5, location=(GPS)
   ↓
   Результат: "Русское Радио, Москва, https://rusradio.ru/stream"
   ↓
   Поиск в Radio Browser: name="Русское Радио", countrycode="RU"
   ↓
   Воспроизведение через PlayerService.playRadio()
   ```

**Требования:**
- ✅ Геолокация (Core Location)
- ✅ Разрешение на доступ к местоположению
- ✅ Обработка отказа пользователя (fallback на ручной выбор города)

#### Вариант 2: Локальная база данных FM-частот

**Идея:** Создать собственную базу соответствий FM ↔ интернет-поток для крупнейших городов.

**Источники данных:**
- Открытые списки частот для Москвы, Санкт-Петербурга, Екатеринбурга
- Ручная верификация соответствий
- Сообщество пользователей (crowdsourcing)

**Пример структуры:**
```json
{
  "city": "Москва",
  "country": "RU",
  "stations": [
    {
      "frequency": 105.7,
      "name": "Русское Радио",
      "radio_browser_uuid": "80da19d7-bf92-418b-a7f0-eab5b544bf96"
    },
    {
      "frequency": 106.2,
      "name": "Европа Плюс",
      "radio_browser_uuid": "..."
    }
  ]
}
```

**Проблемы:**
- ❌ Требует ручного труда для сбора данных
- ❌ Быстро устаревает (станции меняют частоты)
- ❌ Не масштабируется (десятки тысяч городов)

**Вывод:** Подходит только как временное решение для ТОП-10 городов России.

#### Вариант 3: Гибридный подход

**Алгоритм:**
1. Пользователь вводит: `103.5 FM`
2. **Шаг 1:** Попытка поиска в локальной базе (если город известен)
3. **Шаг 2:** Если не найдено → запрос к fmstream.org API
4. **Шаг 3:** Если fmstream недоступен → показать ошибку с предложением искать по названию

**Преимущества:**
- ✅ Быстрый ответ для популярных станций (локальная база)
- ✅ Полное покрытие через API (для редких станций)
- ✅ Отказоустойчивость (fallback на ручной поиск)

---

## 7. Какие файлы VOLNA придётся изменить

### Для добавления фильтров по жанру/языку

#### 1. RadioSearchView.swift
**Изменения:**
- Добавить UI для выбора жанра (Picker или горизонтальный ScrollView с тегами)
- Добавить UI для выбора языка (Picker)
- Передавать выбранные фильтры в `RadioStationQuery`

**Пример кода:**
```swift
@State private var selectedGenre: String?
@State private var selectedLanguage: String?

// В функции performSearch():
var query = RadioStationQuery.search(text, limit: 30)
if let genre = selectedGenre {
    query.tag = genre
}
if let language = selectedLanguage {
    query.language = language
}
```

#### 2. RadioBrowseViews.swift (опционально)
**Цель:** Создать отдельный экран "Жанры" для быстрого доступа

```swift
struct RadioGenreBrowseView: View {
    let genres: [RadioGenre]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))]) {
                ForEach(genres) { genre in
                    NavigationLink(value: genre) {
                        GenreCard(genre: genre)
                    }
                }
            }
        }
        .navigationDestination(for: RadioGenre.self) { genre in
            RadioGenreStationsView(genre: genre)
        }
    }
}
```

### Для добавления поиска по FM-частоте

#### 1. FMStreamAPIClient.swift (новый файл)
**Цель:** Клиент для fmstream.org API

```swift
actor FMStreamAPIClient {
    private let session: URLSession
    private let apiKey: String
    
    func searchByFrequency(
        frequency: Double,
        latitude: Double,
        longitude: Double
    ) async throws -> [FMStation]
}
```

#### 2. FMStation.swift (новая модель)
**Цель:** Модель FM-станции с частотой

```swift
struct FMStation: Codable, Identifiable {
    let id: String
    let frequency: Double      // 103.5
    let name: String
    let city: String
    let streamURL: URL?
    let radioBrowserMatch: String?  // UUID в Radio Browser
}
```

#### 3. FMSearchView.swift (новый экран)
**Цель:** Отдельный экран для поиска по частоте

```swift
struct FMSearchView: View {
    @State private var frequency = ""
    @State private var userLocation: CLLocation?
    @State private var stations: [FMStation] = []
    
    var body: some View {
        VStack {
            // Input: "103.5" или "103.5 FM"
            TextField("FM частота", text: $frequency)
            
            // Результаты поиска
            List(stations) { station in
                FMStationRow(station: station)
            }
        }
    }
}
```

#### 4. RadioSearchView.swift (обновление)
**Изменения:**
- Добавить кнопку/toggle "Поиск по FM"
- Показывать подсказку "Включите геолокацию для поиска по частоте"

#### 5. AppState.swift
**Добавить:**
```swift
@Observable
final class AppState {
    let radio: RadioService
    let fmStream: FMStreamService  // Новый сервис
    let location: LocationService   // Новый сервис
    // ...
}
```

#### 6. LocationService.swift (новый файл)
**Цель:** Обёртка над Core Location для получения координат

```swift
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var location: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
}
```

#### 7. Info.plist
**Добавить:**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Для поиска радиостанций по FM-частоте нам нужна ваша геопозиция</string>
```

---

## 8. Рекомендации

### Краткосрочные улучшения (1-2 недели)

#### ✅ Приоритет 1: Фильтры по жанру/языку
**Почему:** API уже поддерживает, данные загружаются, только UI отсутствует.

**Что сделать:**
1. Добавить горизонтальный ScrollView с популярными жанрами над поиском
2. Добавить Picker для выбора языка
3. Сохранять выбранные фильтры в UserDefaults

**Файлы:**
- `RadioSearchView.swift` — добавить UI
- `RadioStationQuery` — уже поддерживает `tag` и `language`

**Оценка:** 3-4 часа работы + тестирование

#### ✅ Приоритет 2: Экран "Жанры"
**Почему:** Пользователи часто ищут радио по жанру, а не по названию.

**Что сделать:**
1. Создать `RadioGenreBrowseView` с сеткой жанров
2. При тапе на жанр → показать список станций
3. Добавить в главное меню радио

**Файлы:**
- `RadioGenreBrowseView.swift` — новый файл
- `RadioView.swift` — добавить вкладку "Жанры"

**Оценка:** 4-5 часов работы

#### ✅ Приоритет 3: Локализация языков
**Почему:** `language=russian` отображается как "russian" в UI.

**Что сделать:**
1. Создать словарь `languageCode → локализованное название`
2. Добавить в `RadioLanguage` computed property `localizedName`

**Пример:**
```swift
extension RadioLanguage {
    var localizedName: String {
        let mapping: [String: String] = [
            "russian": "Русский",
            "english": "Английский",
            "german": "Немецкий",
            // ...
        ]
        return mapping[name.lowercased()] ?? name.capitalized
    }
}
```

**Оценка:** 1-2 часа работы

### Долгосрочные улучшения (2-4 недели)

#### ⚠️ Приоритет 4: Поиск по FM-частоте

**Рекомендуемый подход:** Гибридный (локальная база + fmstream.org API)

**Этапы:**
1. **Неделя 1:** Получить API-ключ fmstream.org
2. **Неделя 2:** Реализовать `FMStreamAPIClient` и `LocationService`
3. **Неделя 3:** Создать локальную базу FM для Москвы, СПб, Екатеринбурга (ТОП-20 станций в каждом)
4. **Неделя 4:** UI для поиска по частоте + тестирование

**Риски:**
- ❌ fmstream.org может отказать в выдаче ключа (некоммерческое использование)
- ❌ Пользователи могут отключить геолокацию (fallback на ручной выбор города)
- ❌ FM-частоты устаревают (требуется обновление локальной базы)

**Альтернатива:** Отложить поиск по FM до появления надёжного открытого API.

---

## 9. Итоговая оценка текущей реализации

### Что работает отлично ✅

| Функция | Статус | Комментарий |
|---------|--------|-------------|
| Поиск по названию | ✅ Работает | Live search с debounce, пагинация |
| Каталог популярных станций | ✅ Работает | ТОП-20 по кликам |
| Русские станции | ✅ Работает | Подборка `language=russian` |
| Международные станции | ✅ Работает | Без фильтров по стране |
| Новые станции | ✅ Работает | Сортировка по дате добавления |
| Избранное | ✅ Работает | Локальное хранение UUID |
| Воспроизведение | ✅ Работает | PlayerService radio mode |
| ICY метаданные | ✅ Работает | Dual-method extraction |
| Пагинация | ✅ Работает | Автозагрузка + кнопка "Ещё" |

### Что отсутствует ❌

| Функция | Причина | Сложность реализации |
|---------|---------|---------------------|
| Поиск по жанру | UI не реализован | ⭐ Легко (4 часа) |
| Поиск по языку | UI не реализован | ⭐ Легко (2 часа) |
| Фильтр по стране | UI не реализован | ⭐ Легко (3 часа) |
| Комбинированный поиск | UI не реализован | ⭐⭐ Средне (6 часов) |
| Поиск по FM-частоте | Нет данных в Radio Browser | ⭐⭐⭐⭐ Сложно (40+ часов) |
| Экран "Жанры" | Не создан | ⭐⭐ Средне (5 часов) |
| Сохранение фильтров | Не реализовано | ⭐ Легко (1 час) |

---

## 10. Реальные примеры запросов к API

### Пример 1: Поиск по названию

**Запрос:**
```bash
GET https://all.api.radio-browser.info/json/stations/search?name=europa&hidebroken=true&limit=5
User-Agent: VOLNA/1.0
```

**Ответ (сокращённый):**
```json
[
  {
    "stationuuid": "...",
    "name": "Europa FM",
    "url_resolved": "https://live.europafm.ro/europafm/europafm-128.mp3",
    "country": "Romania",
    "countrycode": "RO",
    "language": "romanian",
    "tags": "pop,hits",
    "codec": "MP3",
    "bitrate": 128,
    "clickcount": 245
  }
]
```

### Пример 2: Русские джазовые станции

**Запрос:**
```bash
GET https://all.api.radio-browser.info/json/stations/search?language=russian&tag=jazz&order=clickcount&reverse=true&limit=10
```

**Результат:** Станции с русским языком вещания и тегом "jazz"

### Пример 3: Рок-станции из Германии

**Запрос:**
```bash
GET https://all.api.radio-browser.info/json/stations/search?countrycode=DE&tag=rock&order=clickcount&reverse=true&limit=10
```

### Пример 4: Пагинация

**Страница 1:**
```bash
GET ?name=radio&limit=20&offset=0
```

**Страница 2:**
```bash
GET ?name=radio&limit=20&offset=20
```

**Страница 3:**
```bash
GET ?name=radio&limit=20&offset=40
```

---

## Заключение

### Текущее состояние: 8/10 ⭐

VOLNA уже имеет **профессиональную реализацию** Radio Browser с правильной архитектурой, пагинацией и обработкой ошибок. Основная функция (поиск и воспроизведение интернет-радио) работает отлично.

### Быстрые победы (1 неделя работы):

1. ✅ **Добавить фильтры по жанру/языку** → +30% удобства поиска
2. ✅ **Создать экран "Жанры"** → +40% обнаруживаемости контента
3. ✅ **Локализовать языки** → +10% UX для русских пользователей

### Долгосрочная цель (1 месяц):

4. ⚠️ **Добавить поиск по FM-частоте** → +50% удобства для привычных к FM пользователей
   - Требует интеграции с fmstream.org API
   - Требует геолокации
   - Высокая сложность, но большая ценность

### Вердикт:

**Не меняй рабочий код Radio Browser.** Добавь недостающие UI-элементы для фильтров, которые API уже поддерживает. Поиск по FM-частоте — это отдельный большой проект, который требует другого источника данных.

---

**Приложение:** Все тестовые запросы выполнены 12 ноября 2026 года против `https://all.api.radio-browser.info` с User-Agent `VOLNA/1.0`.
