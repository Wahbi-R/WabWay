# Activity Events

## Description

A real-time activity feed shown on the Home screen. Every significant action in a trip (spot added, receipt logged, member joined, etc.) is automatically recorded by database triggers and read back through `ActivityService`.

## Key Files

- `lib/core/supabase/activity_service.dart` — loads events, joins `profiles` for actor name
- `lib/data/activity_data.dart` — `ActivityEvent` model and `ActivityEventType` enum
- `lib/screens/home_screen.dart` — renders feed with per-type icons and colours
- `supabase/migrations/004_activity_events_and_travel_status.sql` — table, RLS, and triggers

## How It Works

1. A `record_activity()` PL/pgSQL function is attached as an AFTER INSERT trigger on `spots`, `receipts`, `cash_withdrawals`, `travel_items`, `itinerary_items`, `documents`, `trip_links`, and `trip_members`.
2. Each trigger fires with a string argument (e.g. `'spot_added'`) that becomes the `event_type` column.
3. The function resolves `trip_id` and a human-readable `entity_title` for each table, then inserts a row into `activity_events`.
4. `ActivityService.loadEvents(tripId)` queries the table ordered by `created_at DESC`, joining `profiles` to get `display_name`.
5. The Home screen maps each `ActivityEventType` to an icon and accent colour.

## Setup

Migration `004_activity_events_and_travel_status.sql` must be applied. The triggers are created automatically — no manual wiring needed after migration.
