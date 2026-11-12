# VOLNA - Research Document

## Project Overview
VOLNA is a free, native iOS music streaming application with multi-source search, no backend, and commercial-grade UI/UX inspired by Яндекс Музыка (Yandex Music).

**Last Updated:** November 12, 2026

---

## 1. Open Source Projects Analysis

### 1.1 Cassette (MPL-2.0)
**Repository:** https://github.com/CassetteLab/cassette

**Key Findings:**
- Native Swift/SwiftUI for iOS 18+ and macOS 15+
- Subsonic/OpenSubsonic API client implementation
- AudioStreaming engine (MIT) for playback with FLAC support
- MPNowPlayingInfoCenter integration for lock screen controls
- SwiftData for persistence (downloads, playlists, favorites cache)
- Swift 6 strict concurrency model
- Clean architecture: Services as actors, ViewModels with @Observable

**Applicable to VOLNA:**
- Architecture pattern (Service layer with actors)
- Audio playback engine reference (AudioStreaming by Dimitris C.)
- Background playback implementation
- Queue management patterns
- SwiftUI + @Observable pattern

**License:** MPL-2.0 - Compatible, allows combining with proprietary code

### 1.2 Trop (GPL-3.0)
**Repository:** https://github.com/SwiftyMedia/Trop

**Key Findings:**
- YouTube Music client for iOS 26+
- InnerTube API integration
- Synced lyrics from multiple sources (Musixmatch, LRCLIB, Netease, Kugou, Genius)
- SponsorBlock integration
- Equalizer implementation
- Custom themes and icons

**Applicable to VOLNA:**
- Multi-source lyrics aggregation approach
- YouTube Music integration patterns (must respect ToS)
- Equalizer implementation reference

**License:** GPL-3.0 - Cannot directly use code, use as reference only

### 1.3 AudioStreaming (MIT)
**Repository:** https://github.com/dimitris-c/AudioStreaming

**Key Findings:**
- AVAudioEngine-based streaming
- Online streaming + local file support
- Gapless queue support
- Written in Swift

**Applicable to VOLNA:**
- Can be integrated directly (MIT license)
- Proven streaming engine

**License:** MIT - Fully compatible

### 1.4 InternetArchiveKit (License TBD)
**Repository:** https://github.com/jbuckner/InternetArchiveKit

**Key Findings:**
- Swift library for Internet Archive API
- Item and File structure handling
- Metadata extraction

**Applicable to VOLNA:**
- Reference for Internet Archive integration
- May be usable if license permits

---

## 2. Music Source APIs

### 2.1 Jamendo API ✅
**URL:** https://developer.jamendo.com/v3.0/docs

**Features:**
- 500,000+ Creative Commons tracks
- 40,000+ artists from 150+ countries
- Search, browse, radios
- Free for non-commercial use
- Requires API client ID

**Implementation Priority:** HIGH
**License Model:** Free for non-commercial, CC-licensed music
**Rate Limits:** To be determined from API docs
**Audio Formats:** MP3, OGG

**VOLNA Integration Plan:**
- Register for API client ID
- Implement search provider
- Stream audio directly from Jamendo CDN
- Cache artwork and metadata
- Support download for CC-licensed tracks

### 2.2 Internet Archive Audio API ✅
**URL:** https://archive.org/developers/

**Features:**
- 13M+ audio recordings
- Advanced search API
- Metadata API
- Various collections (Live Music Archive, 78rpm, opensource_audio, etc.)
- Public domain and various open licenses

**Implementation Priority:** HIGH
**License Model:** Varies by item, many public domain
**Rate Limits:** Generous, documented in API
**Audio Formats:** MP3, FLAC, OGG, various

**VOLNA Integration Plan:**
- Use Advanced Search API for queries
- Filter by audio mediatype
- Check license field for each item
- Stream from direct file URLs
- Display license information

### 2.3 LRCLIB ✅
**URL:** https://lrclib.net/docs.txt

**Features:**
- Synchronized lyrics (LRC format)
- Plain lyrics
- Word-level sync support (hasWordSync)
- No API key required (optional registration for higher limits)
- FTS-backed search
- Proof-of-work publishing system

