# Spot Visited Status

**Build:** 69  
**Area:** Spots

## What it does

Adds a `visited` status to the spot lifecycle, letting the group mark places they've
actually been to. The full progression is now:

`idea → want to go → must-do → planned → confirmed → booked → visited`
(with `skipped` as an exit ramp at any stage)

## User-facing changes

- **"Mark as visited" button** appears at the bottom of every spot detail panel / screen
  when the spot is editable and not already visited or skipped. Tapping it sets the
  status to `visited` and the badge updates instantly.
- The badge shows "Visited" in the success (green) tone — same as "Booked" — so
  visited spots visually read as completed.
- Map markers for visited spots render in `kColorSuccess` (green) matching booked.

## Implementation

| Layer | Change |
|---|---|
| Supabase | Migration `014_spot_visited_status.sql` — `alter type spot_status add value if not exists 'visited' after 'booked'` |
| `lib/data/spot_data.dart` | Added `SpotStatus.visited`; label `'Visited'`; tone `WabwayBadgeTone.success` |
| `lib/core/supabase/spot_service.dart` | `_statusFrom` / `_statusToDb` now handle `'visited'` ↔ `SpotStatus.visited` |
| `lib/screens/spots/spot_detail.dart` | `_markVisited()` method calls `SpotService.updateSpot(status: SpotStatus.visited)`; `FilledButton` shown when `onEdit != null && status != visited && status != skipped` |
| `lib/screens/map_screen.dart` | Two exhaustive `switch` expressions updated with `SpotStatus.visited => kColorSuccess` |

## Notes

- No separate "visited at" timestamp field yet — that could be a follow-up.
- RLS unchanged: only trip members can update spots.
