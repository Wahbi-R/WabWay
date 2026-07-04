# Trip Settings

## What it does

Trip owners can now edit all trip metadata from a single "Edit trip details" sheet accessible in the More tab. Previously only the trip name was editable.

## Fields

| Field | Control | Notes |
|---|---|---|
| Trip name | Text field | Required; same as before |
| Destination | Text field with place icon | Optional; cleared if left blank |
| Start date | Date picker | Optional; cleared via ✕ button |
| End date | Date picker | Optional; blocked before start date |
| Default currency | Dropdown | 15 common Asia-Pacific currencies |

## Access

- **Mobile**: More tab → "Trip settings" section → "Edit trip details" (owner only)
- **Desktop**: Same — the trip settings section is in the More/Settings area

## After save

`TripService.updateTrip` sends only the changed fields (via conditional map entries). After a successful save, `TripState.refresh(context)` is called so the sidebar header, home screen hero, and everywhere else that reads `TripState.tripOf(context)` picks up the new values.

## Files

| File | Change |
|---|---|
| `lib/core/supabase/trip_service.dart` | `updateTrip` with named params for name, destination, startDate, endDate, currency; clear* flags for nullable fields |
| `lib/screens/trips/trip_settings_sheet.dart` | New — `showTripSettingsSheet`, full form with date pickers and currency dropdown |
| `lib/screens/more_screen.dart` | "Edit trip name" replaced with "Edit trip details" (owner-only); imports new sheet |
