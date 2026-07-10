# Spot Status Quick Actions

**Build 94 · 2026-07-10**

## Problem

The spot detail screen had a single "Mark as visited" button but no way to mark a spot as skipped from the detail view. Users who had already visited or skipped a spot had no way to revert the status without opening the full edit sheet.

## Solution

The status quick-action row at the bottom of the spot detail now handles three cases:

**Active spot (not visited / not skipped):**
- "Mark as visited" — green `FilledButton`, full weight (flex 3)
- "Skip" — outlined `OutlinedButton`, lighter weight (flex 2)

**Already visited or skipped:**
- "Mark as confirmed" — outlined `OutlinedButton` with undo icon; reverts to `SpotStatus.confirmed`

All three actions share a single `_setStatus(SpotStatus)` helper; `_markVisited`, `_markSkipped`, and `_markConfirmed` are one-liner delegates.

## Files changed

- `lib/screens/spots/spot_detail.dart`
  - Replaced `_markVisited()` body with `_setStatus(SpotStatus)` helper
  - Added `_markSkipped()` and `_markConfirmed()` delegates
  - Replaced old single-button section with conditional three-case layout

## No DB changes
`SpotStatus` and `spots.status` already support all values.
