# Visited/Skipped Spot Styling

**Build 92 · 2026-07-10**

## Problem

Spots with a `visited` or `skipped` status looked identical to active spots in the list. Users had no way to scan quickly and tell which spots were already done — every tile had the same opacity and layout.

## Solution

`SpotListTile` now applies visual treatment based on `SpotStatus`:

- **Visited** — tile opacity 65%, green `check_circle_rounded` icon overlay in the bottom-right corner of the photo slot
- **Skipped** — tile opacity 45%, grey `cancel_rounded` icon overlay in the same position
- All other statuses — unchanged (full opacity, no overlay)

The overlay icon sits on a small white circle so it reads clearly over both image and gradient backgrounds.

## Files changed

- `lib/screens/spots/spot_list_tile.dart`
  - `SpotListTile.build()` — computes `isVisited`/`isSkipped`, wraps card in `Opacity`, passes overlay props to `_PhotoSlot`
  - `_PhotoSlot` — added `overlayIcon` and `overlayColor` params; renders overlay in a `Stack` with a positioned white circle badge

## No DB changes
Status is already stored in `spots.status`. No migration needed.
