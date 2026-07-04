# Advanced Spots Filtering

## What it does

The previously-dead filter icon (`tune_rounded`) in the Spots screen app bar now opens a filter sheet that lets users narrow spots by status and city, on top of the existing category strip and search.

## Filters available

| Filter | Control | Type |
|---|---|---|
| Status | Animated pill chips | Multi-select (any of) |
| City | Animated pill chips | Single-select (exact match) |

City chips are derived from the loaded spots — only cities that appear in the current trip are shown.

## UX details

- A blue badge on the filter icon shows the count of active advanced filters (status + city, not counting the category strip)
- "Clear all" button appears in the sheet header when any filter is active
- Filters compose additively with search text and the category strip
- Returning from the sheet with no change leaves state unchanged

## Implementation

`_SpotsScreenState` gained:
- `Set<SpotStatus> _filterStatuses` — multi-select status filter
- `String? _filterCity` — single city filter
- `int get _advancedFilterCount` — badge count for the icon
- `Set<String> get _availableCities` — cities derived from `_spots`
- `_openFilterSheet()` — shows `_SpotFilterSheet` and applies result

`_filtered` getter now applies all four filters: search, category, statuses, city.

`_MobileLayout` gained `advancedFilterCount` and `onFilter` params to pass down to the icon.

`_SpotFilterSheet` / `_SpotFilterResult` added at the bottom of `spots_screen.dart`.

## Files

| File | Change |
|---|---|
| `lib/screens/spots_screen.dart` | Filter state fields; `_filtered` extended; `_openFilterSheet`; `_MobileLayout` updated; `_SpotFilterSheet` + `_SpotFilterResult` added |
