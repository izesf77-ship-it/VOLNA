# VOLNA Changelog

История изменений проекта VOLNA, включая решённые проблемы и новые функции.

---

## 2026-11-15 — Critical Build Issues Resolved ✅

### Статус: 🟢 BUILD PASSING

**GitHub Actions Run:** [#43748857814](https://github.com/izesf77-ship-it/VOLNA/actions/runs/43748857814)  
**Branch:** `feature/open-music-catalog`  
**Commits:** 842e7d4, 9674c58, 44ed0ef

### Решённые проблемы:

#### 🔴 Critical: Broken Pipe in GitHub Actions
- **Commit:** 44ed0ef
- **Problem:** Workflow crashed with exit code 134 before compilation
- **Root Cause:** `xcrun simctl | head -40` caused SIGPIPE
- **Fix:** Added `|| true` to ignore SIGPIPE
- **Impact:** Blocked ALL builds, highest priority

#### 🟠 Swift: Track Initializer Error
- **Commit:** 842e7d4
- **Problem:** Preview used non-existent `streamURL` parameter
- **Fix:** Changed to required `sourceID` parameter
- **Files:** TrackDetailView.swift:362-363

#### 🟠 Swift: Optional String Unwrap
- **Commit:** 842e7d4
- **Problem:** `countryCode?` used without unwrapping
- **Fix:** Added `guard let` in 2 methods
- **Files:** RadioService.swift:336, 389

#### 🟠 Swift: Duplicate Component
- **Commit:** 842e7d4
- **Problem:** 43-line duplicate `RadioStationCard` declaration
- **Fix:** Removed duplicate, use existing from RadioComponents
- **Files:** TrackDetailView.swift:314

#### 🟠 Swift: Wrong API Method
- **Commit:** 9674c58
- **Problem:** Called non-existent `fetchStations(filter:)`
- **Fix:** Use correct `stations(for:)` method
- **Files:** TrackDetailView.swift:286

### Результат:
- ✅ Build and test job: 19m 43s — SUCCESS
- ✅ Build unsigned IPA job: 3m 1s — SUCCESS
- ✅ Unit tests: PASSED
- ✅ Artifacts created: IPA + 9 screenshots

### Документация:
- README.md обновлён с секцией "Решённые критические проблемы"
- Создана [[Troubleshooting/GitHub Actions Build Failures]]
- Обновлён [[Project/Current State]]

---

## 2026-11-12 — Radio Station Switching + Track Details

### Статус: ⚠️ Implemented but builds were broken

**Branch:** `feature/open-music-catalog`  
**Commit:** 652910e

### Новые функции:

#### Radio: Station Switching
- Next/Previous station in same country
- Random station in same country
- Implemented in RadioService, RadioPlayerView, MiniPlayerView
- All async calls properly wrapped in Task blocks

#### Track Details Page
- Full track information display
- Play and favorite controls
- Similar tracks (search by artist)
- Radio stations from artist's country
- Connected to HomeView, SearchView, LibraryView

#### Dynamic Island Integration
- NSUserActivity in PlayerService
- onContinueUserActivity in VOLNAApp
- **Known Issue:** Opens Telegram instead of VOLNA

### Файлы:
- RadioService.swift — new methods
- RadioPlayerView.swift — next/prev buttons
- TrackDetailView.swift — new view (330 lines)
- RadioPlaybackControl.swift — new component

---

## Earlier Changes

См. git history для полной истории:
```bash
git log --oneline --graph
```

---

## Quick Commands

### Check build status
```bash
gh run list --branch feature/open-music-catalog --limit 5
```

### View specific run
```bash
gh run view 43748857814
```

### Download artifacts
```bash
gh run download 43748857814 -n VOLNA-unsigned-IPA
```

---

**Legend:**
- 🔴 Critical — blocks all work
- 🟠 High — compilation/runtime error
- 🟡 Medium — feature incomplete
- 🟢 Low — enhancement
- ✅ Resolved
- ⚠️ Implemented but not tested
