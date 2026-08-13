# Trip Connections — Cross-Section Linking

## What this is

Every entity in a trip (Spot, Plan item, Travel item, Stay, Doc, Link) should be
linkable to every other entity. Right now the app has scattered one-off foreign keys
for some pairs. This feature adds a universal `trip_connections` join table for all
the **currently missing** pairs, and exposes connections visually on every detail screen.

## Strategy: Option C (safe)

Keep all existing columns (`linked_spot_id`, `linked_doc_ids`, etc.) working exactly
as before. Add `trip_connections` only for the **new** pairs. The "Connected" section
on each detail screen reads from **both** sources and merges them visually.

Future cleanup (already in TODO #253): migrate old columns into `trip_connections`
and remove the scattered foreign keys.

## Existing links (do NOT touch)

| Source | Target | Column |
|---|---|---|
| `itinerary_items` | spot | `linked_spot_id` |
| `itinerary_items` | docs | `linked_doc_ids` (array) |
| `itinerary_items` | travel item | `linked_itinerary_item_id` / `linked_day_id` on travel |
| `accommodations` | spot | `linked_spot_id` |

## New pairs to implement via `trip_connections`

- Spot ↔ Travel item
- Spot ↔ Stay
- Spot ↔ Doc
- Spot ↔ Link
- Plan item ↔ Stay
- Travel item ↔ Stay
- Travel item ↔ Link
- Stay ↔ Link
- Doc ↔ Link

## Schema (migration 034)

```sql
create table trip_connections (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references trips(id) on delete cascade,
  entity_a_type text not null,
  entity_a_id   uuid not null,
  entity_b_type text not null,
  entity_b_id   uuid not null,
  created_by    uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  unique (entity_a_id, entity_b_id)
);
-- entity types: 'spot' | 'plan_item' | 'travel' | 'stay' | 'doc' | 'link'
```

RLS: trip members can read/insert/delete (delete only own).
Realtime: yes.

## Files to create

- `supabase/migrations/034_trip_connections.sql`
- `lib/data/connection_data.dart` — `EntityType` enum + `TripConnection` model
- `lib/core/supabase/connection_service.dart` — fetchForEntity, addConnection, removeConnection
- `lib/screens/shared/connections_section.dart` — universal widget dropped into detail screens

## Files to modify (add ConnectionsSection widget)

- `lib/screens/spots/spot_detail.dart`
- `lib/screens/plan/item_detail.dart`
- `lib/screens/travel/travel_item_detail.dart`
- `lib/screens/more/accommodation_detail.dart` (or wherever stay detail is)
- doc detail screen
- links/link detail screen

## ConnectionsSection widget spec

```
Connected
─────────────────────────────
🗺 Shibuya Crossing (Spot)       [×]
✈ Flight to Osaka (Travel)      [×]
📄 Hotel booking.pdf (Doc)      [×]
─────────────────────────────
+ Add connection
```

- Grouped chips or list rows, each showing entity type icon + name
- Tap a chip → navigate to that entity's detail screen
- [×] removes the connection
- "+ Add connection" opens `_ConnectionPickerSheet`

## ConnectionPickerSheet spec

Bottom sheet with a segmented control or tab row:
Spots | Plan | Travel | Stays | Docs | Links

Each tab shows the trip's items of that type. Tap to link.
Already-linked items are shown with a checkmark and can be tapped to unlink.

## Progress log

- [x] Build 252 committed (2026-08-13) — per-person packing, icon centering
- [x] Migration 034 — supabase/migrations/034_trip_connections.sql — pushed
- [x] Data layer — lib/data/connection_data.dart (EntityType, TripConnection, ResolvedConnection)
- [x] Service — lib/core/supabase/connection_service.dart (fetchForEntity, add, remove, subscribe)
- [x] ConnectionsSection + ConnectionPickerSheet — lib/screens/shared/connections_section.dart
- [x] Wire into spot_detail.dart — ConnectionsSection added before Comments
- [x] Wire into travel_item_detail.dart — ConnectionsSection added via Consumer before ActionsSection
- [x] Build 254 committed (2026-08-13)
- [ ] Wire into plan item_detail — lib/screens/plan/item_detail.dart
- [ ] Wire into stay detail — find accommodation detail screen path
- [ ] Wire into doc detail — find doc detail screen path
- [ ] Wire into links detail — find links detail screen path
- [ ] TODO #253 logged for future cleanup of scattered foreign keys ✓

## TODO for future cleanup (Build 253+ placeholder)

Already added to docs/TODO.md:
"Migrate scattered linked_spot_id / linked_doc_ids / linked_itinerary_item_id
columns into trip_connections and remove old columns + service methods."
