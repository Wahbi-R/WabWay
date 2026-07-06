# Google Maps Import

## Overview
Users can share any Google Maps URL directly to WabWay and import places as spots. This includes individual place links, custom saved lists (via Takeout CSV), and My Maps (KML).

## Entry Points
- **Share sheet** — share a Maps URL from the Maps app; WabWay's `IncomingShareScreen` detects it as a `googleMapsLink` content type and shows an "Import from Google Maps" banner.
- **Manual paste** — any Maps URL can be passed to the import flow programmatically.

## URL Types Handled

| URL pattern | Strategy |
|---|---|
| `maps.app.goo.gl/…` | Resolved via `dart:io` `HttpClient` to track final redirect URL |
| `/maps/d/viewer?mid=…` | My Maps — KML export fetched and parsed |
| `/maps/place/NAME/data=…` | Single place — coords extracted from URL or Nominatim geocode |
| `/maps/@…/data=!4m3!11m2!2s…` | Saved list — JS-rendered; falls back to WebView scrape or Takeout |

## Parser: `GoogleMapsParser` (`lib/core/places/google_maps_parser.dart`)
- Uses `dart:io` `HttpClient` (not the `http` package) to follow redirects and capture the final URL, which contains the place name for individual shares.
- Returns `MapsParseResult` with `List<MapsPlace>`, `isList`, `listName`, `finalUrl`, `noDataReason`.
- Nominatim geocoding fallback: extracts name+address from `/maps/place/NAME,ADDRESS/` path and calls `NominatimService.search()`.

## Models
- `MapsPlace` — name, lat, lon, address, mapsUrl, category, city
- `MapsParseResult` — places list + metadata

## Import Screen: `MapsImportScreen` (`lib/screens/share/maps_import_screen.dart`)
- Shows all found places as checkable cards with category chips
- Bulk-creates spots for all checked items
- Stores `placeSource` (list name) on each created spot
- Auto-fetches Wikipedia thumbnail for each place on save

## WebView Scrape: `MapsWebScrapeScreen` (`lib/screens/share/maps_web_scrape_screen.dart`)
- Used when the Maps URL is a JS-rendered saved list with no API access
- Loads the URL in a `WebViewController` with a mobile user-agent
- Waits 5s after `onPageFinished` for XHR rendering to complete
- Injects JavaScript with 5 fallback regex patterns to extract `["Name",null,null,[[lat,lon]]` data from the fully-rendered DOM
- On success: populates `MapsImportScreen`; on failure: falls through to Takeout guide

## Supabase requirements
No schema changes — uses existing `spots` columns: `maps_url`, `address`, `latitude`, `longitude`, `place_source`, `image_url`.
