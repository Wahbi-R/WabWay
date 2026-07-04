# Google Maps Link Handling

## What it does

Google Maps URLs are detected and treated specially throughout all three link-entry flows. When a Maps URL is present, coordinates are extracted (where available) and the URL is saved as `maps_url` rather than `source_url`.

## Detection

`PlaceSearchService.isMapsUrl(url)` matches all three common formats:
- `google.com/maps` — full Google Maps URLs
- `maps.app.goo.gl` — Google Maps short links (mobile share)
- `goo.gl/maps` — legacy short links

`share_data.dart`'s `detectContentType()` also recognises all three, classifying the share as `ShareContentType.googleMapsLink`.

## Coordinate extraction

`PlaceSearchService.parseLatLng(url)` extracts the `@lat,lng` segment present in full Google Maps URLs (e.g. `@35.7147,139.7966`). Short `maps.app.goo.gl` links don't embed coordinates — those require a network round-trip to resolve, which we don't do client-side.

## Where it's applied

### Add Spot sheet (`add_spot_sheet.dart`)
- Pasting any Maps URL into the "Google Maps URL" field triggers `parseLatLng`
- If coords are found, a green "Map ready" badge appears immediately
- Coordinates are passed to `SpotService.createSpot`

### Import sheet (`import/import_sheet.dart`)
- When a pasted URL is a Maps URL, the Spot destination chip is auto-selected
- The Maps URL field in the Spot sub-form is pre-filled
- Coordinates are extracted and saved

### Incoming Share screen (`share/incoming_share_screen.dart` + `share_form.dart`)
- When `contentType == googleMapsLink`, the spot form shows a read-only Maps URL preview instead of a free-text location field
- "Map ready" badge shown if `@lat,lng` could be parsed from the URL
- On save: `mapsUrl` set to the raw content; `source_url` left null (not duplicated); latitude/longitude/place_source passed through to `SpotService.createSpot`

## Files

| File | Change |
|---|---|
| `lib/core/place_search_service.dart` | `isMapsUrl()`, `parseLatLng()` |
| `lib/data/share_data.dart` | Added `maps.app.goo.gl` to `detectContentType` |
| `lib/screens/share/share_form.dart` | `ShareSaveData` extended with `mapsUrl/latitude/longitude/placeSource`; spot fields show Maps URL preview + "Map ready" badge; coords extracted in `initState` |
| `lib/screens/share/incoming_share_screen.dart` | Spot save uses `data.mapsUrl`, `data.latitude/longitude/placeSource`; `sourceUrl` cleared for Maps shares |
| `lib/screens/spots/add_spot_sheet.dart` | `_mapsCtrl` listener calls `parseLatLng`, sets `_latitude`/`_longitude` |
| `lib/screens/import/import_sheet.dart` | Maps URL detection auto-selects Spot; pre-fills `mapsUrl` field |
