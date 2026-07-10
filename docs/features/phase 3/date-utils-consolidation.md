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

## What stays private

- `_fmtDate` in `trip_settings_sheet.dart`, `parsed_itinerary_screen.dart` — different format (includes year or is ISO); intentionally separate
- `_fmtDate` in service files (`plan_service`, `travel_service`, etc.) — ISO 8601 format for DB writes; these could use `DateTime.toIso8601String().substring(0,10)` but are left scoped to avoid unintended coupling
