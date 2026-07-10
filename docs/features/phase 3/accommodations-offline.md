# Accommodations Screen — Offline Resilience

**Build 55**

## Problem

`AccommodationsScreen` had a Realtime subscription (debounced silent reload on CDC events) but no offline handling — a network failure on a silent reload would silently drop the update with no user feedback.

## Solution

Added the same offline pattern used by `LinksScreen`, `DocsScreen`, and others:

- Added `_offline` bool field to state
- Silent reload failures now set `_offline = true` instead of swallowing the error
- Successful loads clear `_offline = false`  
- When `_offline` is true, wraps the scaffold in a `Stack` with `OfflineBanner` pinned to the bottom

## Files changed

- `lib/screens/accommodations/accommodations_screen.dart`
