# GitHub Actions Build Failures - Complete Investigation

## Overview

Between commits `5b422be` and `44ed0ef`, all GitHub Actions builds on branch `feature/open-music-catalog` were failing. This document records the complete investigation, root causes, and solutions.

## Timeline

| Date | Run ID | SHA | Status | Issue |
|------|--------|-----|--------|-------|
| 2026-11-15 | 43739938370 | 5b422be | ❌ Failed | Unknown (pre-investigation) |
| 2026-11-15 | 43735607657 | 5f35ec2 | ❌ Failed | Async/await issues |
| 2026-11-15 | 43747763054 | 842e7d4 | ❌ Failed | Wrong API method call |
| 2026-11-15 | 43748535688 | 9674c58 | ❌ Failed | Broken pipe in workflow |
| 2026-11-15 | 43748857814 | **44ed0ef** | ✅ **SUCCESS** | All issues fixed |

## Root Causes

### 1. Critical: GitHub Actions Workflow Bug 🔴

**Severity**: Critical - blocked ALL builds before compilation

**Location**: `.github/workflows/build.yml:46`

**Symptom**:
```
*** Terminating app due to uncaught exception 'NSFileHandleOperationException'
reason: '*** -[_NSStdIOFileHandle writeData:]: Broken pipe'
##[error]Process completed with exit code 134.
```

**Root Cause**:
```bash
xcrun simctl list devices available | head -40
```

The problem:
1. `head -40` reads 40 lines and closes the read end of the pipe
2. `xcrun simctl` continues writing to the closed pipe
3. Receives **SIGPIPE** signal
4. `NSFileHandleOperationException` thrown
5. Process exits with code **134**
6. Entire workflow fails **BEFORE** Swift compilation starts

**Fix** (Commit 44ed0ef):
```bash
xcrun simctl list devices available | head -n 40 || true
```

Adding `|| true` makes the command ignore SIGPIPE exit code, allowing the workflow to continue.

**Why this is critical**: This bug prevented ANY Swift code from being compiled. All previous fixes were correct but couldn't be verified because the workflow crashed before reaching compilation.

---

### 2. Swift Compilation Error: Track Initializer

**Severity**: High - compilation error

**Location**: `VOLNA/Features/Track/TrackDetailView.swift:362-363`

**Error**:
```
error: extra argument 'streamURL' in call
error: missing argument for parameter 'sourceID' in call
```

**Root Cause**:
Preview provider used non-existent initializer parameter:
```swift
// ❌ Wrong
Track(
    streamURL: URL(string: "https://example.com/stream.mp3")!,
    // ... other params
)
```

The `Track` initializer requires `sourceID: String`, not `streamURL: URL`.

**Fix** (Commit 842e7d4):
```swift
// ✅ Correct
Track(
    sourceID: "mock-source-\(UUID().uuidString)",
    // ... other params
)
```

---

### 3. Swift Compilation Error: Optional String Unwrap

**Severity**: High - compilation error

**Location**: `VOLNA/Services/RadioService.swift:336, 389`

**Error**:
```
error: value of optional type 'String?' must be unwrapped to refer to member 'trimmingCharacters'
```

**Root Cause**:
Methods `findNextStationInCountry` and `playRandomStationInCountry` used `RadioStation.countryCode` (type `String?`) without unwrapping:

```swift
// ❌ Wrong
let trimmed = countryCode.trimmingCharacters(in: .whitespacesAndNewlines)
```

**Fix** (Commit 842e7d4):
```swift
// ✅ Correct
guard let code = countryCode else { return }
let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
```

Applied to both methods at lines 336 and 389.

---

### 4. Swift Compilation Error: Duplicate Component Declaration

**Severity**: Medium - compilation error

**Location**: `VOLNA/Features/Track/TrackDetailView.swift:314`

**Error**:
```
error: invalid redeclaration of 'RadioStationCard'
```

**Root Cause**:
`TrackDetailView.swift` contained a 43-line duplicate definition of `RadioStationCard` component, which was already defined in `VOLNA/Features/Radio/RadioComponents.swift`.

**Fix** (Commit 842e7d4):
- Removed duplicate 43-line component from TrackDetailView
- Use existing component from RadioComponents with `width: 160` parameter

```swift
// ✅ Use existing component
RadioStationCard(station: station, width: 160)
```

