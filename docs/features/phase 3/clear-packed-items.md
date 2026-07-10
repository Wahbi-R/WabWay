# Clear Packed Items

**Build 98 · 2026-07-10**

## Problem

Once items are packed there was no quick way to remove all of them at once. Users had to delete items one-by-one via the popup menu on each tile — tedious for lists of 10+ items.

## Solution

A `⋮` overflow menu appears in the packing screen AppBar whenever at least one item is packed. The only action is "Clear packed items" (shown in red with a sweep icon). Selecting it shows a confirmation dialog that reports how many items will be removed. On confirm, packed items are removed optimistically from local state and `PackingService.clearPackedItems(tripId)` is called to delete them in Supabase. On error, a silent reload restores server state.

The menu is hidden when no items are packed, so it doesn't clutter the bar unnecessarily.

## Files changed

- `lib/core/supabase/packing_service.dart`
  - Added `clearPackedItems(String tripId)` — single `.delete().eq('trip_id', ...).eq('is_packed', true)` query

- `lib/screens/packing_screen.dart`
  - Added `_clearPacked()` — confirmation dialog + optimistic state removal + service call
  - AppBar `actions` — added `PopupMenuButton` with "Clear packed items" item, conditionally shown when `packed > 0`

## No DB migration

Bulk-deletes existing rows via the already-open `packing_items` table.
