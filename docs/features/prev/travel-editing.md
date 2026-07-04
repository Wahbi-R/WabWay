# Travel Editing

## What it does

Travel items can now have a booking status, and document attachments are properly synced when editing.

## Booking status

A new `status` field with three values: **Booked**, **Tentative**, **Cancelled**.

- Shown as a badge next to the type badge in the item detail header
- Shown as a pill chip on the card for non-booked items (booked is the default, so it stays quiet)
- Selected from a dropdown in the Add/Edit Travel sheet (side-by-side with the Type dropdown)
- Stored in `travel_items.status` column (requires DB migration below)

## Document attach/detach on edit

When a travel item is edited and the doc selection changes, the `document_links` table is now synced correctly:
- Removed docs → rows deleted
- Added docs → rows inserted
- This uses `TravelService.syncDocLinks(itemId, oldDocIds, newDocIds, userId)`

## DB migration required

```sql
ALTER TABLE travel_items
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'booked'
  CHECK (status IN ('booked', 'tentative', 'cancelled'));
```

## Implementation

| File | Change |
|---|---|
| `lib/data/travel_data.dart` | `TravelBookingStatus` enum (label/icon/color/softColor/fromDb/toDb); `status` field on `TravelItem` |
| `lib/core/supabase/travel_service.dart` | `status` in `_fromRow`, `createItem`, `updateItem`; new `syncDocLinks` method |
| `lib/screens/travel/add_travel_sheet.dart` | `_status` state; status dropdown in form; passed in `_submit` |
| `lib/screens/travel/travel_item_detail.dart` | `_StatusBadge` widget; shown alongside `_TypeBadge` in header |
| `lib/screens/travel/travel_item_card.dart` | Status pill chip on card for tentative/cancelled items |
| `lib/screens/travel_screen.dart` | `_updateItem` calls `TravelService.syncDocLinks`; `createItem` passes `status` |
