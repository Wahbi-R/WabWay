# Owner Transfer

## Description

Trip owners can transfer ownership to any other member via a picker sheet. The operation is atomic (both role changes happen in a single `security definer` RPC). Owners also see a "Delete trip" option with a confirmation dialog. Non-owners see "Leave trip" instead.

## Key Files

- `lib/core/supabase/trip_service.dart` — `transferOwnership(tripId, newOwnerId)`, `deleteTrip()`, `leaveTrip()`
- `lib/screens/members_screen.dart` — member list with transfer sheet and delete/leave actions
- `supabase/migrations/003_rls_fixes_and_settlements.sql` — `transfer_trip_ownership` RPC + leave-trip RLS fix

## How It Works

**Transfer**: `TripService.transferOwnership()` calls the `transfer_trip_ownership(p_trip_id, p_new_owner_id)` RPC. The RPC:
1. Verifies the caller is the current owner.
2. Verifies the target is an existing member.
3. Sets target's `role = 'owner'` and caller's `role = 'member'` in one transaction.

**Leave**: Non-owners call `TripService.leaveTrip()` which deletes their own `trip_members` row. Migration 003 added the RLS policy `"trip_members: member can leave own trip"` allowing `user_id = auth.uid()` deletes (previously only owners could delete rows).

**Delete**: Owner-only. Calls `TripService.deleteTrip()` — cascades to all trip data via DB foreign keys.
