# VOLNA Stage 2 - Open Music Ecosystem Research

**Date:** November 12, 2026  
**Objective:** Expand VOLNA to support multiple open music sources with focus on Russian music catalog

---

## Current Project Audit

### ✅ Working Components (Stage 1)
- **Domain Models:** Complete (Track, Album, Artist, Playlist, StreamSource)
- **MusicProvider Protocol:** Defined and ready
- **ProviderRegistry:** Working registry system
- **JamendoProvider:** Basic structure exists (needs API key configuration)
- **SearchService:** Multi-provider search with deduplication
- **PlayerService:** AVPlayer integration (needs testing)
- **LyricsService:** LRCLIB integration complete
- **LibraryService:** JSON-based local storage
- **UI Screens:** Home, Search, Library, Settings (basic implementation)
- **Design System:** Colors and components defined

### ⚠️ Needs Work
- **JamendoProvider:** Hardcoded API key placeholder
- **Audio Playback:** Not tested with real streams
- **Provider Testing:** No integration tests yet
- **Russian Music:** No specific discovery system
- **License Tracking:** Not implemented in Track model

### ❌ Missing Components
- **InternetArchiveProvider:** Not implemented
- **WikimediaCommonsProvider:** Not implemented
- **DirectMusicProvider:** Not implemented
- **License verification system:** Not implemented
- **Russian music filtering:** Not implemented
- **Provider status monitoring:** Not implemented

---

## Music Source Research

### 1. Internet Archive ✅ APPROVED

**URL:** https://archive.org  
**API:** https://archive.org/developers/  
**License:** Varies per item (check metadata)

#### API Capabilities
- Advanced Search API for audio items
- Metadata API for detailed information
- Direct file URLs available
- Filter by mediatype:audio
- Language filtering available
- Collection filtering

#### Russian Music Potential
- Live Music Archive
- Community Audio
- Audio Books & Poetry (some Russian content)
- Folk Music collections
- Historical recordings
- Classical music recordings

#### Implementation Strategy
```swift
// Search endpoint
https://archive.org/advancedsearch.php?
  q=(title:{query}+OR+creator:{query})+AND+mediatype:audio+AND+language:Russian
  &fl=identifier,title,creator,date,downloads,format,item_size
  &output=json
  &rows=20

// Metadata endpoint  
https://archive.org/metadata/{identifier}

// File URL pattern
https://archive.org/download/{identifier}/{filename}
```

#### License Checking
- Check `licenseurl` field in metadata
- Check `rights` field
- Verify `publicdate` and copyright status
- Store attribution requirements

---

### 2. Wikimedia Commons ✅ APPROVED

**URL:** https://commons.wikimedia.org  
**API:** MediaWiki API  
**License:** Free licenses (CC, PD)

#### API Capabilities
- File search via MediaWiki API
- Category browsing
- Direct file URLs
- License information in metadata
- Multi-language support

#### Russian Music Content
- Category:Russian_music
- Category:Russian_folk_music
- Category:Russian_classical_music
- Category:Audio_files_in_Russian
- Public domain recordings
- Folk songs
- Historical archives

#### Implementation Strategy
```swift
// Search for audio files
https://commons.wikimedia.org/w/api.php?
  action=query
  &list=search
  &srsearch=filetype:audio+Russian+music
  &srnamespace=6
  &format=json

// Get file info and URL
https://commons.wikimedia.org/w/api.php?
  action=query
  &prop=imageinfo
  &iiprop=url|size|mime|extmetadata
  &titles=File:{filename}
  &format=json
```

#### License Verification
- Check `extmetadata.LicenseShortName`
- Check `extmetadata.UsageTerms`
- Store `extmetadata.Artist` for attribution
- Verify commercial use permissions

---

### 3. Jamendo ✅ CONFIGURED

**URL:** https://www.jamendo.com  
**API:** https://developer.jamendo.com  
**License:** Creative Commons

#### Current Status
- Client ID: `b488b912`
- Implementation exists, needs key update
- 500,000+ CC-licensed tracks

#### Russian Music Discovery
Limited Russian content, but available:
- Search with Russian keywords
- Filter by language (if available)
- Browse Russian artists
- Genre filtering

#### Security Note
⚠️ **Client Secret Compromised:** The client secret `ab42a1fe99d6e61dcc57211179975aee` has been exposed. While we're using only the Client ID for public API calls (which is acceptable), the secret should be regenerated if OAuth operations are needed in the future.

---

### 4. Additional Sources (To Investigate)

#### Muxiv.com ⏳ RESEARCH NEEDED
- **Status:** Requires investigation
- **Task:** Check for public API or documented catalog access
- **Risk:** No documented public API found yet
- **Action:** Document findings if legitimate access method exists

#### Free Music Archive (FMA) ⚠️ STATUS UNCLEAR
- **URL:** https://freemusicarchive.org  
- **Status:** Previously had API, current status unknown
- **Action:** Check if API still available and terms of use

#### ccMixter ⏳ TO INVESTIGATE
- **URL:** https://ccmixter.org  
- **License:** CC remixes
- **API:** Check for availability

