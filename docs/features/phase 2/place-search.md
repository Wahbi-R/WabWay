# Place Search

## Description

Live place search powered by the Photon API (komoot.io) with a local Japan dataset as an immediate fallback. Returns structured name/city/area/address/coords with category inferred from OSM type. Used in the Add/Edit Spot sheet.

## Key Files

- `lib/core/place_search_service.dart` — `searchPhoton()`, `searchLocal()`, `parseLatLng()`, `isMapsUrl()`
- `lib/data/japan_places.dart` — local fallback dataset (~110 entries)
- `lib/data/spot_data.dart` — `PlaceSuggestion` model
- `lib/screens/spots/add_spot_sheet.dart` — search field with 350ms debounce

## How It Works

1. User types in the place search field; a 350ms debounce fires.
2. `searchLocal()` runs immediately against `kJapanPlaces` for instant results while the network request is in flight.
3. `searchPhoton()` calls `https://photon.komoot.io/api/?q=<query>&limit=6&lang=en` with a 5-second timeout. On success, local results are replaced with Photon results.
4. Each Photon GeoJSON feature is mapped to `PlaceSuggestion` via `_featureToSuggestion()`, extracting name, city, district, street address, lat/lng, and a Google Maps URL (`maps/search/?api=1&query=lat,lng`).
5. `SpotCategory` is inferred from OSM `type` and `osm_value` strings.
6. Selecting a suggestion pre-fills all spot form fields.

## Setup

Requires `http: ^1.2.0` in `pubspec.yaml` (run `flutter pub get`). No API key needed — Photon is open access.
