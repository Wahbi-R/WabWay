# Travel Editing

## Description

Travel items support a `status` field with three values: `booked`, `tentative`, `cancelled`. The status is shown as a badge on the travel card and in the detail view. When editing a travel item, document links are synced (added/removed) via `TravelService.syncDocLinks()`.

## Key Files

- `lib/core/supabase/travel_service.dart` — `updateItem()`, `syncDocLinks()`
- `lib/data/travel_data.dart` — `TravelItem`, `TravelBookingStatus` enum + `fromDb`/`toDb`
- `lib/screens/travel_screen.dart` — status badge on list card
- `lib/screens/travel/travel_detail.dart` — edit sheet, status picker, linked-doc list
- `supabase/migrations/004_activity_events_and_travel_status.sql` — adds `status` column

## How It Works

**Status**: `TravelBookingStatus` values: `booked` (default), `tentative`, `cancelled`. Stored as a `text` column with a CHECK constraint. `fromDb()` / `toDb` convert between enum and string. The detail sheet shows a segmented picker; the card shows a coloured badge.

**Doc link sync**: When the user edits linked documents, `TravelService.syncDocLinks(itemId, oldDocIds, newDocIds, userId)` computes the diff:
- Rows in `oldDocIds` but not `newDocIds` → `DELETE` from `document_links`
- Rows in `newDocIds` but not `oldDocIds` → `INSERT` into `document_links`

## Setup

Migration `004_activity_events_and_travel_status.sql` must be applied (adds `status text not null default 'booked'` to `travel_items`).
