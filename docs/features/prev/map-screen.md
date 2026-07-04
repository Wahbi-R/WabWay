# Map Screen

## What it does

Replaces the "Map coming soon" placeholder with a real interactive map backed by OpenStreetMap tiles (via `flutter_map`). No API key required.

## Map view

- Renders all spots that have `latitude` + `longitude` as pin markers
- Each marker is a coloured circle (status colour) + category icon + triangular tail
- Status colours match the badge system: idea=grey, want-to-go=primary, must-do=gold, planned=green-muted, booked=success-green, skipped=danger
- Tapping a marker opens the full Spot Detail as a draggable bottom sheet
- Initial camera position centers on the mean coordinates of all mapped spots; falls back to Tokyo if none
- Shows a footer banner when some spots have no coordinates, with a "See all" shortcut to switch to List view

## List view (toggle)

- Toggled via the Map / List segmented control in the app bar
- Sections: "On map" (spots with coordinates) and "No coordinates"
- Tapping an "On map" row switches back to the map and flies the camera to that spot
- Tapping "No coordinates" rows opens spot detail directly

## Files

| File | Role |
|---|---|
| `lib/screens/map_screen.dart` | Full implementation — `MapScreen`, `_SpotMarker`, `_PinTailPainter`, `_SpotListRow`, `_SectionLabel` |
| `lib/screens/placeholder_screen.dart` | `MapScreen` stub removed |
| `lib/shell/app_shell.dart` | Import added for `map_screen.dart` |
| `pubspec.yaml` | `flutter_map: ^7.0.2`, `latlong2: ^0.9.0` added |

## Constraints / out of scope

- Day badges (D1, D2…) skipped — spots don't have a direct plan-day assignment in the current schema; will revisit when plan-spot linking is added
- Tiles are OpenStreetMap (no API key, free, attribution required by OSM license — shown automatically by `flutter_map`)
- Short `maps.app.goo.gl` links don't embed coordinates, so those spots won't appear on the map until the user also has the full URL