#### Musopen ⏳ TO INVESTIGATE
- **URL:** https://musopen.org  
**Focus:** Public domain classical music
- **Russian Content:** Possible (Tchaikovsky, Rachmaninoff, etc.)

---

## Russian Music Discovery Strategy

### Multi-Level Search Approach

1. **Search Terms (Russian)**
   - Русская музыка
   - Русские песни
   - Русский рок
   - Русский рэп
   - Народная музыка
   - Советские песни (if public domain)

2. **Search Terms (Transliterated)**
   - Russian music
   - Russian folk
   - Russian indie
   - Russian rock
   - Russkaya muzyka

3. **Artist Names (Both scripts)**
   - Cyrillic: Мияги, ДДТ, etc.
   - Latin: Miyagi, DDT, etc.

4. **Language Filters**
   - language:Russian
   - language:ru
   - lang=ru

### Track Model Extensions Needed

```swift
struct Track {
    // Existing fields...
    
    // New fields for Stage 2:
    let language: String?           // ISO 639-1 code
    let originalTitle: String?      // Original script
    let transliteratedTitle: String? // Latin script
    let license: LicenseType
    let licenseURL: URL?
    let attribution: String?
    let isStreamAllowed: Bool
    let isDownloadAllowed: Bool
    let region: String?             // Country/region
}

enum LicenseType: String, Codable {
    case cc0 = "CC0"
    case ccBy = "CC-BY"
    case ccBySa = "CC-BY-SA"
    case ccByNd = "CC-BY-ND"
    case ccByNc = "CC-BY-NC"
    case ccByNcSa = "CC-BY-NC-SA"
    case ccByNcNd = "CC-BY-NC-ND"
    case publicDomain = "Public Domain"
    case other = "Other"
    case unknown = "Unknown"
    case restricted = "Restricted"
}
```

---

## Implementation Priority

### Phase 1: Core Providers ⏰ NOW
1. ✅ Fix JamendoProvider with real API key
2. ✅ Implement InternetArchiveProvider
3. ✅ Implement WikimediaCommonsProvider
4. ✅ Update Track model with license fields
5. ✅ Create ProviderStatus monitoring

### Phase 2: Russian Discovery 🎯 NEXT
1. Add language detection
2. Implement Russian search strategies
3. Create Russian music filters
4. Add transliteration support
5. Build "Russian Music" category

### Phase 3: Testing & Verification ✅ REQUIRED
1. Test each provider with real API calls
2. Verify audio stream playback
3. Check license compliance
4. Document provider status
5. Create integration tests

### Phase 4: Additional Sources 🔮 FUTURE
1. Investigate Muxiv
2. Check Free Music Archive status
3. Explore ccMixter
4. Consider Musopen for classical

---

## Technical Considerations

### Rate Limiting
- **Jamendo:** Check current rate limits
- **Internet Archive:** Respect scraping guidelines
- **Wikimedia:** Follow API etiquette (user agent, rate limits)
- **Implementation:** Add exponential backoff

### Caching
- Cache search results (5-15 minutes)
- Cache metadata (1 hour)
- Cache artwork URLs (persistent)
- Don't cache audio streams (direct playback)

### Error Handling
- Provider offline: Continue with other providers
- Rate limit hit: Show message, retry later
- Invalid audio URL: Mark track unavailable
- Network timeout: Show retry option

### Privacy & Legal
- No user tracking
- No data collection
- Display license info
- Show attribution
- Link to original sources
- Respect robots.txt (if scraping)

---

## Success Metrics

### Minimum Viable (Stage 2)
- ✅ 3+ working providers
- ✅ At least 50 Russian music tracks discoverable
- ✅ Real audio playback working
- ✅ License information displayed
- ✅ Provider status monitoring
- ✅ Git commits pushed to GitHub

### Optimal (Stage 2+)
- 5+ providers working
- 500+ Russian tracks discoverable
- Advanced filtering (language, license, genre)
- Offline provider graceful degradation
- Comprehensive documentation

---

## Risks & Mitigation

### Risk: Limited Russian Content
- **Mitigation:** Use multiple sources, document realistic expectations
- **Action:** Clearly communicate available content to users

### Risk: API Changes
- **Mitigation:** Modular provider architecture, easy to update
- **Action:** Version checking, graceful degradation

### Risk: License Compliance
- **Mitigation:** Strict license checking, display attribution
- **Action:** Legal review of implementation

### Risk: Audio Playback Issues
- **Mitigation:** Thorough testing, format detection
- **Action:** Test with real devices and network conditions

---

## Next Steps

1. ✅ Update JamendoProvider with real client ID
2. ✅ Implement InternetArchiveProvider
3. ✅ Implement WikimediaCommonsProvider
4. ✅ Extend Track model for licenses
5. ✅ Add ProviderStatus view
6. ✅ Test real API calls
7. ✅ Commit and push to GitHub

---

**Research Completed:** November 12, 2026  
**Ready for Implementation:** ✅ YES