**Implementation Priority:** HIGH
**Rate Limits:**
- Generic: ~45 req/min per IP
- Identified: ~90 req/min per IP
- Registered app: ~180 req/min per IP + ~6000 req/min app-wide

**VOLNA Integration Plan:**
- Use v2 search endpoint for lightweight queries
- Fetch full lyrics by ID when needed
- Implement User-Agent identification
- Support synchronized and plain lyrics display
- Auto-scroll synchronized lyrics

### 2.4 MusicBrainz API ✅
**URL:** https://musicbrainz.org/ws/2/

**Features:**
- Open music encyclopedia
- Artist, release, recording, work metadata
- ISRC, genre tags
- Relationship graphs
- Cross-platform ID resolution (Spotify, Discogs, Wikidata)
- No API key required (User-Agent required)

**Implementation Priority:** MEDIUM
**Rate Limits:** 1 request per second for automated queries
**Use Case:** Metadata enrichment, not audio source

**VOLNA Integration Plan:**
- Use for metadata normalization
- Artist/album information enrichment
- ISRC-based track matching for deduplication
- Genre information
- NOT an audio source (metadata only)

### 2.5 Navidrome / OpenSubsonic (Optional User Source) ✅
**Spec:** https://opensubsonic.netlify.app/

**Features:**
- User's personal music library
- Self-hosted server
- Subsonic/OpenSubsonic API compatibility
- Full streaming capabilities

**Implementation Priority:** MEDIUM
**License Model:** User's own content

**VOLNA Integration Plan:**
- Optional provider (not required for basic functionality)
- Allow users to configure their own Navidrome server
- Use SwiftSonic library or similar for API communication
- Store server credentials in Keychain

### 2.6 YouTube Music Integration (⚠️ Requires Careful Approach)
**Status:** RESEARCH REQUIRED

**Considerations:**
- InnerTube API is undocumented/unofficial
- Must comply with YouTube ToS
- No DRM circumvention
- Authentication required
- May be restricted to metadata only

**Implementation Decision:** 
- Start WITHOUT YouTube Music integration
- Focus on fully open/legal sources first
- If added later, ensure full ToS compliance
- Consider metadata-only integration (no audio streaming)

---

## 3. Technical Stack

### 3.1 Core Technologies
- **Language:** Swift 6
- **UI Framework:** SwiftUI
- **Minimum iOS:** 17.0 (verify with latest Xcode 16+ requirements)
- **Audio:** AVFoundation, AVPlayer, AVAudioSession
- **Networking:** URLSession
- **Concurrency:** Swift Concurrency (async/await, actors)

### 3.2 Background Audio Requirements
- AVAudioSession with `.playback` category
- Background mode capability: Audio, AirPlay, and Picture in Picture
- MPNowPlayingInfoCenter for metadata
- MPRemoteCommandCenter for controls
- Interruption handling (phone calls, Siri)

### 3.3 Persistence Strategy
- **User Preferences:** UserDefaults
- **Library Data:** JSON files in Documents directory
- **Cache:** FileManager-managed cache directory
- **Secure Storage:** Keychain (for optional Navidrome credentials)

**No Database:** Per requirements, NO SQLite, Core Data, SwiftData, Realm

### 3.4 Project Generation
- **Tool:** XcodeGen
- **Configuration:** project.yml in root
- **Dependencies:** Swift Package Manager

---

## 4. Architecture Design

### 4.1 Module Structure
```
VOLNA/
├── App/                      # App entry point, main views
├── Core/                     # Core utilities, extensions
├── Domain/                   # Domain models (Track, Artist, Album, etc.)
├── Data/                     # Data layer (repositories, storage)
├── Providers/                # Music provider implementations
│   ├── MusicProvider.swift   # Protocol
│   ├── JamendoProvider.swift
│   ├── InternetArchiveProvider.swift
│   ├── NavidromeProvider.swift (optional)
│   └── ProviderRegistry.swift
├── Services/                 # Business logic services
│   ├── AudioEngine/          # Audio playback
│   ├── SearchService/        # Multi-provider search
│   ├── LibraryService/       # Local library management
│   ├── CacheService/         # Cache management
│   └── LyricsService/        # Lyrics fetching (LRCLIB)
├── Features/                 # Feature modules
│   ├── Home/
│   ├── Search/
│   ├── Artist/
│   ├── Album/
│   ├── Player/
│   ├── Lyrics/
│   ├── Library/
│   └── Settings/
├── DesignSystem/             # Design system components
│   ├── Colors/
│   ├── Typography/
│   ├── Components/
│   └── Assets/
└── Resources/                # Assets, localization
```

