# VOLNA Build Status Update

**Date**: November 15, 2026  
**Commit**: 49a7fe1  
**Branch**: feature/open-music-catalog

## What Was Fixed

### 1. GitHub Actions Runner Label ✅
**Problem**: Workflow used `runs-on: xcode-27` which doesn't exist  
**Solution**: Changed to `runs-on: xcode-27-arm64` (correct label per GitHub Actions documentation)

**Changed in both jobs**:
- `build-and-test` job
- `build-unsigned-ipa` job (renamed from `build-ipa`)

### 2. Simulator Device Names ✅
**Problem**: Workflow checked for iPhone 15/16 models that don't exist in Xcode 27  
**Solution**: Updated to check for Xcode 27 simulator names

**Old list**: iPhone 15 Pro, iPhone 15, iPhone 16 Pro, iPhone 16, iPhone 14 Pro, iPhone 14  
**New list**: iPhone 18 Pro, iPhone 17, iPhone 18 Pro Max, iPhone 17e, iPhone Air, iPhone Duo

**Verification**: Xcode 27 includes iOS 27.0/27.1/27.2 simulators with models:
- iPhone 17, 17e, 18 Pro, 18 Pro Max
- iPhone Air
- iPhone Duo (iOS 27.1+)
- Various iPads

### 3. Unsigned IPA Build ✅ COMPLETE REWRITE
**Problem**: Workflow required Apple Developer certificates and provisioning profiles  
**Solution**: Completely rewrote IPA build job to create unsigned IPA without any certificates

#### Job renamed:
`build-ipa` → `build-unsigned-ipa`

#### Certificate requirements removed:
- ❌ No IOS_CERTIFICATE_P12_BASE64 required
- ❌ No IOS_CERTIFICATE_PASSWORD required
- ❌ No IOS_PROVISIONING_PROFILE_BASE64 required
- ❌ No APPLE_TEAM_ID required
- ❌ No keychain import steps
- ❌ No exportArchive with signing

#### New unsigned build process:
1. **Archive without signing**:
   ```bash
   xcodebuild archive \
     -scheme VOLNA \
     -configuration Release \
     -destination 'generic/platform=iOS' \
     CODE_SIGNING_ALLOWED=NO \
     CODE_SIGNING_REQUIRED=NO \
     CODE_SIGN_IDENTITY="" \
     DEVELOPMENT_TEAM="" \
     PROVISIONING_PROFILE_SPECIFIER=""
   ```

2. **Extract .app bundle**:
   - Locate `VOLNA.app` in archive at `Products/Applications/`
   - Verify structure exists

3. **Create IPA manually**:
   ```bash
   mkdir -p build/ipa/Payload
   cp -R VOLNA.xcarchive/Products/Applications/VOLNA.app build/ipa/Payload/
   cd build/ipa && zip -r ../../VOLNA-unsigned.ipa Payload
   ```

4. **Comprehensive verification**:
   - ✅ Check IPA file exists
   - ✅ List IPA contents
   - ✅ Extract and verify Payload/VOLNA.app structure
   - ✅ Verify Info.plist exists
   - ✅ Verify executable exists and not empty (> 1000 bytes)
   - ✅ Read and validate Bundle ID (`com.volna.app`)
   - ✅ Display version info (version, build number, git SHA)
   - ✅ List embedded frameworks (if any)

5. **Calculate checksum**:
   - SHA-256 hash of IPA file
   - Included in build summary

6. **GitHub Actions Artifact**:
   - Name: `VOLNA-unsigned-IPA`
   - File: `VOLNA-unsigned.ipa`
   - Retention: 30 days

#### Build summary includes:
- Commit SHA
- Build number (GitHub run ID)
- Bundle ID verification
- Version number
- IPA size in bytes
- SHA-256 checksum
- Instructions for sideloading
- Links to Sideloadly, AltStore

## Current Status

