# Map Screen

## Description

An interactive map of all trip spots, rendered with `flutter_map` and Carto Voyager tiles (English labels). Spots are shown as colour-coded pins by status. A list/map toggle switches views. Tapping a pin opens the spot detail sheet.

## Key Files

- `lib/screens/map_screen.dart` — main screen (map + list toggle, Realtime, marker rendering)
- `lib/core/supabase/spot_service.dart` — `loadSpots()`
- `lib/data/spot_data.dart` — `Spot`, `SpotStatus` (drives pin colour)

## How It Works

1. On load, `SpotService.loadSpots(tripId)` fetches all spots.
2. Spots with `latitude`/`longitude` set are rendered as `Marker` widgets on the map; status determines colour (green = booked/confirmed, amber = mustDo, etc.).
3. A Supabase Realtime channel subscribes to `spots` and `spot_votes` changes for the active trip. On any change the spot list reloads.
4. The map uses Carto Voyager tile URL with `subdomains: ['a','b','c','d']` for worldwide English-language map labels.
5. List toggle (`_showMap = false`) renders the same spots in a `ListView` for no-coords fallback.
6. A refresh `IconButton` in the AppBar triggers a manual reload.

## Setup

`flutter_map` and `latlong2` packages required (already in `pubspec.yaml`). No API key needed — Carto Voyager is free for typical usage.