### 4.2 MusicProvider Protocol
```swift
protocol MusicProvider: Actor {
    var id: String { get }
    var name: String { get }
    var capabilities: ProviderCapabilities { get }
    
    func search(query: String, type: SearchType) async throws -> [Track]
    func resolveStream(for track: Track) async throws -> StreamSource?
    func fetchArtist(id: String) async throws -> Artist?
    func fetchAlbum(id: String) async throws -> Album?
}

struct ProviderCapabilities {
    let supportsSearch: Bool
    let supportsStreaming: Bool
    let supportsArtwork: Bool
    let supportsAlbums: Bool
    let supportsArtists: Bool
    let supportsDownload: Bool
}
```

### 4.3 Domain Models
```swift
struct Track: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let artworkURL: URL?
    let duration: TimeInterval?
    let providerID: String
    let sourceID: String
    let isrc: String?
    let explicit: Bool
    let availableStreams: [StreamSource]
}

struct StreamSource: Codable {
    let providerID: String
    let streamURL: URL
    let format: AudioFormat
    let bitrate: Int?
    let availability: Availability
}

struct Artist: Identifiable, Codable {
    let id: String
    let name: String
    let artworkURL: URL?
    let biography: String?
}

struct Album: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let artworkURL: URL?
    let releaseDate: Date?
    let tracks: [Track]
}
```

---

## 5. Design System

### 5.1 Color Palette
**Inspiration:** Yandex Music (dark theme with purple/blue accents)

```swift
// Primary Colors
- Background: Deep black (#000000) and graphite (#1A1A1A)
- Surface: Dark gray (#2A2A2A)
- Accent Primary: Deep purple (#8B5CF6)
- Accent Secondary: Blue (#3B82F6)
- Accent Tertiary: Magenta (#EC4899)

// Text Colors
- Primary: White (#FFFFFF)
- Secondary: Light gray (#A0A0A0)
- Tertiary: Medium gray (#6B7280)

// Gradients
- Hero Gradient: Purple to blue
- Accent Gradient: Blue to magenta
```

### 5.2 Typography
**System Fonts:** SF Pro (system default)

- Display: SF Pro Display (Large titles, hero text)
- Text: SF Pro Text (Body, UI elements)
- Rounded: SF Pro Rounded (Optional for playful elements)

**Scale:**
- Hero: 34pt, Bold
- Title 1: 28pt, Bold
- Title 2: 22pt, Semibold
- Title 3: 20pt, Semibold
- Headline: 17pt, Semibold
- Body: 17pt, Regular
- Callout: 16pt, Regular
- Subheadline: 15pt, Regular
- Footnote: 13pt, Regular
- Caption: 12pt, Regular

### 5.3 Component Library
- **Cards:** Rounded corners (12pt), subtle shadows, gradient overlays
- **Buttons:** Pill-shaped primary, ghost secondary, icon buttons
- **Navigation:** Bottom tab bar with 4-5 tabs, custom styling
- **Mini Player:** Floating above tab bar, swipe gesture to expand
- **Full Player:** Modal presentation, blur background, large artwork

### 5.4 Assets Sourcing
**Icons:** SF Symbols (built-in) + custom icons if needed
**Fonts:** SF Pro (system)
**Artwork:** From music providers (dynamic)
**App Icon:** Custom design required
**Launch Screen:** VOLNA branding

**Design Tools:** Figma for mockups (optional), direct SwiftUI implementation

---

## 6. GitHub Actions CI/CD

### 6.1 Required Workflows

