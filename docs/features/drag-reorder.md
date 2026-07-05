# Plan Item Drag-to-Reorder

## Description

Itinerary items within a day can be reordered by dragging. Order is persisted to Supabase via `PlanService.reorderItemsInDay()`. Only untimed items participate in drag reorder; timed items sort by time above them.

## Key Files

- `lib/screens/plan/day_card.dart` — `_ReorderableItemList` with `ReorderableListView` and drag handles
- `lib/data/plan_data.dart` — `ItineraryItem.sortOrder` field; `TripDay.sortedItems` computed property
- `lib/core/supabase/plan_service.dart` — `reorderItemsInDay(List<ItineraryItem> items)` persists new order

## How It Works

1. `ItineraryItem` has a `sortOrder` integer field (read from `itinerary_items.sort_order` column, defaulting to 0).
2. `TripDay.sortedItems` separates timed items (sorted by time string) from untimed items (sorted by `sortOrder`), then concatenates them — timed items always appear first.
3. `_ReorderableItemList` wraps untimed items in a `ReorderableListView`. Each item shows a drag handle (`Icons.drag_handle_rounded`) on the trailing side.
4. On drag completion, `onReorder` is called with the reordered list. The parent screen calls `PlanService.reorderItemsInDay(newItems)` which issues one `UPDATE` per item whose `sort_order` changed (skips unchanged rows).

## Setup

No migration needed — `sort_order` is an integer column added during initial schema. New items default to `sort_order: 0` and are placed at the end of the untimed list. Drag reorder is available on both mobile and desktop plan layouts.
