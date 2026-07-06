# Trip Switcher

## Description

Allows users who belong to multiple trips to switch between them without logging out. A trip-switcher bottom sheet is accessible from the More screen (mobile) and by tapping the trip name in the desktop sidebar header.

## Key Files

- `lib/screens/more_screen.dart` — "Switch Trip" row opens the switcher sheet
- `lib/widgets/sidebar.dart` — desktop sidebar header tap opens the switcher sheet
- `lib/core/trip/trip_state.dart` — `TripState.setTrip()` updates the active trip for all screens
- `lib/core/supabase/trip_service.dart` — `loadUserTrips()` fetches all trips for the current user

## How It Works

1. `TripService.loadUserTrips()` queries `trips` rows where the current user has a `trip_members` row (enforced by RLS).
2. The switcher sheet lists all trips with their name, destination, and member count.
3. Tapping a trip calls `TripState.setTrip(trip)`, which notifies all `TripState.tripOf(context)` listeners.
4. All screens re-query on `didChangeDependencies` when `TripState.tripOf(context).id` changes, so data reloads automatically.

Previously the app used `trips.first` — the switcher replaces that hardcoded fallback.
