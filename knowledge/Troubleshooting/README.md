# Troubleshooting

Документация решённых проблем и методов диагностики в проекте VOLNA.

## Критические проблемы

### [[GitHub Actions Build Failures]]
**Статус**: ✅ Решено  
**Дата**: 2026-11-15  
**Влияние**: Блокировало все сборки в CI/CD

Полное расследование падений GitHub Actions builds на ветке `feature/open-music-catalog`. Включает:
- Broken pipe в workflow (exit code 134)
- Swift compilation errors (4 шт.)
- Порядок исправлений и lessons learned

---

## Категории проблем

### 🔴 CI/CD Issues
- [[GitHub Actions Build Failures#1. Critical: GitHub Actions Workflow Bug|Broken Pipe in simctl]]

### 🟠 Swift Compilation
- [[GitHub Actions Build Failures#2. Swift Compilation Error: Track Initializer|Track Initializer Error]]
- [[GitHub Actions Build Failures#3. Swift Compilation Error: Optional String Unwrap|Optional Unwrap Error]]
- [[GitHub Actions Build Failures#4. Swift Compilation Error: Duplicate Component|Duplicate Component]]
- [[GitHub Actions Build Failures#5. Wrong API Method Call|Wrong API Method]]

---

## Быстрые решения

### Проверить статус сборки
```bash
gh run list --branch feature/open-music-catalog --limit 1
```

### Получить логи последней неудачной сборки
```bash
gh run view --log-failed
```

### Скачать артефакты успешной сборки
```bash
gh run download 43748857814 -n VOLNA-unsigned-IPA
```

---

## Уроки

1. **Shell pipelines**: Всегда добавляйте `|| true` после `head` в pipelines
2. **Read full logs**: Корневая причина может быть в начале лога, не только в ошибках компиляции
3. **Exit codes**: 134 = SIGABRT, указывает на проблему в toolchain, не в коде
4. **Test incrementally**: Исправляйте и тестируйте по одной проблеме

---

## См. также

- [[Project/Current State]] - Текущее состояние проекта
- [[Project/Architecture]] - Архитектура системы
- [[00-VOLNA HOME]] - Главная страница
