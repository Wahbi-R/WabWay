# Spot Country + Better Maps Import

**Build:** 28  
**Date:** 2026-07-09  
**Migration:** `supabase/migrations/009_spot_country.sql`

---

## What changed

### Country field on Spots

`Spot` now has a `country` field (nullable text). It is:
- Persisted in Supabase via migration 009
- Read by `SpotService._spotFromRow`
- Written by `SpotService.createSpot` and `SpotService.updateSpot`
- Shown and editable in `add_spot_sheet.dart` (below the Address field)
- Auto-filled by Photon place search (via `PlaceSuggestion.country`)
- Auto-filled when pasting a Google Maps URL (via `MapsImportService`)
- Passed through the share/import flow via `ShareSaveData.country`

### Better Google Maps URL import (`MapsImportService`)

New service at `lib/core/maps_import_service.dart`. When a Maps URL is pasted or shared:

1. **Redirect resolution** — follows up to 5 HTTP hops so `maps.app.goo.gl` short links are resolved to the full `google.com/maps/place/...` URL
2. **Place name extraction** — parses the place name from the URL path (`/maps/place/NAME/@lat,lng`)
3. **Reverse geocoding** — calls Nominatim (`nominatim.openstreetmap.org/reverse`) with the extracted coordinates to get address, city, and country

Result: pasting any Maps link (short or full) in the Add Spot form now auto-fills:
- Name (from URL path, decoded)
- Address (street + postcode from Nominatim)
- City (city/town/village from Nominatim)
- Country (country from Nominatim)
- Coordinates (from `@lat,lng` in URL)

All fields are only overwritten if they are currently empty, so manual edits are preserved.

A "Looking up place info…" spinner appears on the Maps URL field while resolving.

### Share flow improvements

`share_form.dart` — when a Google Maps link is shared into the app:
- Calls `MapsImportService.resolve()` on init (async)
- Pre-fills the spot title with the resolved place name
- Pre-fills City and Country fields (new Country field added to the spot share form)
- Shows a resolving spinner until the lookup completes

`ShareSaveData` gets a new `country` field passed through to `SpotService.createSpot`.

---

## Files changed

| File | Change |
|---|---|
| `lib/core/maps_import_service.dart` | New — redirect resolution + place name extraction + Nominatim reverse geocode |
| `lib/data/spot_data.dart` | Added `country` field to `Spot` and `copyWith` |
| `lib/core/supabase/spot_service.dart` | Reads/writes `country` column in all CRUD methods |
| `lib/screens/spots/add_spot_sheet.dart` | Country field + async Maps URL resolution with `MapsImportService` |
| `lib/screens/share/share_form.dart` | `ShareSaveData.country`; Maps share resolves name/city/country on init |
| `lib/screens/share/incoming_share_screen.dart` | Passes `country` to `SpotService.createSpot` |
| `supabase/migrations/009_spot_country.sql` | `ALTER TABLE spots ADD COLUMN country text` |
