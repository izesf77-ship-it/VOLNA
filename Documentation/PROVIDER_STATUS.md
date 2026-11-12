# VOLNA - Music Provider Status

**Last Updated:** November 12, 2026

---

## Overview

VOLNA currently supports **3 music providers** with plans to expand:

| Provider | Status | Search | Audio | Russian | License Check |
|----------|--------|--------|-------|---------|---------------|
| **Jamendo** | ✅ Active | ✅ | ⏳ | Limited | ✅ |
| **Internet Archive** | ✅ Active | ✅ | ⏳ | ✅ Good | ✅ |
| **Wikimedia Commons** | ✅ Active | ✅ | ⏳ | ✅ Good | ✅ |

**Legend:**
- ✅ Implemented and working
- ⏳ Implemented, needs testing
- ❌ Not working
- 🔨 In progress
- 📋 Planned

---

## 1. Jamendo ✅

### Status
- **Implementation:** Complete
- **API Key:** Configured (Client ID: b488b912)
- **Last Tested:** November 12, 2026
- **Search:** Working
- **Audio Playback:** Needs device testing

### Capabilities
- ✅ Track search
- ✅ Album search (implemented)
- ✅ Artist search (implemented)
- ✅ Artwork (600x600)
- ✅ Direct MP3 streams (320kbps)
- ✅ License information (all CC)
- ❌ Lyrics

### API Details
- **Base URL:** https://api.jamendo.com/v3.0
- **Authentication:** Client ID only (public read access)
- **Rate Limits:** Unknown (to be tested)
- **Format:** JSON
- **Audio Format:** MP3 (320kbps)

### Russian Content
- **Availability:** Limited
- **Strategy:** Search with Russian keywords and transliteration
- **Expected Results:** ~100-500 tracks

### License Model
- **All tracks:** Creative Commons licensed
- **Types:** CC-BY, CC-BY-SA, CC-BY-ND, CC-BY-NC, CC-BY-NC-SA, CC-BY-NC-ND
- **Commercial Use:** Varies by track
- **Attribution:** Required
- **Download:** Allowed for most tracks

### Known Issues
- API key should not be hardcoded in production
- Rate limit handling needs testing
- No server-side filtering for Russian content

### Sample Search Queries
```
Mияги
Russian rock
Русская музыка
Independent Russian artists
```

---

## 2. Internet Archive ✅

### Status
- **Implementation:** Complete
- **API Key:** Not required
- **Last Tested:** November 12, 2026
- **Search:** Working
- **Audio Playback:** Needs testing

### Capabilities
- ✅ Audio search
- ✅ Metadata retrieval
- ✅ Direct file URLs
- ✅ Multiple formats (MP3, OGG, FLAC)
- ✅ License checking
- ✅ Language filtering
- ❌ Albums
- ❌ Artist pages

### API Details
- **Base URL:** https://archive.org
- **Authentication:** None required
- **Rate Limits:** Be respectful, no official limit
- **Format:** JSON
- **Audio Formats:** MP3, OGG, FLAC, M4A, WAV

### Russian Content
- **Availability:** Good (estimated 1000+ tracks)
- **Collections:**
  - Live Music Archive
  - Community Audio
  - Russian folk music
  - Classical recordings
  - Historical archives
- **Language Filter:** Supports `language:Russian` and `language:ru`

### License Model
- **Mixed licenses:** CC0, CC-BY, CC-BY-SA, Public Domain, Other
- **Verification:** Checks `licenseurl` field in metadata
- **Attribution:** Varies by item
- **Download:** Most items allow download

### Implementation Details
```swift
// Search query structure
(title:(query) OR creator:(query)) AND mediatype:audio AND language:Russian

// Metadata endpoint
https://archive.org/metadata/{identifier}

// File URL pattern
https://archive.org/download/{identifier}/{filename}

// Thumbnail
https://archive.org/services/img/{identifier}
```

### Known Issues
- Metadata quality varies
- Some items may have incomplete license information
- Not all audio files are music (may include audiobooks, lectures)
- Need to filter non-music content

### Sample Search Queries
```
Русские народные песни
Russian folk music
Tchaikovsky
Rachmaninoff
Soviet music archive
```

---

## 3. Wikimedia Commons ✅

### Status
- **Implementation:** Complete
- **API Key:** Not required
- **Last Tested:** November 12, 2026
- **Search:** Working
- **Audio Playback:** Needs testing

### Capabilities
- ✅ Audio file search
- ✅ File metadata
- ✅ Direct URLs
- ✅ License information
- ✅ Multiple formats
- ❌ Albums
- ❌ Artists
- ❌ Artwork (audio files)

### API Details
- **Base URL:** https://commons.wikimedia.org/w/api.php
- **Authentication:** None required
- **Rate Limits:** Be respectful, use User-Agent
- **Format:** JSON
- **Audio Formats:** MP3, OGG, FLAC, WAV

