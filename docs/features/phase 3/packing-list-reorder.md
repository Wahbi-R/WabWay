# Packing List Drag-to-Reorder

**Build 95 · 2026-07-10**

## Problem

Packing list items couldn't be manually reordered. The `sort_order` column existed in the DB but was only set at insert time and never updated by the UI.

## Solution

The unpacked section of the packing list is now a `SliverReorderableList`. Each tile shows a `≡` drag handle (via `ReorderableDragStartListener`) when not searching. Dragging an item reorders it optimistically and calls `PackingService.reorderItems()` to persist the new order.

The packed section remains a regular `SliverList` — reordering packed items has no meaningful effect so it's intentionally excluded.

Searching hides drag handles (`canReorder = _search.isEmpty`) since the visible subset doesn't represent the full list order, which would make drags confusing.

## Files changed

- `lib/core/supabase/packing_service.dart`
  - Added `reorderItems(List<PackingItem> ordered)` — bulk upsert of `(id, sort_order)` pairs

- `lib/screens/packing_screen.dart`
  - `_PackingTile` — added `super.key`, `index`, and `showHandle` params; renders `ReorderableDragStartListener` in trailing row
  - `_PackingScreenState._reorder()` — new method; moves item in local list and calls service
  - `_PackingScreenState._buildList()` — replaced `ListView.builder` with `CustomScrollView` + `SliverPadding(SliverReorderableList)` + `SliverToBoxAdapter` header + `SliverList` for packed items
  
## No DB migration
`sort_order` column already exists in `packing_items`.
