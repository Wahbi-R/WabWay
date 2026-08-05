# Google Places Photos + Home Screen Performance

**Build 100 — 2026-08-05**

## What changed

### Google Places photo pipeline
- Wikipedia thumbnail fetching was CORS-blocked on web and made N×2 HTTP calls on mobile; replaced with Google Places CDN photos.
- `wabway-server` gains a `/places/photo?place_id=…` GET endpoint: fetches photo metadata from Places v1 details endpoint, then resolves the first photo name to a CDN URI using `skipHttpRedirect=true` (no API key in the returned URL).
- `PlaceSuggestion.placeId` field added to carry the Google Places `place_id` through the search → add-spot pipeline.
- `PlaceSearchService.fetchPhotoUrl(placeId)` calls the server and returns the CDN URL.
- `add_spot_sheet.dart` fetches the photo URL at save time (create path only) and passes it to `SpotService.createSpot`.
- `maps_import_screen.dart`: Wikipedia fetch guarded with `kIsWeb` to prevent CORS errors on web.
- `spots_screen.dart`: removed `_fetchMissingThumbnails` and all Wikipedia imports entirely.

### CI/CD web build
- `--web-renderer html` flag removed (it was deleted in Flutter 3.22+).
- Replaced with `--wasm`, which produces a dual Skwasm (WebAssembly) + CanvasKit fallback build.
- Web build steps moved before APK steps so GitHub Pages deploys even when APK signing fails.

### Home screen performance
- `kStyle*` text style constants in `app_text_theme.dart` changed from `get` getters to `final` fields — `GoogleFonts.*()` is now called once per app lifetime instead of on every widget build.
- `_ActivityFeed.build()` precomputes O(1) Maps for spot/doc/travel/receipt/link/plan lookups, removing O(n) linear scans per event.
- `_TripHero`, `_ActivityFeed`, and individual activity rows wrapped in `RepaintBoundary` to isolate repaints.

## Files changed
- `wabway-server/main.py` — new `/places/photo` endpoint
- `lib/core/place_search_service.dart` — `fetchPhotoUrl`, `placeId` in search results
- `lib/data/spot_data.dart` — `PlaceSuggestion.placeId`
- `lib/screens/spots/add_spot_sheet.dart` — fetch photo at save time
- `lib/screens/spots_screen.dart` — removed Wikipedia calls
- `lib/screens/share/maps_import_screen.dart` — `kIsWeb` guard on Wikipedia
- `lib/theme/app_text_theme.dart` — `get` → `final` for all `kStyle*`
- `lib/screens/home_screen.dart` — O(1) maps, `RepaintBoundary`
- `.github/workflows/build-and-deploy.yml` — `--wasm`, web first