#### Build Workflow (.github/workflows/build.yml)
- Trigger: Push to main, PR
- Steps:
  1. Checkout code
  2. Setup Xcode (macOS runner)
  3. Install XcodeGen
  4. Generate Xcode project
  5. Resolve Swift packages
  6. Build for iOS
  7. Run tests

#### IPA Workflow (.github/workflows/ipa.yml)
- Trigger: Tag push (v*.*.*)
- Steps:
  1. Checkout code
  2. Setup Xcode
  3. Install XcodeGen
  4. Generate project
  5. Import signing certificate (from secrets)
  6. Import provisioning profile (from secrets)
  7. Archive
  8. Export IPA
  9. Upload artifact

#### Release Workflow (.github/workflows/release.yml)
- Trigger: Tag push
- Steps:
  1. Run IPA workflow
  2. Create GitHub Release
  3. Upload IPA to release
  4. Generate release notes

### 6.2 GitHub Secrets Required
- `BUILD_CERTIFICATE_BASE64`: Base64-encoded .p12 certificate
- `P12_PASSWORD`: Certificate password
- `BUILD_PROVISION_PROFILE_BASE64`: Base64-encoded provisioning profile
- `KEYCHAIN_PASSWORD`: Temporary keychain password
- `APPLE_TEAM_ID`: Apple Developer Team ID

**Note:** Documentation needed for users to add their own certificates

---

## 7. Implementation Roadmap

### Stage 1: Foundation (CURRENT)
- [x] Research Open Source projects
- [x] Document music source APIs
- [x] Define architecture
- [ ] Create project structure
- [ ] Setup XcodeGen configuration
- [ ] Setup GitHub Actions basic workflow
- [ ] Create domain models

### Stage 2: Design System
- [ ] Define color system
- [ ] Create typography scale
- [ ] Build reusable components (buttons, cards, navigation)
- [ ] Design app icon
- [ ] Create launch screen

### Stage 3: Core UI Screens
- [ ] Main tab navigation
- [ ] Home screen (empty state)
- [ ] Search screen (UI only)
- [ ] Library screen (UI only)
- [ ] Settings screen (UI only)

### Stage 4: Audio Engine
- [ ] Integrate AudioStreaming or build custom player
- [ ] AVAudioSession configuration
- [ ] Background playback
- [ ] Now Playing Center integration
- [ ] Remote Command Center
- [ ] Queue management
- [ ] Playback state persistence

### Stage 5: Music Providers
- [ ] MusicProvider protocol
- [ ] JamendoProvider implementation
- [ ] InternetArchiveProvider implementation
- [ ] Provider registry and capability checking

### Stage 6: Unified Search
- [ ] SearchService with multi-provider support
- [ ] Parallel search execution
- [ ] Result deduplication algorithm
- [ ] Result ranking
- [ ] Search UI integration

### Stage 7: Library & Persistence
- [ ] JSON-based library storage
- [ ] Favorites management
- [ ] Playlist creation/editing
- [ ] Playback history
- [ ] State restoration

### Stage 8: Player UI
- [ ] Mini player component
- [ ] Full-screen player
- [ ] Artwork display with gradients
- [ ] Queue view
- [ ] Playback controls

### Stage 9: Lyrics Integration
- [ ] LRCLIB service implementation
- [ ] Synchronized lyrics display
- [ ] Auto-scroll
- [ ] Plain lyrics fallback
- [ ] Lyrics UI

### Stage 10: Advanced Features
- [ ] Navidrome provider (optional)
- [ ] Artwork caching system
- [ ] Offline/cache management
- [ ] Personalization (local algorithms)
- [ ] Settings implementation

### Stage 11: Polish & Testing
- [ ] Unit tests for services
- [ ] Integration tests for providers
- [ ] UI tests
- [ ] Performance optimization
- [ ] Bug fixes
- [ ] Localization (Russian primary, English secondary)

### Stage 12: Release Preparation
- [ ] Complete documentation
- [ ] Third-party licenses document
- [ ] Privacy policy
- [ ] Build instructions
- [ ] Release IPA via GitHub Actions
- [ ] TestFlight distribution (optional)

---

## 8. Third-Party Dependencies