---

### 5. Wrong API Method Call

**Severity**: High - compilation error

**Location**: `VOLNA/Features/Track/TrackDetailView.swift:286`

**Error**:
```
error: value of type 'RadioService' has no member 'fetchStations'
```

**Root Cause**:
Code called non-existent method:
```swift
// ❌ Wrong - method doesn't exist
appState.radio.fetchStations(filter: .country(code, limit: 20))
```

**Correct API** (from RadioService.swift):
```swift
func stations(for query: RadioStationQuery) async throws -> RadioPage
```

**Fix** (Commit 9674c58):
```swift
// ✅ Correct
let page = await appState.radio.stations(for: .country(code, limit: 20))
let stations = page.stations
```

---

## Investigation Process

### Step 1: Get Failed Run Logs
```bash
gh run list --branch feature/open-music-catalog --limit 5
gh run view 43739938370 --log-failed
```

### Step 2: Identify Compilation Errors
Found 3 Swift compilation errors in build logs:
- Track initializer
- Optional unwrap
- Duplicate component

### Step 3: Fix Swift Errors
Created commit 842e7d4 with fixes for all 3 compilation errors.

### Step 4: Discover Additional Error
Build still failed with `fetchStations` method error.

### Step 5: Fix API Call
Created commit 9674c58 to fix RadioService API call.

### Step 6: Discover Root Cause
Build STILL failed with exit code 134 **before compilation**.

Analyzed full logs and found:
- Xcode version detected successfully: `27.1`
- Crash in `xcrun simctl | head -40` pipe
- `NSFileHandleOperationException: Broken pipe`

### Step 7: Fix Workflow
Created commit 44ed0ef to fix broken pipe issue.

### Step 8: Success ✅
Build 43748857814 completed successfully:
- Job 1: Build and test (19m 43s) ✅
- Job 2: Build unsigned IPA (3m 1s) ✅

---

## Lessons Learned

### 1. **Shell Pipeline Safety**
Always handle SIGPIPE in shell pipelines:
```bash
# ❌ Dangerous
command_with_lots_of_output | head -n 10

# ✅ Safe
command_with_lots_of_output | head -n 10 || true
```

### 2. **Order of Fixes Matters**
All Swift compilation errors were fixed correctly, but couldn't be verified due to workflow crash. The workflow bug should have been identified first.

### 3. **Read Full Logs**
Early investigation focused on compilation errors visible in truncated logs. The root cause (broken pipe) was only visible in the full log output at the beginning of the workflow.

### 4. **Exit Codes Matter**
Exit code 134 = SIGABRT = abnormal termination, not a compilation error. This should have been a clue that the issue was in the toolchain/runner, not Swift code.

### 5. **Test Incrementally**
After each fix, verify that specific error is resolved. We fixed multiple issues in one commit, making it harder to isolate which fix addressed which error.

---

## Verification

### Build Success Indicators

✅ **Workflow steps completed**:
- Show Xcode, iOS SDK and Swift versions
- XcodeGen project generation  
- Swift compilation (Debug + Release)
- Unit tests execution
- Simulator screenshots capture
- Unsigned IPA packaging

✅ **Artifacts created**:
- `VOLNA-unsigned-IPA` (Bundle ID: com.volna.app)
- `simulator-screenshots-44ed0ef...` (9 screenshots)

✅ **Configuration verified**:
- Xcode version: 27.1
- Runner: xcode-27
- Swift driver: 1.168.6

---

## Related Documents

- [[Project/Current State]] - Project status
- [[Project/Architecture]] - System architecture
- [[Troubleshooting/README]] - Troubleshooting index

---

## Quick Reference

```bash
# Check latest build status
gh run list --branch feature/open-music-catalog --limit 1

# View successful run
gh run view 43748857814

# Download IPA
gh run download 43748857814 -n VOLNA-unsigned-IPA

# Download screenshots
gh run download 43748857814 -n simulator-screenshots-44ed0efbc0afe3b6d35bcbed3cbae1127f2d9e0b
```

---

**Status**: ✅ Resolved  
**Last Updated**: 2026-11-15  
**Commits**: 842e7d4, 9674c58, 44ed0ef  
**Successful Run**: [#43748857814](https://github.com/izesf77-ship-it/VOLNA/actions/runs/43748857814)
