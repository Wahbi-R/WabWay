# Google Takeout Import

## Overview
Google Maps saved lists are not accessible via a public API. WabWay supports importing them via Google Takeout export files — both the default starred places (JSON) and custom-named lists (CSV). Large lists (88+ places) appear instantly; locations resolve in the background one by one.

## Why Takeout?
Google's saved lists are JavaScript-rendered with no public API. The WebView scraper attempts live extraction but may fail. Takeout provides a reliable offline fallback.

## Export Types

### Custom Lists (CSV) — recommended for named lists
- Google Takeout product: **"Saved"**
- File location: `Takeout/Saved/{List Name}.csv`
- Columns: `Title, Note, URL, Tags, Comment`
- No coordinates included — each place is geocoded after the list appears
- Notes from the `Note` column are preserved on the created spot

### Starred/Saved Places (JSON)
- Google Takeout product: **"Maps (your places)"**
- File location: `Takeout/Maps (your places)/Saved Places.json`
- GeoJSON FeatureCollection format
- Note: many entries have `[0, 0]` coordinates ("No location information available") — these are skipped

## Parser: `TakeoutParser` (`lib/core/places/takeout_parser.dart`)

### `parseCsvFast(Uint8List bytes)` — sync, instant
- Parses CSV with a custom RFC-4180-compliant splitter (handles quoted fields and escaped quotes)
- Deduplicates by Maps URL (`Set<String>` seen URLs)
- Returns all places immediately with `lat=0, lon=0` — no network calls
- Reads the `Note` column and stores it on each `MapsPlace`

### `geocodePlace(MapsPlace)` — async, per-place, three-step fallback
1. **Nominatim by display name** — `NominatimService.search(place.name)`
2. **Nominatim by URL slug** — extracts and URL-decodes the `/maps/place/NAME/` path segment; retries with that name if different from the display name
3. **Google Maps page fetch** — `GoogleMapsParser.fetchCoordsFromUrl(mapsUrl)` fetches the actual Maps page and extracts `@lat,lon` from the redirect URL. Works for local restaurants and niche spots that Nominatim doesn't know.

### `parseJson(Uint8List bytes)` — sync
- Validates `type == "FeatureCollection"`
- Reads `geometry.coordinates[lon, lat]` (GeoJSON order)
- Falls back to `Location.Geo Coordinates` for older export format
- Supports both `Title`/`Google Maps URL` (new format) and `title`/`google_maps_url` (older format)
- Skips `[0, 0]` entries

## Instant List + Background Geocoding

For CSV imports `MapsImportScreen` calls `parseCsvFast()` first, displays the full list immediately, then launches `_startBackgroundGeocoding()` which:
- Iterates places where `!p.hasCoords`
- Calls `TakeoutParser.geocodePlace(p)` sequentially (respects Nominatim ~1 req/sec rate limit)
- Updates `_places[i]` via `setState` after each resolves
- Shows a progress banner: "Finding locations… X of Y"

### Unfound places
Places that can't be geocoded through any fallback stay in the list with `lat=0, lon=0`. They are flagged with a `location_off_rounded` icon and "No location found" label. On save, `hasCoords` is checked: if false, `latitude`/`longitude` are stored as `null` rather than `0`.

## UI Integration

The Takeout guide is shown in `MapsImportScreen`'s empty state. Two labeled sections:
- **Custom lists (CSV)** — step-by-step for the "Saved" Takeout product
- **Starred places (JSON)** — step-by-step for "Maps (your places)"

File picker accepts `.csv` and `.json`. After picking a CSV the list appears instantly and the geocoding counter runs live.

## Supabase requirements
None — uses existing `spots` columns: `maps_url`, `address`, `latitude`, `longitude`, `place_source`, `image_url`, `notes`.