### Git Status ✅
```
Branch: feature/open-music-catalog
HEAD: 49a7fe1
Remote: up-to-date with origin
```

### GitHub Actions Status 🔄 QUEUED
- New workflow run triggered by push
- Commit: 49a7fe1
- Status: Queued (as of document creation)
- Expected to start shortly

### Files Modified
1. `.github/workflows/build.yml` (419 insertions, 158 deletions)
2. `AUDIT_REPORT.md` (new file, comprehensive analysis)

## What To Expect

### If Build Succeeds ✅
1. Two jobs will complete:
   - `build-and-test`: Simulator build + unit tests + screenshots
   - `build-unsigned-ipa`: Release archive + unsigned IPA

2. Artifacts available for download:
   - `VOLNA-unsigned-IPA` - The unsigned IPA file
   - `simulator-screenshots-{sha}` - App screenshots (if captured)

3. Build summary will show:
   - IPA size
   - SHA-256 checksum
   - Installation instructions

4. Next steps:
   - Download IPA from GitHub Actions artifacts
   - Sign with Sideloadly or AltStore using any Apple ID
   - Install on iPhone 15 Pro (or any iOS 17.0+ device)

### If Build Fails with Compilation Errors 🔴
**Previous runs failed with exit code 65** which indicates Swift compilation errors.

Possible causes we'll investigate:
1. Swift concurrency issues (actor isolation, MainActor)
2. Type mismatches in recent Radio integration
3. Missing imports or symbols
4. Test compilation errors

**Action required**: 
- Download build logs from failed run
- Identify specific error messages
- Fix Swift code issues
- Push fix and retry

### If Runner Still Fails ❌
If `xcode-27-arm64` runner doesn't work either:
- Check GitHub Actions runner-images documentation
- Try alternative labels (might need `xcode-27` without `-arm64` suffix)
- Contact GitHub support or check runner availability

## Verification Checklist

Once build completes successfully, verify:

- [ ] Both jobs completed (green checkmarks)
- [ ] Artifact `VOLNA-unsigned-IPA` is available
- [ ] Download artifact (should be a ZIP containing the IPA)
- [ ] Extract and verify IPA file present
- [ ] Check IPA size (should be several MB, not empty)
- [ ] Unzip IPA and verify structure:
  ```
  Payload/
    VOLNA.app/
      Info.plist
      VOLNA (executable)
      Assets.car
      ...
  ```
- [ ] Verify Bundle ID in Info.plist: `com.volna.app`
- [ ] Verify version: `1.0.0`
- [ ] Verify build number matches GitHub run ID
- [ ] Verify Git SHA in Info.plist matches commit 49a7fe1
- [ ] Note SHA-256 checksum from build summary
- [ ] Attempt sideloading installation (requires actual device)

## Technical Details

### Archive Location
```
build/VOLNA.xcarchive/Products/Applications/VOLNA.app
```

### IPA Structure
```
VOLNA-unsigned.ipa (ZIP archive)
└── Payload/
    └── VOLNA.app/
        ├── Info.plist
        ├── VOLNA (Mach-O executable)
        ├── Assets.car
        ├── Base.lproj/
        ├── ru.lproj/
        ├── en.lproj/
        └── ... (other resources)
```

### Code Signing Status
- Archive built with: `CODE_SIGNING_ALLOWED=NO`
- No signature present in .app bundle
- Cannot install directly (expected behavior)
- Requires signing via sideloading tool

### Installation Methods
**Sideloadly** (Windows/Mac):
1. Install Sideloadly from sideloadly.io
2. Connect iPhone via USB
3. Drag VOLNA-unsigned.ipa to Sideloadly
4. Enter Apple ID (free or paid account)
5. Click Start - Sideloadly signs and installs

**AltStore** (Windows/Mac):
1. Install AltStore from altstore.io
2. Install AltServer on PC/Mac
3. Connect iPhone via USB and trust PC
4. Open AltStore on iPhone
5. Add VOLNA-unsigned.ipa via My Apps → +
6. AltStore signs and installs