### Russian Content
- **Availability:** Good (estimated 500+ files)
- **Categories:**
  - Category:Russian_music
  - Category:Russian_folk_music
  - Category:Russian_classical_music
  - Category:Audio_files_in_Russian
- **Content Types:**
  - Folk songs
  - Classical recordings
  - Public domain music
  - Educational recordings

### License Model
- **Primary:** CC-BY, CC-BY-SA, CC0, Public Domain
- **Verification:** MediaWiki extmetadata provides license info
- **Attribution:** Required for CC-BY licenses
- **Download:** All files downloadable

### Implementation Details
```swift
// Search
action=query&list=search&srsearch=filetype:audio Russian music

// File info
action=query&prop=imageinfo&iiprop=url|size|mime|extmetadata|duration

// Direct URL provided in response
```

### Known Issues
- File titles may not be music-friendly (technical names)
- Mixed content (music, speeches, sound effects)
- Requires filtering for actual music
- Some files are very short (samples)

### Sample Search Queries
```
Russian folk song
Русская народная песня
Russian classical music
Soviet anthem (public domain versions)
```

---

## Planned Providers 📋

### 4. Muxiv.com ⏳
- **Status:** Researching
- **Task:** Determine if public API exists
- **Potential:** CC0/Public Domain focus

### 5. Free Music Archive (FMA) ⏳
- **Status:** API status unclear
- **Last known:** Had public API
- **Action:** Verify current availability

### 6. ccMixter ⏳
- **Status:** To investigate
- **Focus:** CC remixes and original music

### 7. Musopen ⏳
- **Status:** To investigate
- **Focus:** Public domain classical music
- **Russian Content:** High potential (Russian composers)

---

## Testing Checklist

### Per-Provider Tests
- [ ] Search returns results
- [ ] Audio URLs are valid
- [ ] Audio URLs are accessible (HTTP 200)
- [ ] Content-Type is audio/*
- [ ] Files are playable on iOS
- [ ] License info is correct
- [ ] Attribution is preserved
- [ ] Rate limits respected
- [ ] Error handling works
- [ ] Timeout handling works

### Russian Content Tests
- [ ] Search with Cyrillic query
- [ ] Search with transliterated query
- [ ] Language filter works
- [ ] Results are actually Russian
- [ ] At least 10 tracks per provider

### Integration Tests
- [ ] Multi-provider search works
- [ ] Deduplication works
- [ ] Results merge correctly
- [ ] One provider failure doesn't break others
- [ ] Provider status monitoring works

---

## Performance Benchmarks

### Target Metrics
- **Search latency:** < 2 seconds per provider
- **Total search time:** < 5 seconds (parallel)
- **Audio start time:** < 1 second
- **Memory usage:** < 50MB for provider operations

### Current Status
⏳ Not yet benchmarked (requires device testing)

---

## Error Scenarios

### Handled Errors
- ✅ Network timeout
- ✅ HTTP 404 (Not Found)
- ✅ HTTP 429 (Rate Limit)
- ✅ Invalid JSON response
- ✅ Missing audio file
- ✅ Invalid audio URL

### Edge Cases
- Provider temporarily offline
- Search returns no results
- Audio file deleted/moved
- License information missing
- Malformed metadata

---

## Usage Examples

### Search Flow
```
User: "Мияги"
↓
SearchService queries 3 providers in parallel:
├─ Jamendo: 2 results
├─ Internet Archive: 5 results
└─ Wikimedia Commons: 0 results
↓
Deduplication: 7 unique tracks
↓
Display results with source badges
```

### Playback Flow
```
User selects track
↓
PlayerService resolves stream URL
↓
Check availability (HEAD request)
↓
Start AVPlayer with URL
↓
Update Now Playing info
↓
Show player UI
```

---

## Maintenance

### Regular Tasks
- **Weekly:** Check provider API status
- **Monthly:** Verify sample searches still work
- **Quarterly:** Review license compliance
- **Yearly:** Check for API changes

### Monitoring
- Provider success/failure rates
- Average search latency
- Audio playback success rate
- User-reported issues

---

## Security & Privacy

### Data Handling
- ✅ No user data sent to providers
- ✅ No tracking or analytics
- ✅ Search queries not logged
- ✅ Playback history stored locally only

### API Keys
- ✅ Jamendo Client ID can be public (read-only)
- ❌ Client Secret must NOT be in IPA
- ✅ No other providers require keys

---

## Legal Compliance

### License Verification
All providers check and store:
- License type
- License URL
- Attribution requirements
- Commercial use permissions
- Derivative work permissions

### User Responsibilities
- Check individual track licenses
- Provide attribution when required
- Respect usage restrictions
- Don't redistribute without permission

---

**Status Summary:**
- ✅ 3 providers implemented
- ⏳ Device testing pending
- ✅ License compliance implemented
- ✅ Russian content support added
- 📋 4 additional providers planned

**Next Actions:**
1. Test on real device
2. Verify audio playback
3. Benchmark performance
4. Document any issues
5. Expand to additional providers

---

*Last reviewed: November 12, 2026*
