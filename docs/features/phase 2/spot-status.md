# Confirmed Spot Status + Plan Integration

## Description

A `confirmed` status was added to the `SpotStatus` enum (between `mustDo` and `planned`). Confirmed spots display a green badge and green map pin. A collapsible "Unplanned Spots" section in the Plan screen shows confirmed/planned spots not yet linked to a day, letting users quickly schedule them.

## Key Files

- `lib/data/spot_data.dart` — `SpotStatus.confirmed` enum value
- `lib/core/supabase/spot_service.dart` — `_statusFrom()` / `_statusToDb()` handle `'confirmed'`
- `lib/screens/map_screen.dart` — `confirmed` + `booked` both render as green pins
- `lib/screens/plan_screen.dart` — `_unplannedSpots` getter, `_UnplannedSpotsSection` widget, `_DayPickerSheet`
- `supabase/migrations/005_confirmed_spot_status.sql` — adds enum value to DB

## How It Works

**Status**: `SpotStatus.confirmed` maps to the DB string `'confirmed'`. Both `booked` and `confirmed` show as green in the map and spot list (indicating commitment without a full booking).

**Unplanned Spots section** (Plan screen):
- `_unplannedSpots` computes spots with `status == confirmed || planned` that have no linked `ItineraryItem` (`linkedSpotId` not found in any day's items).
- The section is collapsible; tapping a spot opens `_DayPickerSheet` with a list of days and an optional time picker.
- Confirming creates an `ItineraryItem` with `linkedSpotId` set. The spot disappears from the section on the next list rebuild.

## Setup

Run migration `005_confirmed_spot_status.sql` in the Supabase SQL editor:
```sql
ALTER TYPE spot_status ADD VALUE IF NOT EXISTS 'confirmed';
```
