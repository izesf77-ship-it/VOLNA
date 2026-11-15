# VOLNA — Overview

**Статус:** Active Development  
**Платформа:** iOS 17.0+  
**Язык:** Swift 5.0, SwiftUI  
**Архитектура:** MVVM + Services  

---

## 🎵 Что такое VOLNA?

VOLNA — музыкальное iOS-приложение с открытым каталогом и интернет-радио.

### Ключевые возможности:
- 🎶 **Музыкальный плеер** — воспроизведение треков из открытых источников
- 📻 **Интернет-радио** — доступ к 40,000+ радиостанций через Radio Browser API
- 🔍 **Поиск** — по трекам, исполнителям, альбомам и радиостанциям
- 💾 **Медиатека** — избранное, история, плейлисты
- 📱 **Native iOS** — Dynamic Island, Now Playing, Control Center

---

## 🏗️ Архитектура

См. подробнее: [[Architecture]]

### Основные компоненты:
- [[PlayerService]] — единый AVPlayer для музыки и радио
- [[RadioService]] — управление радиостанциями
- Music Providers — Jamendo, Internet Archive, Community Catalogs
- AppState — глобальное состояние через Observation framework

### Технологии:
- **UI:** SwiftUI, NavigationStack
- **Audio:** AVFoundation, MediaPlayer
- **Сеть:** URLSession, async/await
- **Состояние:** @Observable (iOS 17+)
- **Сборка:** XcodeGen

---

## 🎯 Цели проекта

1. **Открытость** — использование только открытых каталогов и API
2. **Простота** — минималистичный UI без перегруженности
3. **Нативность** — полная интеграция с iOS экосистемой
4. **Надёжность** — стабильная работа без сбоев

---

## 🔗 Связи

- [[Current State]] — текущее состояние
- [[Roadmap]] — планы развития
- [[Architecture]] — детальная архитектура
- [[Music Player]] — функциональность плеера
- [[Radio]] — функциональность радио

---

## 📦 Провайдеры музыки

### Активные:
- **Jamendo** — основной каталог, Creative Commons музыка
- **Internet Archive** — архивные записи
- **Community Catalogs** — кастомные каталоги

### Запланированные:
- SoundCloud (через публичные треки)
- Bandcamp (открытые альбомы)

См. `Documentation/PROVIDER_STATUS.md`

---

## 🚀 Деплой

**Метод:** Unsigned IPA через GitHub Actions  
**Runner:** xcode-27 (Xcode 27)  
**Установка:** Sideloading (Sideloadly, AltStore)

Требования:
- Без Apple Developer сертификатов
- Без provisioning profiles
- Установка на устройство через сторонние инструменты

---

## 📖 Документация

В репозитории:
- `README.md` — для пользователей
- `Documentation/` — техническая документация
- `knowledge/` — база знаний для AI (эта папка)

---

*Обновлено: 2026-11-12*
