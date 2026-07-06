# Maps Link Handling

## Description

Utility logic that detects Google Maps URLs, extracts coordinates from them, and feeds the result into Spot creation, the Import flow, and the Share intake screen.

## Key Files

- `lib/core/place_search_service.dart` — `isMapsUrl()`, `parseLatLng()`
- `lib/screens/spots/add_spot_sheet.dart` — uses `isMapsUrl` to pre-fill maps_url + coords
- `lib/screens/import_screen.dart` — uses `isMapsUrl` to route to Spot import path
- `lib/screens/incoming_share_screen.dart` — title extraction improved for maps links

## How It Works

`PlaceSearchService.isMapsUrl(url)` returns true for URLs containing:
- `google.com/maps`
- `maps.app.goo.gl`
- `goo.gl/maps`

`PlaceSearchService.parseLatLng(url)` applies a regex `@(-?\d+\.?\d*),(-?\d+\.?\d*)` to extract the `@lat,lng` component embedded in long-form Google Maps URLs. Short URLs (`maps.app.goo.gl`) must be expanded before coordinates can be extracted.

Extracted coordinates populate `latitude`, `longitude`, and `maps_url` on a new `Spot` or `ItineraryItem`.