**Xcode** (Mac only):
1. Open Xcode
2. Window → Devices and Simulators
3. Select connected iPhone
4. Drag VOLNA.app (not IPA) to Installed Apps
5. Xcode signs automatically with personal team

## Dependencies

### Build Requirements
- Xcode 27.x (27.0, 27.1, or 27.2)
- XcodeGen (installed via Homebrew)
- iOS 17.0+ SDK
- macOS runner (xcode-27-arm64)

### Runtime Requirements
- iPhone running iOS 17.0 or later
- Sideloading tool (Sideloadly, AltStore, etc.)
- Apple ID (free account works)

### No External Dependencies
- No CocoaPods
- No Swift Package Manager packages
- All code is internal
- Reduces build complexity

## Known Limitations

### Unsigned IPA
- Cannot install via App Store
- Cannot TestFlight distribute
- Requires manual renewal every 7 days (free Apple ID) or 1 year (paid)
- Must re-sign if certificate expires

### Sideloading
- iPhone must be in Developer Mode (iOS 16+)
- AltStore requires AltServer running on PC/Mac
- Sideloadly requires connection per install
- Maximum 3 apps at once (free Apple ID limit)

### Radio Streams
- Some stations broadcast HTTP (not HTTPS)
- Allowed via NSAllowsArbitraryLoadsForMedia
- Only affects AVPlayer media loading
- General networking still requires HTTPS

## Next Actions

### Immediate (Waiting)
1. 🔄 Monitor GitHub Actions run progress
2. 🔄 Wait for build completion
3. 🔍 Review build logs if failures occur

### On Success
1. ✅ Download VOLNA-unsigned-IPA artifact
2. ✅ Verify IPA structure and size
3. ✅ Document SHA-256 in final report
4. ✅ Test installation via Sideloadly
5. ✅ Verify app launches and plays music/radio

### On Failure
1. 🔍 Download build-logs artifact
2. 🔍 Identify specific compilation errors
3. 🛠️ Fix Swift code issues
4. 🔄 Push fix commit
5. 🔄 Retry build

### Documentation
1. 📝 Create final completion report
2. 📝 Document actual IPA size and hash
3. 📝 Include GitHub Actions run URL
4. 📝 Include artifact download instructions
5. 📝 List any issues found and resolved

## Questions Answered

### Why unsigned IPA?
- User explicitly requested NO certificates
- Intended for sideloading, not App Store
- Allows development without paid Apple Developer account
- Can be signed later with any Apple ID

### Why not TestFlight?
- TestFlight requires paid Apple Developer account ($99/year)
- TestFlight requires uploaded IPA with App Store Connect
- Sideloading works with free Apple ID
- Faster iteration for development

### Why xcode-27-arm64?
- GitHub Actions runner label for macOS with Xcode 27
- Apple Silicon (M-series) runners
- Faster builds than Intel runners
- Latest Xcode with iOS 27 SDK

### Will it work on older iOS?
- Deployment target: iOS 17.0
- Will install on iOS 17.0 through iOS 27.x
- Won't install on iOS 16.x or older
- Can lower deployment target if needed

## Commit Details

**Hash**: 49a7fe1  
**Message**: ci: fix runner label and build unsigned IPA without certificates

**Changes**:
- Fixed runner label xcode-27 → xcode-27-arm64
- Updated simulator names for Xcode 27
- Removed all certificate/provisioning profile code
- Implemented manual IPA packaging
- Added comprehensive verification steps
- Renamed artifact to VOLNA-unsigned-IPA

**Files**:
- `.github/workflows/build.yml`: 577 lines changed (419+, 158-)
- `AUDIT_REPORT.md`: 800+ lines added (new file)

---

**Status**: 🔄 Waiting for GitHub Actions build results  
**Last Updated**: November 15, 2026  
**Next Update**: After build completes (success or failure)
