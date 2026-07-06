# Plan Editing

## Description

Enhanced editing capabilities for the trip itinerary: edit a day's city/date/notes, move an item to a different day, duplicate an item, and use inline Move/Duplicate action buttons inside the item detail view.

## Key Files

- `lib/screens/plan_screen.dart` — day editing sheet, move/duplicate triggers
- `lib/screens/plan/item_detail.dart` — inline Move and Duplicate buttons
- `lib/core/supabase/plan_service.dart` — `updateDay()`, `moveItem()`, `duplicateItem()`
- `lib/data/plan_data.dart` — `TripDay`, `ItineraryItem` models

## How It Works

**Edit day**: Tapping the edit icon on a day header opens a sheet with city, date, and notes fields. `PlanService.updateDay(dayId, city, date, notes)` updates the row; the screen refreshes via Realtime or explicit reload.

**Move item**: A "Move to day" picker sheet lists all other days. Selecting one calls `PlanService.moveItem(itemId, newDayId)` which updates `day_id`. The item disappears from its current day and appears in the new one.

**Duplicate item**: Creates a copy of the item in the same day with title suffixed `(copy)` and `sort_order: 999`. Calls `PlanService.duplicateItem(item, createdBy: userId)`.

Both Move and Duplicate are accessible from the item detail bottom sheet and from the item's action menu.
