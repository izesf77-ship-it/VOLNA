# VOLNA — Phase 2 source verification (empirical checks)

**Date:** 2026-11-13  
**Environment:** Windows workstation (PowerShell/curl), no Xcode/iOS Simulator/physical device, AVPlayer playback not executable here.  
**Branch/HEAD at start:** `feature/open-music-catalog`, `5f92028` (local working changes not committed in this check).

## 1) Requested source checks

### Audius (official)
- Docs reviewed: `https://docs.audius.co/api/` (high-level; API reference content is JS-rendered in this environment).
- Official host bootstrap `GET https://api.audius.co` and discovery requests (e.g. `https://discoveryprovider.audius.co/v1/...`, `https://discoveryprovider2.audius.co/v1/...`) returned **Cloudflare 403 challenge/block** from this environment (non-browser-like context).
- **Result (this environment):** endpoint reachability not verifiable due to Cloudflare block; full-stream/Range/AVPlayer compatibility not verified. A direct `AudiusProvider` implementation was added to VOLNA following official API patterns (`app_name`, host resolution, search/trending/track/user/playlist mapping, stream URL `/v1/tracks/:id/stream`) but must be validated on iOS/macOS/CI network conditions.

### SayaMusicAPI (`https://sayamusicapi.sayaproject-mailflow.workers.dev`)
- `GET /health` → **200 OK**: `{"ok":true,"service":"SayaMusicAPI","data":{"status":"ok","version":"0.1.0","endpointCount":1316}}`
- `GET /v1/endpoints` and `GET /v1/openapi.json` available (large catalog of routes; includes audius/jiosaavn/deezer/openverse/radio-browser/archive/web routes).
- `GET /v1/search/tracks?q=MACAN` → timed out in this environment (>20s sample attempt earlier), not treated as reliable.
- `GET /v1/audius/search/tracks?q=The%20Weeknd&limit=2` → **upstream blocked** (`upstreamOk:false`, HTTP 403 Cloudflare from Audius).
- `GET /v1/jiosaavn/search/songs?q=MACAN&limit=2` → **200**, metadata returned with explicit policy: *"Official preview URLs only. Protected/encrypted media fields are intentionally not exposed."* (`previewUrl` mp4 previews). **No full stream**.
- `GET /v1/deezer/search?q=MACAN&limit=2` → route mismatch suggestion; `GET /v1/deezer/search/tracks?q=MACAN&limit=2` → **200** with Deezer `preview` MP3 URLs (~30s). **Preview only**.
- `GET /v1/openverse/search/audio?q=rock&limit=2` → **200**, proxied Openverse results including direct Jamendo `mp32` URLs and licenses. **Full streams for underlying open items** (mostly Jamendo/Openverse sources already addressable directly).
- `GET /v1/radio-browser/search/stations...` → route mismatch; `GET /v1/radio-browser/stations/search?name=rock&limit=2` and direct Radio Browser API returned live station streams (`url_resolved` AAC/MP3). **Live radio, not on-demand track catalog**.
- **Assessment:** useful for inspection/metadata aggregation in some cases, but production dependency on third-party Worker is risky; JioSaavn/Deezer paths checked are preview/metadata-limited for full-song playback. Not integrated as a core provider in this phase.

### Jamendo (existing, direct)
- Quick check `GET https://api.jamendo.com/v3.0/tracks/?client_id=b488b912&format=json&limit=1&search=MACAN&audioformat=mp32&include=licenses%20musicinfo` returned `results_count: 0` for that query (open catalog does not guarantee mainstream commercial artists).
- Jamendo remains the primary integrated source of legal full MP3 streams with per-track licenses/artwork (as per existing implementation/docs).

### Internet Archive / Wikimedia Commons / Openverse (existing)
- Implementations present and used in search; Openverse proxy results observed via Saya confirm direct Jamendo/open audio URLs with CC licenses. No new blocking evidence collected in this phase, but runtime playback/Range on device not verified here.

