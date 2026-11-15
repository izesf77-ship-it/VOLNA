# VOLNA HOME

**Музыкальное приложение для iOS** 
Bundle ID: `com.volna.app`  
Target: iOS 17.0+  
Язык: Swift + SwiftUI

---

## 🎯 Текущее состояние

→ См. [[Current State]]

Последнее обновление контекста: **2026-11-12**

---

## 📚 Быстрая навигация

### Проект
- [[Overview]] — общее описание проекта
- [[Current State]] — актуальное состояние разработки
- [[Architecture]] — архитектура приложения
- [[Roadmap]] — планы развития
- [[Project Rules]] — правила работы над проектом

### Функциональность
- [[Music Player]] — музыкальный плеер
- [[Radio]] — интернет-радио
- [[Music Catalog]] — каталог музыки
- [[Track Details]] — детали композиций
- [[Library]] — медиатека

### Компоненты
- [[PlayerService]] — сервис воспроизведения
- [[RadioService]] — сервис радио
- [[RadioAPIClient]] — API клиент Radio Browser
- [[Track]] — модель композиции
- [[Navigation]] — навигация приложения

### Troubleshooting ⚠️
- [[Troubleshooting/README|Troubleshooting Index]] — решённые проблемы
- [[Troubleshooting/GitHub Actions Build Failures|GitHub Actions Failures]] — ✅ **РЕШЕНО 2026-11-15**

### Разработка
- [[Known Issues]] — известные проблемы
- [[Resolved Issues]] — решённые проблемы
- [[Build History]] — история сборок
- [[Failed Builds]] — проблемы сборок
- [[Architecture Decisions]] — архитектурные решения

### Задачи
- [[Completed]] — завершённые задачи
- [[In Progress]] — задачи в работе
- [[Planned]] — запланированные задачи

---

## 🔗 Структура базы знаний

```
knowledge/
├── 00 - VOLNA HOME.md          ← вы здесь
├── Project/                    ← общая информация о проекте
├── Features/                   ← описание функций
├── Components/                 ← технические компоненты
├── Decisions/                  ← архитектурные решения
├── Bugs/                       ← баги и их исправления
├── Builds/                     ← история сборок
├── Sessions/                   ← история разработки
└── Tasks/                      ← управление задачами
```

---

## ⚠️ Правила для AI-агентов

### Перед началом работы:
1. Читай [[Current State]] для восстановления контекста
2. Ищи связанные заметки по текущей задаче через MCP
3. Проверяй реальный код, не полагайся только на заметки
4. Изучай [[Known Issues]] перед изменениями

### После завершения работы:
1. Обновляй [[Current State]]
2. Фиксируй новые решения в [[Architecture Decisions]]
3. Переноси баги из [[Known Issues]] в [[Resolved Issues]]
4. Обновляй статус задач
5. Создавай заметку о сессии в [[Development History]]

### Достоверность информации:
- ✅ Проверено и работает
- ⚠️ Реализовано, но не протестировано
- 🔄 В процессе разработки
- ❌ Не работает / требует исправления

---

## 🔧 Git & CI/CD

**Ветка:** `feature/open-music-catalog`  
**Последний коммит:** См. [[Build History]]

**GitHub Actions:**
- Runner: `xcode-27`
- Xcode: 27.x
- Unsigned IPA сборка
- Без сертификатов и provisioning profiles

---

## 📖 Дополнительная документация

В корне проекта:
- `README.md` — общее описание
- `Documentation/` — техническая документация
- `BUILD_STATUS.md` — статус сборок
- `IMPLEMENTATION_REPORT.md` — отчёты о реализации

---

*База знаний создана для сохранения контекста между AI-агентами и сессиями разработки VOLNA*
