# Google Takeout Import

## Overview
Google Maps saved lists are not accessible via a public API. WabWay supports importing them via Google Takeout export files — both the default starred places (JSON) and custom-named lists (CSV).

## Why Takeout?
Google's saved lists are JavaScript-rendered with no public API. The WebView scraper attempts live extraction but may fail. Takeout provides a reliable offline fallback.

## Export Types

### Custom Lists (CSV) — recommended for named lists
- Google Takeout product: **"Saved"**
- File location: `Takeout/Saved/{List Name}.csv`
- Columns: `Title, Note, URL, Tags, Comment`
- No coordinates included — each place is geocoded via Nominatim using the Maps URL path name.

### Starred/Saved Places (JSON)
- Google Takeout product: **"Maps (your places)"**
- File location: `Takeout/Maps (your places)/Saved Places.json`
- GeoJSON FeatureCollection format
- Note: many entries have `[0, 0]` coordinates ("No location information available") — these are skipped.

## Parser: `TakeoutParser` (`lib/core/places/takeout_parser.dart`)

### `parseCsv(Uint8List bytes)` — async
- Parses CSV with a custom RFC-4180-compliant splitter (handles quoted fields)
- For each row: calls `GoogleMapsParser.parse(url)` → falls back to `NominatimService.search(title)` if no coords
- Returns `Future<List<MapsPlace>?>`

### `parseJson(Uint8List bytes)` — sync
- Validates `type == "FeatureCollection"`
- Reads `geometry.coordinates[lon, lat]` (GeoJSON order)
- Falls back to `Location.Geo Coordinates` for older export format
- Supports both `Title`/`Google Maps URL` (new format) and `title`/`google_maps_url` (older format)
- Skips `[0, 0]` entries

## UI Integration
The Takeout import guide is shown in `MapsImportScreen`'s empty state (when no places were found automatically). It presents two labeled sections — custom lists and starred places — each with step-by-step instructions.

File picker accepts both `.csv` and `.json`. After picking a CSV, the button label changes to "Geocoding places…" while Nominatim lookups complete.

## Supabase requirements
None — uses existing spots columns.
