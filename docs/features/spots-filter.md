# Spots Filter

## Description

An advanced filter sheet on the Spots screen allowing multi-select status filtering and city filtering. A badge on the filter icon shows the number of active filter criteria.

## Key Files

- `lib/screens/spots_screen.dart` — filter icon, `_FilterSheet`, active-filter badge, filtered list computation
- `lib/data/spot_data.dart` — `SpotStatus` enum

## How It Works

1. Tapping the filter icon (top-right of Spots AppBar) opens `_FilterSheet` as a bottom sheet.
2. **Status filter**: a multi-select chip row for each `SpotStatus` value. Any combination can be selected. Empty selection = show all.
3. **City filter**: a text field. Filters spots whose `city` contains the entered string (case-insensitive).
4. The screen maintains `_activeStatuses` (a `Set<SpotStatus>`) and `_activeCity` (a `String`). The spot list is filtered client-side on every rebuild.
5. The filter icon shows a `Badge` with the count of active criteria (number of selected statuses + 1 if city is non-empty) so users can tell at a glance that filters are active.
