# Google Places Search + Shared PlaceSearchField

## What changed

### User-visible
- Place search in **Add Spot** and **Add Plan Item** now returns Google Places results (restaurants, shops, hotels, local businesses) instead of only OSM data
- Search fires on **Enter** or **search icon tap** — not on every keystroke — to avoid burning API credits
- Falls back to **Photon (OpenStreetMap)** automatically when the wabway-server is unavailable
- **Google Takeout CSV geocoding** now tries Google Places as step 0, so imported pins with ambiguous names (e.g. "Daiso") are located far more accurately

### Internal
- `wabway-server/main.py` — new `POST /places/search` endpoint; accepts `query`, optional `latitude`/`longitude` (50 km soft bias), and `limit`; returns a `list[PlacesSearchResult]` with name, address, city, country, category, lat/lng, website, place_id; returns `[]` if `GOOGLE_PLACES_API_KEY` is unset so the client falls back to Photon transparently
- `lib/core/place_search_service.dart` — new `search()` method (server-first → Photon fallback); `_searchViaServer()` posts to `/places/search`; `_categoryFromSlug()` maps server category strings to `SpotCategory`
- `lib/widgets/place_search_field.dart` — new shared widget; submit-triggered (Enter / icon); shows loading spinner and "No results found" empty state; `onSelected(PlaceSuggestion)` callback
- `lib/widgets/wabway_text_field.dart` — added `onSuffixTap: VoidCallback?` and `onFieldSubmitted: ValueChanged<String>?`
- `lib/screens/spots/add_spot_sheet.dart` — replaced inline debounced search bar + suggestion list with `PlaceSearchField`; removed 50+ lines of duplicated state
- `lib/screens/plan/add_item_sheet.dart` — replaced `_LocationField` widget class with `PlaceSearchField`; removed 130+ lines of duplicated widget code
- `lib/core/places/takeout_parser.dart` — `geocodePlace()` now calls `PlaceSearchService.search()` as step 0 before Nominatim

## Architecture

```
User types → [PlaceSearchField] → (submit) → PlaceSearchService.search()
                                                    │
                                         ┌──────────┴──────────┐
                                         ▼                     ▼
                               wabway-server              (fallback)
                               /places/search              Photon API
                               (Google Places)          (OpenStreetMap)
```

## Adding coords to a search

Pass `latitude` / `longitude` to `PlaceSearchField` or `PlaceSearchService.search()` to apply a 50 km soft bias circle. The API still returns global results if no nearby matches are found — coords are a hint, not a hard filter.
