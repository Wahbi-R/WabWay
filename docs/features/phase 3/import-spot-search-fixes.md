# Import & Spot Search Fixes (Build 104+)

Six bugs fixed across the Google Takeout import flow and the Add Spot search field.

---

## 1. Japanese / CJK mojibake in Takeout CSV

**Problem:** Google Takeout CSVs sometimes contain Japanese (or other non-Latin) text that was saved with UTF-8 bytes mis-decoded as Windows-1252, then re-encoded as UTF-8. Dart's `utf8.decode` reads those bytes correctly, but the resulting string is garbled (e.g. `ä¸–ç•Œãšã£ã¨WONDER` instead of `世界ずっとWONDER`).

**Fix:** `TakeoutParser._fixMojibake(String)` in `lib/core/places/takeout_parser.dart` converts each codepoint back to its W1252 byte value (handling the 0x80–0x9F range that differs from Latin-1), then UTF-8 decodes the resulting bytes. The result is only used if it contains characters above U+00FF, so ASCII and Latin-1 European names pass through unchanged. Applied to both `title` and `note` fields in `parseCsvFast`.

---

## 2. "No location found" shown during active geocoding

**Problem:** While `_startBackgroundGeocoding` was running, import cards with no coordinates yet showed a permanent-looking "No location found" label, even though the geocoder hadn't tried them yet.

**Fix:** `_MapsPlaceCard` now accepts an `isSearching` bool (passed as `_geocoding && !place.hasCoords`). When true, a small `CircularProgressIndicator` + "Searching…" label is shown instead of the location-off icon.

---

## 3. Save has no progress and never closes

**Problem:** Tapping "Add N spots" showed an indefinite spinner with no count, the screen stayed open forever (success path never set `_saving = false` or popped the route), and the list remained tappable during the save.

**Fix:**
- `_savingCount` / `_savingTotal` state vars track progress; button shows "Adding X of Y…".
- Spots are saved in parallel batches of 5 (Wikipedia lookup + Supabase insert concurrently per batch), reducing wall-clock time by ~5×.
- `Navigator.pop(context)` called after the snackbar on success.
- `AbsorbPointer(absorbing: _saving)` wraps the list to prevent stray taps during save.

---

## 4. "Unknown" city saved when geocoder only finds coordinates

**Problem:** The final geocoding fallback (`GoogleMapsParser.fetchCoordsFromUrl`) returned lat/lon but no city, so `p.city` was empty and the spot was saved with `city: 'Unknown'`.

**Fix:** After a successful coord fetch, `TakeoutParser.geocodePlace` now calls `NominatimService.reverseGeocodeCity(lat, lon)` (new method added to `lib/core/places/nominatim_service.dart`) to resolve the city name from the coordinates before returning the updated place.

---

## 5. Spot list shows "Unknown · · Landmark"

**Problem:** `SpotListTile` rendered `'${spot.city} · ${spot.area} · ${spot.category.label}'` verbatim, producing "Unknown · · Landmark" for imported spots.

**Fix:** The location text is now built with a list comprehension that only includes `spot.city` if it's non-empty and not `'Unknown'`, and only includes `spot.area` if non-empty. At minimum the category label is always shown.

---

## 6. Keyboard search key doesn't show results

**Problem:** Pressing the keyboard's search action key on Android unfocused the text field (dismissing the keyboard) before `_search()` completed. `_onFocusChange` fired and set `_showResults = false`, swallowing the incoming results.

**Fix in `lib/widgets/place_search_field.dart`:**
- `_onFocusChange` now only hides results when `!_loading` — results in-flight are preserved.
- The final `setState` in `_search()` explicitly sets `_showResults = true` so results always appear when they arrive.

---

## 7. No hint about location bias

**Problem:** Searching short queries like "GU" returned results near the user's device location (e.g. Toronto) with no indication that the search is location-biased.

**Fix:** A small caption "Include a city or country for better results — e.g. 'GU Japan'" is shown below the search field in the Add Spot sheet (`lib/screens/spots/add_spot_sheet.dart`).

---

## Files changed

| File | Change |
|---|---|
| `lib/core/places/takeout_parser.dart` | `_w1252` map + `_fixMojibake`; apply to title/note in `parseCsvFast`; reverse-geocode city in `geocodePlace` fallback |
| `lib/core/places/nominatim_service.dart` | New `reverseGeocodeCity(lat, lon)` method |
| `lib/screens/share/maps_import_screen.dart` | `isSearching` flag on cards; batch save with progress; auto-pop; `AbsorbPointer` |
| `lib/screens/spots/spot_list_tile.dart` | Suppress "Unknown" city in location text |
| `lib/widgets/place_search_field.dart` | Fix keyboard search key via `_onFocusChange` + `_loading` guard |
| `lib/screens/spots/add_spot_sheet.dart` | Location bias hint below search field |
