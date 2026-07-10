# Packing List

**Build 64**

## What it does

A shared packing checklist visible to all trip members. Accessible from:
- **Mobile**: More → Explore → Packing List
- **Desktop**: sidebar "Packing" entry

Features:
- Tap any item (or its checkbox) to toggle packed/unpacked state — animates with a smooth fill
- Tapped items show strikethrough text and move visually to "packed" state
- "X / Y" counter in the app bar header turns green when all items are packed
- Add items via the + button (dialog with text field)
- Delete items via the × trailing button
- Realtime sync: all members see changes immediately via Supabase Realtime (with 400ms debounce)
- Empty state with a "Add item" call-to-action

## How it connects

- `lib/data/packing_data.dart` — `PackingItem` model
- `lib/core/supabase/packing_service.dart` — `fetchAll`, `addItem`, `setPackedState`, `deleteItem`, `subscribe`; uses the same Realtime CDC pattern as other screens
- `lib/screens/packing_screen.dart` — main screen with `_PackingTile`, empty state, add-item dialog
- `lib/screens/more_screen.dart` — "Packing List" entry added to Explore section
- `lib/shell/app_shell.dart` — `_buildPacking` + desktop sidebar `_NavDest`
- `supabase/migrations/012_packing_list.sql` — `packing_items` table with full per-member RLS (read/insert/update/delete)

## Files changed

- `supabase/migrations/012_packing_list.sql` (new)
- `lib/data/packing_data.dart` (new)
- `lib/core/supabase/packing_service.dart` (new)
- `lib/screens/packing_screen.dart` (new)
- `lib/screens/more_screen.dart` — import + tile
- `lib/shell/app_shell.dart` — import + builder + desktop nav entry
