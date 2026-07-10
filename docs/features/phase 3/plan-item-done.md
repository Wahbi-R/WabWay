# Plan Item — Mark as Done

**Status:** Completed (2026-07-10, build 51)

## What it does

Users can check off itinerary items during the trip. Tapping the coloured timeline dot on any plan item toggles its done state. Done items appear visually dimmed so the remaining tasks stand out at a glance.

## Visual behaviour

| State | Dot | Title | Location | Links | Chevron |
|-------|-----|-------|----------|-------|---------|
| Undone | Coloured circle (item type colour) | Normal | Shown | Shown | Shown |
| Done | Green checkmark icon | Strikethrough + grey | Hidden | Hidden | Hidden |

Transitions are animated via `AnimatedSwitcher` (dot) and no rebuild delay (text decoration).

## Technical implementation

### Database
- Migration `010_itinerary_item_done.sql` adds `is_done boolean not null default false` to `itinerary_items`.

### Model (`lib/data/plan_data.dart`)
- `ItineraryItem.isDone` field (default `false`).
- `ItineraryItem.copyWith({bool? isDone})` for immutable updates.

### Service (`lib/core/supabase/plan_service.dart`)
- `_itemFromRow` reads `is_done`.
- `updateItem` writes `is_done` on full edits.
- `PlanService.toggleDone(String itemId, {required bool done})` — lightweight dedicated method that sends only `{'is_done': done}` — avoids sending the full payload on every checkbox tap.

### UI
- **`lib/screens/plan/item_tile.dart`** — `ItineraryItemTile` gains `onToggleDone` callback; the timeline dot column is wrapped in `GestureDetector`; `AnimatedSwitcher` between the undone dot and done checkmark icon.
- **`lib/screens/plan/day_card.dart`** — `TripDayCard` and `_ReorderableItemList` forward `onToggleDone` down to each tile.
- **`lib/screens/plan_screen.dart`** — `_toggleItemDone(String itemId)` applies an optimistic state mutation via `copyWith`, then calls `PlanService.toggleDone` in the background. On error, falls back to `_loadAll(silent: true)`.

## Connections
- Realtime subscription on `itinerary_items` already propagates done-state changes from other group members automatically.
- The `ItemDetailScreen` full-edit path also writes `is_done` via `updateItem`, so it stays in sync.

## Not in scope
- Done items are not sorted to the bottom (the list stays in time order — reordering while checking off is a separate UX question).
- No "completion percentage" badge on the day header (potential future improvement).
