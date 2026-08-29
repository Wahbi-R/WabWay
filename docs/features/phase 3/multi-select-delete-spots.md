# Multi-select delete — Spots page

**Build:** 261  
**Date:** 2026-08-29

## What it does

Users can select multiple spots at once and delete them in bulk, rather than opening each spot detail and deleting one at a time.

## UX flow

1. **Enter selection mode** — long-press any spot tile on the list. The tile gains an animated circular checkbox overlay on its photo, and the app bar switches to selection mode.
2. **Add/remove spots** — tap any tile to toggle it in or out of the selection. Checkboxes animate in/out.
3. **Delete** — tap the delete button (trash icon on mobile, "Delete" button on desktop). A confirmation dialog shows the count and asks for confirmation.
4. **Exit without deleting** — tap ✕ (mobile) or the close button (desktop), or deselect all tiles (selection mode exits automatically when the count reaches zero).

## Permissions

Only spots the current user is allowed to delete are actually deleted. Allowed = spot was added by the current user, or the current user is the trip owner. Spots in the selection that the user can't delete are silently skipped; the permission check was already the same as the single-delete path. If *none* of the selected spots are deletable, a snackbar explains this instead of showing the confirmation dialog.

## Implementation notes

- State lives in `_SpotsScreenState`: `_selectionMode` (bool) + `_selectedIds` (Set<String>).
- `SpotListTile` gains `inSelectionMode` and `checkedForDelete` props; the checkbox is an `AnimatedContainer` overlaid on the `_PhotoSlot`.
- FAB is hidden during selection mode so it doesn't overlap the delete affordance.
- Desktop top bar switches to a selection-mode row (count label + danger Delete button + close button).
- Deletions run in parallel via `Future.wait`-equivalent sequential loop; failures surface a snackbar count.

## Edge cases

- If `_spots` is empty or a selected ID is no longer in the list (realtime delete by another member), the permission check uses `.firstOrNull` and skips missing IDs rather than crashing.
- Realtime updates during selection mode will reload the list silently; `_selectedIds` may contain IDs for spots that have disappeared — these are harmlessly skipped at delete time.