### Direct Dependencies (via SPM)
1. **AudioStreaming** (MIT) - https://github.com/dimitris-c/AudioStreaming
   - Purpose: Audio playback engine
   - License: MIT
   
2. **(Optional) SwiftSonic** - If available for Navidrome integration
   - Purpose: Subsonic API client
   - License: TBD

### Indirect Dependencies
- None beyond standard iOS frameworks

### License Compliance
All dependencies will be documented in `Documentation/THIRD_PARTY_LICENSES.md` with:
- Library name
- Version
- License type
- Copyright notice
- Link to original repository

---

## 9. Legal & Privacy Considerations

### 9.1 Music Source Compliance
- ✅ Jamendo: Use within API Terms (non-commercial or licensed)
- ✅ Internet Archive: Respect per-item licenses
- ✅ LRCLIB: Follow API guidelines, implement User-Agent, respect rate limits
- ✅ MusicBrainz: Implement rate limiting (1 req/sec), proper User-Agent
- ⚠️ YouTube Music: NOT IMPLEMENTED initially due to ToS concerns

### 9.2 No Censorship Policy
- Display explicit content without filtering
- Show accurate metadata from sources
- Respect source licensing, NOT self-censorship
- Do NOT modify artist/track names

### 9.3 Privacy
- No user accounts required
- No data collection
- No analytics
- No remote logging
- All data stays on device
- Optional Navidrome credentials stored in Keychain only

### 9.4 License Choice for VOLNA
**Recommendation:** MIT or Apache 2.0
- Allows commercial use
- Compatible with all researched dependencies
- Simple and permissive
- Widely accepted

---

## 10. Risk Assessment

### High Risk
- **YouTube Music integration:** Could violate ToS → MITIGATED by NOT implementing
- **Copyright violations:** → MITIGATED by using only licensed/open sources

### Medium Risk
- **API rate limits:** → MITIGATED by implementing proper rate limiting, caching
- **API changes/deprecation:** → MITIGATED by modular provider architecture
- **Background audio issues:** → MITIGATED by following Apple best practices

### Low Risk
- **Performance with large libraries:** → MITIGATED by pagination, lazy loading
- **Build complexity:** → MITIGATED by XcodeGen, clear documentation

---

## 11. Success Criteria

### Minimum Viable Product (MVP)
- ✅ Native Swift/SwiftUI iOS app
- ✅ 2+ working music providers (Jamendo + Internet Archive)
- ✅ Unified search with deduplication
- ✅ Full audio playback with background support
- ✅ Lock screen controls
- ✅ Basic library (favorites, history)
- ✅ Mini player + full player
- ✅ Queue management
- ✅ Russian localization
- ✅ Automatic IPA build via GitHub Actions

### Full Release (v1.0)
- MVP +
- ✅ Lyrics integration (LRCLIB)
- ✅ Playlist management
- ✅ Artwork caching
- ✅ Local recommendations
- ✅ Settings screen
- ✅ App icon and branding
- ✅ Comprehensive documentation

### Future Enhancements (Post-v1.0)
- Navidrome provider
- Additional music sources
- Equalizer
- CarPlay support
- Widgets
- Apple Watch companion

---

## 12. References

### Documentation
- [LRCLIB API Docs](https://lrclib.net/docs.txt)
- [Internet Archive API](https://archive.org/developers/)
- [Jamendo API](https://developer.jamendo.com/v3.0/docs)
- [MusicBrainz API](https://musicbrainz.org/doc/MusicBrainz_API)
- [OpenSubsonic Spec](https://opensubsonic.netlify.app/)

### Repositories
- [Cassette](https://github.com/CassetteLab/cassette)
- [Trop](https://github.com/SwiftyMedia/Trop)
- [AudioStreaming](https://github.com/dimitris-c/AudioStreaming)
- [Navidrome](https://github.com/navidrome/navidrome)

### Apple Documentation
- [AVFoundation](https://developer.apple.com/av-foundation/)
- [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [MediaPlayer Framework](https://developer.apple.com/documentation/mediaplayer)
- [Background Execution](https://developer.apple.com/documentation/avfoundation/media_playback/configuring_your_app_for_media_playback)

---

**End of Research Document**
