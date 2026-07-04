# Destination Autocomplete

## Overview

Typing in a destination field now surfaces up to 6 matching suggestions from a bundled local dataset — no network calls or paid APIs required.

## Component

**`DestinationAutocomplete`** (`lib/widgets/destination_autocomplete.dart`)

- Uses Flutter's `RawAutocomplete<String>` widget
- Accepts a `TextEditingController` so state lives in the parent (same pattern as `WabwayTextField`)
- Dataset: ~110 entries — major countries first, then popular cities with country suffix (e.g. `Tokyo, Japan`)
- Filters case-insensitively on `contains` match; returns up to 6 suggestions
- Dropdown is a `Material` overlay with `ListView.separated`; tap selects and closes

## Used in

| Screen | Field |
|---|---|
| `lib/screens/trips/create_trip_screen.dart` | Destination (optional) |
| `lib/screens/trips/trip_settings_sheet.dart` | Destination |

## Extending the dataset

Edit the `_kDestinations` constant at the top of `destination_autocomplete.dart`. No other changes required.
