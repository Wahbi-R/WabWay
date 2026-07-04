# Place Search for Spots

## What it does

When adding a spot, users can type any place name (e.g. "Senso-ji", "Shibuya", "TeamLab") into a search bar at the top of the sheet. Matching suggestions appear instantly from a bundled Japan dataset. Tapping a suggestion fills every field automatically:

- Name, city, area, category  
- Google Maps URL  
- Exact latitude / longitude  
- Full address  
- `place_source` set to `local_suggestion`

A green **"Map ready" badge** appears in the form once coordinates are set.

Pasting a full Google Maps URL (e.g. `https://www.google.com/maps/.../@35.71,139.79,...`) into the Maps URL field also parses the `@lat,lng` segment and sets coordinates without needing to pick from the dataset.

In Spot Detail, spots with coordinates show a location icon next to the city/area line, and the address is shown below it.

## Dataset

`lib/data/japan_places.dart` — ~60 hand-curated Japan spots across:
- Tokyo (Asakusa, Shibuya, Harajuku, Shinjuku, Ueno, Akihabara, Tsukiji, TeamLab, Nakameguro, Odaiba, Yanaka, DisneySea, Tokyo Tower)
- Kyoto (Fushimi Inari, Kinkaku-ji, Arashiyama, Kiyomizu-dera, Gion, Nijo Castle, Nishiki Market, Philosopher's Path, Tenryu-ji)
- Osaka (Dotonbori, Osaka Castle, Kuromon Market, Shinsekai, USJ)
- Nara, Hiroshima/Miyajima, Hakone, Kamakura, Nikko, Yokohama, Sapporo, Fukuoka, Mount Fuji

Each entry has aliases (Japanese characters + romanized variants) for broad matching.

## Database migration required

Run this SQL in Supabase before spots with coordinates will save:

```sql
ALTER TABLE spots ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE spots ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 7);
ALTER TABLE spots ADD COLUMN IF NOT EXISTS longitude NUMERIC(10, 7);
ALTER TABLE spots ADD COLUMN IF NOT EXISTS place_source TEXT;
```

## Files

| File | Role |
|---|---|
| `lib/data/japan_places.dart` | `PlaceSuggestion` model + ~60 Japan places dataset |
| `lib/core/place_search_service.dart` | `search()`, `parseLatLng()`, `isMapsUrl()` |
| `lib/screens/spots/add_spot_sheet.dart` | Search bar, suggestion list, auto-fill, lat/lng parsing from Maps URL |
| `lib/screens/spots/spot_detail.dart` | Map-ready icon + address row added to detail view |
| `lib/data/spot_data.dart` | `address`, `latitude`, `longitude`, `placeSource`, `isMapReady` getter |
| `lib/core/supabase/spot_service.dart` | Saves + reads the new fields |
