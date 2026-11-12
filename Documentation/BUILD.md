# VOLNA - Build Instructions

## Prerequisites

### Development Environment
- **macOS:** 14.0 (Sonoma) or later
- **Xcode:** 16.0 or later
- **Command Line Tools:** Installed via `xcode-select --install`
- **Homebrew:** For installing dependencies

### Required Tools
```bash
# Install XcodeGen
brew install xcodegen

# Verify installation
xcodegen --version
```

---

## Initial Setup

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/VOLNA.git
cd VOLNA
```

### 2. Configure API Keys

**Jamendo API:**
1. Register at [developer.jamendo.com](https://developer.jamendo.com)
2. Create a new application
3. Copy your Client ID
4. Open `VOLNA/Providers/JamendoProvider.swift`
5. Replace `YOUR_CLIENT_ID` with your actual client ID:

```swift
private let clientID = "your_actual_client_id_here"
```

> **Security Note:** For production, move API keys to a configuration file or use environment variables.

### 3. Generate Xcode Project
```bash
xcodegen generate
```

This will create `VOLNA.xcodeproj` from `project.yml`.

### 4. Open Project
```bash
open VOLNA.xcodeproj
```

---

## Project Configuration

### Signing & Capabilities

1. Select the **VOLNA** target in Xcode
2. Go to **Signing & Capabilities** tab
3. **Automatically manage signing:** Enable
4. **Team:** Select your Apple Developer team
5. **Bundle Identifier:** Use `com.volna.app` or customize

### Background Audio

The project is already configured for background audio playback:
- ✅ Audio background mode enabled in Info.plist
- ✅ AVAudioSession configured for playback
- ✅ MPNowPlayingInfoCenter integration
- ✅ MPRemoteCommandCenter for lock screen controls

---

## Building the App

### For Simulator

```bash
xcodebuild \
  -project VOLNA.xcodeproj \
  -scheme VOLNA \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  clean build
```

### For Device

1. **Connect your iPhone** via USB
2. **Trust the computer** on your device
3. In Xcode:
   - Select your device from the destination menu
   - Press **⌘R** or click Run
4. **First time:** You may need to trust the developer certificate on your device:
   - Settings → General → Device Management → Trust

### Archive for Distribution

```bash
xcodebuild archive \
  -project VOLNA.xcodeproj \
  -scheme VOLNA \
  -sdk iphoneos \
  -configuration Release \
  -archivePath build/VOLNA.xcarchive
```

### Export IPA

Create `ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
```

Then export:

```bash
xcodebuild -exportArchive \
  -archivePath build/VOLNA.xcarchive \
  -exportPath build \
  -exportOptionsPlist ExportOptions.plist
```

The IPA will be at `build/VOLNA.ipa`.

---

## GitHub Actions CI/CD

### Setup Secrets

For automated IPA builds, configure these GitHub Secrets:

1. Go to your repository on GitHub
2. Settings → Secrets and variables → Actions
3. Add the following secrets:

#### Required Secrets

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded .p12 certificate | See below |
| `P12_PASSWORD` | Password for .p12 certificate | Set when exporting |
| `BUILD_PROVISION_PROFILE_BASE64` | Base64-encoded provisioning profile | See below |
| `KEYCHAIN_PASSWORD` | Temporary keychain password | Any secure random string |
| `APPLE_TEAM_ID` | Apple Developer Team ID | From Apple Developer portal |

#### Exporting Certificate

```bash
# Export from Keychain Access
# 1. Open Keychain Access
# 2. Find your "Apple Development" or "Apple Distribution" certificate
# 3. Export as .p12 with a password
# 4. Convert to base64:

base64 -i certificate.p12 | pbcopy
# Paste into BUILD_CERTIFICATE_BASE64 secret
```

#### Exporting Provisioning Profile

```bash
# Download from Apple Developer portal
# Then convert to base64:

base64 -i profile.mobileprovision | pbcopy
# Paste into BUILD_PROVISION_PROFILE_BASE64 secret
```

### Workflows

The project includes two workflows:

1. **Build** (`.github/workflows/build.yml`)
   - Runs on push to main/develop
   - Builds for simulator
   - Runs tests
   
2. **Build IPA** (`.github/workflows/ipa.yml`)
   - Runs on version tags (`v*.*.*`)
   - Archives and exports IPA
   - Creates GitHub Release

#### Triggering a Release

```bash
git tag v0.1.0
git push origin v0.1.0
```

---

## Testing

### Run Unit Tests

```bash
xcodebuild test \
  -project VOLNA.xcodeproj \
  -scheme VOLNA \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### In Xcode

Press **⌘U** or Product → Test

---

## Troubleshooting

### XcodeGen Issues

**Problem:** `xcodegen: command not found`
```bash
brew install xcodegen
```

**Problem:** Project generation fails
```bash
# Check project.yml syntax
xcodegen generate --verbose
```

### Build Errors

**Problem:** Swift package resolution fails
```bash
# Clean and rebuild
rm -rf .build
xcodebuild -resolvePackageDependencies -project VOLNA.xcodeproj -scheme VOLNA
```

**Problem:** Code signing issues
1. Verify your Apple Developer account is active
2. Check Bundle Identifier is unique
3. Ensure provisioning profile matches the Bundle ID

### Audio Playback Issues

**Problem:** No sound in background
1. Check Info.plist has `audio` background mode
2. Verify AVAudioSession is configured correctly
3. Test on a real device (simulator may have limitations)

**Problem:** Lock screen controls not working
1. Check MPNowPlayingInfoCenter is updated
2. Verify MPRemoteCommandCenter handlers are registered

### API Issues

**Problem:** Jamendo returns 401 Unauthorized
- Check your Client ID is correct
- Verify API key is not expired
- Try regenerating the key from Jamendo developer portal

**Problem:** Rate limit exceeded
- Implement proper request throttling
- Add delays between requests
- Cache responses when possible

---

## Clean Build

```bash
# Remove all generated files
rm -rf build/
rm -rf VOLNA.xcodeproj
rm -rf .swiftpm/
rm -rf ~/Library/Developer/Xcode/DerivedData/VOLNA-*

# Regenerate
xcodegen generate

# Clean build
xcodebuild clean -project VOLNA.xcodeproj -scheme VOLNA
```

---

## Development Tips

### Live Preview

SwiftUI previews are available in Xcode. Look for `#Preview` macros in view files.

### Hot Reload

For faster iteration:
1. Keep simulator running
2. Make changes
3. Press **⌘R** to rebuild and run

### Debugging Audio

```swift
// Add in PlayerService
print("🎵 Current time: \(currentTime)")
print("🎵 Duration: \(duration)")
print("🎵 Playing: \(isPlaying)")
```

### Network Debugging

Enable network logging:
```swift
// In provider init
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 30
config.waitsForConnectivity = true
// Add URLSession delegate for detailed logs
```

---

## Performance Optimization

### Build Time

```bash
# Use multiple CPU cores
xcodebuild -parallelizeTargets
```

### App Size

The IPA size can be reduced by:
- Using asset catalogs for images
- Enabling bitcode (if targeting App Store)
- Removing unused dependencies

---

## Resources

- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [AVFoundation Guide](https://developer.apple.com/av-foundation/)
- [XcodeGen Documentation](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md)

---

## Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/VOLNA/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/VOLNA/discussions)
- **Documentation:** [Documentation/](.)

---

**Last Updated:** November 12, 2026
