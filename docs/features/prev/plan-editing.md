# Plan Editing

## What it does

Itinerary days and items can now be edited, moved, and duplicated from the plan screen.

## Day editing

Tapping the pencil icon next to the item-count badge in any day card header opens an **Edit Day** sheet with:
- Date picker
- City field
- Notes field (leave blank to clear)

Changes are saved to Supabase via `PlanService.updateDay` and applied to local state immediately.

## Item actions

### Move to another day
Available via the inline **Move day** button (visible when there are ≥2 days) or the `⋮` sheet. Opens a day-picker sheet listing all other days; selecting one calls `PlanService.moveItem` and re-assigns the item locally.

### Duplicate item
Available via the inline **Duplicate** button or the `⋮` sheet. Calls `PlanService.duplicateItem`, which creates a copy titled `"<original> (copy)"` in the same day, and appends it to local state.

### Edit item
Existing `showAddItemSheet` opened pre-filled with the item's current values.

## Implementation

| File | Change |
|---|---|
| `lib/core/supabase/plan_service.dart` | `updateDay`, `moveItem`, `duplicateItem` methods |
| `lib/screens/plan/day_card.dart` | `TripDayCard.onEditDay`; pencil icon in `_DayHeader` |
| `lib/screens/plan/item_detail.dart` | `ItemDetailContent`/`ItemDetailScreen` accept `days`, `onMove`, `onDuplicate`; `_ActionsSection` exposes Move/Duplicate buttons; `_MoveToDaySheet` for day picker |
| `lib/screens/plan_screen.dart` | `_onEditDay`, `_onMoveItem`, `_onDuplicateItem` callbacks; `_EditDaySheet`; wired to both mobile and desktop layouts |
