# Date Utils Consolidation

**Build 55**

## Problem

`fmtDate` (in `money_data.dart`) and `fmtDayDate` (in `plan_data.dart`) were functionally identical functions. Additionally, private `_fmtDate` copies existed in `doc_card.dart`, `accommodations_screen.dart` — all producing the same "Jan 7" output.

## Solution

Created `lib/data/date_utils.dart` with a single `fmtDate(DateTime)` function.

Both `money_data.dart` and `plan_data.dart` now re-export it via `export 'date_utils.dart' show fmtDate;`, so all existing callers continue to work without changing their imports.

## Files changed

- `lib/data/date_utils.dart` — new canonical location
- `lib/data/money_data.dart` — removed inline definition, added re-export
- `lib/data/plan_data.dart` — removed `fmtDayDate`, added re-export
- `lib/screens/docs/doc_card.dart` — removed private copy, imports `date_utils.dart`
- `lib/screens/accommodations/accommodations_screen.dart` — same
- `lib/screens/plan_screen.dart`, `plan/day_card.dart`, `plan/item_detail.dart`, `travel/travel_item_detail.dart` — `fmtDayDate` → `fmtDate`

## Build 58 additions

Added `isoDate(DateTime)` to `date_utils.dart` for the ISO 8601 DB format. Updated all 4 service files:

- `plan_service.dart` — `_fmtDate` → `isoDate`
- `travel_service.dart` — `_fmtDate` → `isoDate`
- `money_service.dart` — `_fmtDate` → `isoDate`
- `trip_service.dart` — `_fmtDate` → `isoDate`; also cleaned up inline formatting in `createTrip`

## What stays private

- `_fmtDate` in `trip_settings_sheet.dart` — date picker display format; different use case
- `_fmtDate` in `parsed_itinerary_screen.dart` — includes year (e.g. "Jan 7, 2025"); intentionally different
