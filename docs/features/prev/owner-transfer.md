# Owner Transfer / Leave-Trip Safety

## Overview

Owners can transfer ownership to any other trip member or permanently delete the trip. Non-owners can leave the trip. The "Leave trip" button is hidden from owners, preventing last-owner abandonment.

## New actions (owner-only)

### Transfer ownership
- "Transfer ownership" row in More → Trip settings → opens `_TransferOwnershipSheet`
- Member picker list shows all non-owner members
- Selecting a member enables the "Transfer" button
- On confirm: promotes chosen member to `owner`, demotes current user to `member` via `TripService.transferOwnership`
- `TripState.refresh` is called so the UI reflects the new role immediately

### Delete trip
- "Delete trip" row (red) in More → Trip settings → confirmation `AlertDialog`
- On confirm: `TripService.deleteTrip` deletes the trip row (cascade deletes members/data)
- `TripState.refresh` called after deletion

## Leave trip (non-owner)

Pre-existing flow — unchanged. Shown only when `!isOwner`.

## Service additions (`lib/core/supabase/trip_service.dart`)

```dart
static Future<void> transferOwnership(String tripId, String newOwnerId)
static Future<void> deleteTrip(String tripId)
```

`transferOwnership` issues two sequential updates: promote new owner, then demote current user. These should ideally be wrapped in a Supabase RPC transaction — add an RPC if concurrent-edit safety becomes a concern.
