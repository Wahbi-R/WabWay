# Trip Settings

## Description

A full-screen settings sheet (owner-only) for editing a trip's destination, start/end dates, and default currency. Changes are saved via `TripService.updateTrip()` and propagate to `TripState` immediately.

## Key Files

- `lib/screens/more_screen.dart` — trip settings sheet entry point (More screen)
- `lib/core/supabase/trip_service.dart` — `updateTrip()`
- `lib/core/trip/trip_state.dart` — refreshed after save so the sidebar/header updates
- `lib/core/supabase/` — `DestinationAutocomplete` widget reused from create-trip flow

## How It Works

1. Owner taps "Trip Settings" in the More screen (or desktop sidebar).
2. A modal sheet shows fields: Trip name, Destination (with autocomplete), Start date, End date, Default currency (dropdown).
3. Cover photo is also managed here (see `trip-cover-photo.md`).
4. On save, `TripService.updateTrip()` is called with only the changed fields (unchanged fields pass `null` so the service skips them).
5. `TripState` is notified to reload the active trip, propagating the new name/destination to all screens.

Fields support clearing (e.g. clear destination or dates) via explicit `clearDestination: true` / `clearStartDate: true` flags on `updateTrip()`.
