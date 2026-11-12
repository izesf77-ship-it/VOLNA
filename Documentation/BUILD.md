# VOLNA — сборка и CI

## Требования

- macOS 14+
- Xcode 15+ (в GitHub Actions используется `macos-latest` с доступной версией Xcode)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Apple Developer account — только для установки на физический iPhone или подписи IPA

Локальная сборка на Windows/Linux невозможна: проект использует SwiftUI, AVFoundation и MediaPlayer.

---

## Локальная сборка

```bash
brew install xcodegen
git clone https://github.com/izesf77-ship-it/VOLNA.git
cd VOLNA
xcodegen generate
open VOLNA.xcodeproj
```

`VOLNA.xcodeproj` генерируется из `project.yml` и не хранится в репозитории.

### Симулятор

```bash
xcodebuild \
  -project VOLNA.xcodeproj \
  -scheme VOLNA \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

Если другой версии симулятора нет:

```bash
xcrun simctl list devices available
```

и подставьте доступное имя.

### Тесты

```bash
xcodebuild test \
  -project VOLNA.xcodeproj \
  -scheme VOLNA \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Тестовый таргет `VOLNATests` хостится приложением (`TEST_HOST`), содержит unit-тесты лицензий, языков/транслитерации, дедупликации, форматов, прямых ссылок и LRC-парсера.

### Устройство

1. Подключите iPhone и Trust This Computer.
2. В Xcode выберите target **VOLNA** → **Signing & Capabilities**.
3. Укажите Team и при необходимости измените Bundle Identifier.
4. Выберите устройство и нажмите **⌘R**.

Для запуска на устройстве нужна ваша подпись. В репозитории сертификаты не хранятся.

---

## API и секреты

| Сервис | Ключ | Где хранится |
|---|---|---|
| Jamendo | публичный Client ID `b488b912` | в коде, это не секрет |
| Internet Archive | не требуется | — |
| Wikimedia Commons | не требуется | — |
| Openverse | не требуется (анонимный лимит) | — |
| LRCLIB | не требуется | — |

**Jamendo Client Secret не используется.** Не добавляйте его в репозиторий, `Info.plist`, `.xcconfig` или secrets workflow: приложение работает только с публичным Client ID.

---

## GitHub Actions

### Build and Test

Файл: `.github/workflows/build.yml`

Запускается при push и pull request в `master` и `feature/open-music-catalog`, а также вручную. Выполняет:

1. `xcodegen generate`
2. сборку под iOS Simulator;
3. выбор доступного iPhone-симулятора;
4. `xcodebuild test`.

### Build IPA

Файл: `.github/workflows/ipa.yml`

Запускается по тегам `v*.*.*` и вручную. Логика:

- если **все** signing secrets заданы — archive + export подписанной IPA (`VOLNA-signed.ipa`);
- если хотя бы одного секрета нет — archive без подписи и упаковка `VOLNA-unsigned.ipa`;
- артефакт `VOLNA-IPA` загружается всегда;
- для тега создаётся GitHub Release с честным описанием файлов.

### Signing secrets (необязательно)

| Secret | Назначение |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | `.p12` сертификат в base64 |
| `P12_PASSWORD` | пароль `.p12` |
| `BUILD_PROVISION_PROFILE_BASE64` | `.mobileprovision` в base64 |
| `KEYCHAIN_PASSWORD` | пароль временной keychain |
| `DEVELOPMENT_TEAM` | Apple Developer Team ID |

Если секретов нет, CI **не** пытается подписывать и **не** выдаёт неподписанный файл за устанавливаемый.

Получить base64 на macOS:

```bash
base64 -i certificate.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
```

### Неподписанная IPA

`VOLNA-unsigned.ipa`:

- в релизе `v1.0.0` такой файл уже есть: `https://github.com/izesf77-ship-it/VOLNA/releases/tag/v1.0.0`;
- не устанавливается двойным щелчком;
- не предназначена для App Store;
- требует собственной подписи (AltStore, Sideloadly, Xcode) и вашей учётной записи Apple;
- собрана из `Release`-конфигурации без signing identity.

### Ручной запуск

Actions → **Build IPA** → Run workflow. Артефакт появится в разделе Artifacts завершённого запуска.

### Release

```bash
git tag v1.0.0
git push origin v1.0.0
```

Тег запускает `ipa.yml`. Если подпись не настроена, к релизу будет приложена только неподписанная IPA с соответствующим описанием.

---

## Проверка качества

В репозитории есть статическая проверка исходников, но **физический iPhone в рамках разработки не использовался**. Поэтому:

- сборка и unit-тесты **проверены GitHub Actions**: 26 тестов, 0 падений (коммит `2ba79df`);
- **IPA workflow проверен** на теге `v1.0.0`: артефакт собран, `embedded.mobileprovision` и `_CodeSignature` отсутствуют;
- воспроизведение, фон, экран блокировки, прерывания и маршруты аудио требуют проверки на реальном устройстве;
- сетевые провайдеры проверялись живыми HTTP-запросами (Jamendo, Internet Archive, Wikimedia, Openverse), но это не заменяет тест на iPhone.

---

## Частые проблемы

### `xcodegen: command not found`

```bash
brew install xcodegen
```

### `VOLNA.xcodeproj` отсутствует

```bash
xcodegen generate
```

### Ошибка подписи в CI

Проверьте, что заданы все пять signing secrets и что Bundle ID `com.volna.app` присутствует в provisioning profile. Без секретов используйте неподписанную сборку.

### Jamendo возвращает пустую выдачу по-русски

Jamendo ищет по языку метаданных. Для кириллических запросов приложение добавляет `lang=ru`. Это поведение проверено живыми запросами; см. [RUSSIAN_CATALOG.md](RUSSIAN_CATALOG.md).

### Нет звука в фоне на симуляторе

Фоновое аудио проверяется на устройстве. Убедитесь, что в `Info.plist` включён `UIBackgroundModes` → `audio`, а на устройстве не активен режим энергосбережения, ограничивающий фон.