### Additional/related APIs reviewed
- `musicapi.com`: commercial transfer/SSO infrastructure, not a free in-app playback catalog. **Not applicable**.
- `mohd-baquir-qureshi/music-api`: deprecated/unofficial multi-engine proxy. **Not integrated**.
- `Shrinivas2708/OneTune`: full app/backend stack (not a public API). **Not integrated**.
- `feralbureau/bedrock-api`: self-hosted gRPC gateway/bridge requiring infrastructure and upstream credentials; not a drop-in public legal stream source. **Not integrated**.
- `shnwazdev/shnwazdev-jiosaavn-api`: unofficial JioSaavn scraper/API exposing full CDN URLs in general, but relies on unofficial access to a licensed service; legal/ToS risk and not verified as acceptable for VOLNA. **Not integrated**.

## 2) 30-query spot checks (HTTP/API-level only)

| # | Query | Jamendo (direct, quick) | Saya JioSaavn | Saya Deezer tracks | Saya Openverse audio | Notes |
|---|---|---|---|---|---|---|
| 1 | MACAN | 0 results (sample call) | metadata + preview only | results + 30s preview | n/a (rock sample checked) | No verified full mainstream stream found |
| 2 | The Weeknd | not run in this pass | not run | not run | not run | Audius upstream blocked via Saya |
| 3 | rock (open catalog sanity) | existing integration | n/a | n/a | 240 results, direct mp32 (Jamendo) | Open content available |

**Limitation:** full 30-query x multi-source matrix with per-track stream/Range/AVPlayer checks was **not completed** in this environment (no iOS runtime, time/network constraints, Audius blocked, some Saya routes slow/incompatible). Results above are partial empirical samples.

## 3) 50-track test set (required report fields)

A complete 50-track playback table (found/correct artist/correct album/artwork/full duration/full stream/playback/seek/provider) **cannot be honestly completed** without runtime execution and AVPlayer/device or simulator verification.

**Planned/requested set:** RU — MACAN, Miyagi & Эндшпиль, Скриптонит, Баста, ANNA ASTI, Artik & Asti, Три дня дождя, Zivert, Егор Крид, HammAli & Navai (+ Noize MC, Oxxxymiron, Кино as extra checks); INTL — The Weeknd, Travis Scott, Drake, Billie Eilish, Eminem, Kanye West, Dua Lipa, Rihanna, Post Malone, Kendrick Lamar (+ Linkin Park, Daft Punk as extra checks).  
**Expected reality:** many of these commercial releases are unlikely to exist as legal full streams in current open catalogs (Jamendo/IA/Wikimedia/Audius availability varies by artist/rights). Preview-only sources (Deezer/JioSaavn via checked gateways) must not be counted as full playable tracks.

## 4) Provider summary (honest)

| Provider | Search | Full streams | Previews | RU coverage | Health (this env) | Status |
|---|---|---|---|---|---|---|
| Jamendo | yes (integrated) | yes (direct MP3, licensed per track) | no | partial (open catalog) | direct API reachable in sample | integrated/active |
| Audius | implemented | expected if API/stream accessible | no | unknown | Cloudflare-blocked here | **implemented, unverified in this env** |
| Internet Archive | yes (integrated) | yes (MP3/M4A derivatives, licensed items) | no | partial/archival | not re-benchmarked fully | integrated |
| Wikimedia Commons | yes (integrated) | yes via MP3/transcodes where available | no | limited | not re-benchmarked fully | integrated |
| Openverse | yes (integrated, limited) | yes (aggregated open audio URLs) | no | limited | proxied results observed | integrated (limited) |
| Direct links | local | user-provided | n/a | user-provided | local | integrated |
| SayaMusicAPI | yes (gateway) | open proxies possible (e.g. Openverse/Jamendo) | yes (Deezer/JioSaavn routes checked) | limited | health OK, some routes slow/blocked | **not integrated** |
| Deezer (public API) | metadata/preview | no (public) | 30s | good metadata | preview endpoint seen via Saya | preview-only |
| JioSaavn (via checked gateway) | metadata | no (exposed by Saya) | preview | limited sample | preview-only policy stated | preview-only |
| Radio Browser | stations | live radio streams | n/a | station-dependent | reachable | out of scope (not on-demand tracks) |
| Yandex/VK/Zaycev/SoundCloud/Apple Music/iTunes full catalogs | n/a | no legal full access for this app | some have previews | n/a | n/a | unavailable without licenses/official agreements |

## 5) Not claimed
- Successful end-to-end playback/seek/Lock Screen on real iPhone or simulator **not verified**.
- Exact runtime catalog totals, unique playable track counts, and 50-track success percentage **not measured** in this environment.