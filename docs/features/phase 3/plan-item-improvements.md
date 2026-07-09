# Plan Item Improvements

**Build:** 27  
**Date:** 2026-07-09  
**Migration:** `supabase/migrations/008_itinerary_country.sql`

---

## What changed

### Spot quick-pick

A collapsible spot picker sits above the Title field in the Add/Edit Item sheet.

- Tapping "Fill from a spot" expands a searchable list of all trip spots
- Selecting a spot autofills: Title, City, Location/Address, Maps URL
- Sets `linkedSpotId` on the item
- Item type is inferred from the spot's category (food → Food & Drink, everything else → Spot)
- The picker collapses and shows the linked spot name with swap/clear buttons

### Location / Address autocomplete

The Location field calls Photon (komoot) on each keystroke (debounced 350 ms) and shows a suggestion dropdown beneath the field.

- Suggestions display name + address/city/country
- Selecting one fills Location, and also pre-fills City and Country if those fields are empty
- Maps URL is also auto-populated from the geocoordinates

### Country field

A new Country field was added below City in the form. Field order:

> Spot picker → Title → Type → Time → Location/Address → City → **Country** → Attach docs → Notes → Advanced

`country` is stored in `itinerary_items` (migration 008) and is read/written by `PlanService`.

### Attach documents — collapsible

The document multi-picker is collapsed by default (expanded only when docs are already attached). A count badge on the header shows how many docs are linked.

### Desktop layout

On screens ≥ `kDesktopBreakpoint` (720px) the sheet opens as a centred `Dialog` instead of a `DraggableScrollableSheet`.

---

## Files changed

| File | Change |
|---|---|
| `lib/screens/plan/add_item_sheet.dart` | Full rewrite — spot picker, location autocomplete, country field, collapsible docs |
| `lib/data/plan_data.dart` | Added `country` field to `ItineraryItem` |
| `lib/data/spot_data.dart` | Added `country` to `PlaceSuggestion` |
| `lib/core/place_search_service.dart` | Extracts `country` from Photon response |
| `lib/core/supabase/plan_service.dart` | Reads/writes `country` column |
| `lib/screens/plan_screen.dart` | Passes `country: draft.country` to `createItem` |
| `supabase/migrations/008_itinerary_country.sql` | `ALTER TABLE itinerary_items ADD COLUMN country text` |
