# WabWay Changelog

## 1.1.0+8 — Gemini AI itinerary parsing + full offline cache + map improvements

### Gemini Flash AI parser (free tier)
- Added `lib/core/ocr/gemini_parser.dart` — sends itinerary screenshots to Gemini 1.5 Flash vision API; reads flights, hotels, trains, and reservations as structured JSON
- Added `lib/core/ocr/parse_counter.dart` — tracks daily AI parse usage against the 1,500/day free limit, persisted in SharedPreferences
- Added `lib/core/ocr/parsed_booking.dart` — unified model shared by AI and OCR parsers
- Added `lib/core/ocr/itinerary_scanner.dart` — tries Gemini first, falls back to on-device ML Kit OCR + regex
- `ParsedItineraryScreen` updated to accept `List<ParsedBooking>`, shows AI-parsed / OCR badge and remaining daily parse count
- Import sheet and incoming share screen updated to use `ItineraryScanner` — banners now show "AI-parsed" vs "on-device OCR" label

### On-device OCR (ML Kit, free, no limit)
- `lib/core/ocr/ocr_service.dart` — extracts text from image files on-device; used as Gemini fallback
- `lib/core/ocr/itinerary_parser.dart` — regex-based flight extractor (flight number, route, times, cabin class)
- Auto-triggered when attaching a photo in the Import sheet
- Available in the incoming share flow when sharing a screenshot or PDF to the Travel destination

### Offline read cache (6 screens)
- `lib/core/offline_cache.dart` extended with keys for Travel, Links, Money receipts/withdrawals, trip shell, and user trips
- Plan, Travel, Links, Money, and Map screens write to cache on every successful Supabase load and fall back to cache on network failure
- Offline state shown with a banner; editing requires connectivity

### Receipt sync queue
- `lib/core/sync_queue.dart` — queues failed receipt creates in SharedPreferences, replayed on next successful load
- Money screen shows pending sync count when offline

### Map improvements
- Initial load fits all trip spots using `CameraFit.bounds` with padding
- Single-spot trips zoom to that spot at level 14
- Tile labels forced to English (`additionalOptions: {'lang': 'en'}`)

### Signed release builds (GitHub Actions)
- CI now builds a signed release APK (was debug)
- Keystore decoded from `KEYSTORE_BASE64` secret; `key.properties` written in CI
- `android/app/build.gradle.kts` reads signing config from `key.properties`; falls back to debug signing locally
- `compileSdk` bumped to 37 (required by `receive_sharing_intent`)

### Instagram / link sharing fix
- Incoming share screen now correctly saves Instagram, TikTok, YouTube, and blog links via `LinksService`

### Photon place search
- Removed ~110 hardcoded Japan spots from local search dataset
- Address field now populated from Photon results (neighbourhood + postcode fallback for Japanese addresses)
