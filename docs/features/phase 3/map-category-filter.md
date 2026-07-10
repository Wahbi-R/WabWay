# Map Category Filter Chips

**Build 96 · 2026-07-10**

## Problem

The map shows all spot categories simultaneously. With many spots across diverse categories (restaurants, hotels, parks, activities), the map becomes cluttered. There was no way to isolate one type — e.g., "just show me restaurants."

## Solution

A horizontal scrollable chip strip floats at the top of the map view (as a `Positioned` overlay inside the `Stack`). Each chip shows:
- Category icon
- Category name + count of mapped spots in that category
- Active state: paper background with strong border and shadow
- Hidden state: dimmed background with faint border, reduced font weight

Tapping a chip toggles it from visible → hidden. The `_visibleSpots` getter filters `_mappedSpots` against `_hiddenCategories`. Map markers use `_visibleSpots` instead of `_mappedSpots`.

The strip only appears when 2+ categories are present (`_presentCategories.length >= 2`), so solo-category trips see no change.

## Files changed

- `lib/screens/map_screen.dart`
  - Added `Set<SpotCategory> _hiddenCategories = {}` state field
  - Added `_visibleSpots` getter — filtered view of `_mappedSpots`
  - Added `_presentCategories` getter — deduped ordered list of categories with mapped spots
  - Added `_categoryFilterStrip()` — scrollable chip row overlaid on the map
  - Updated `_buildMap()` to use `_visibleSpots` for markers and include `_categoryFilterStrip()` in the `Stack`

## No DB changes
All filtering is client-side on already-loaded spots.
