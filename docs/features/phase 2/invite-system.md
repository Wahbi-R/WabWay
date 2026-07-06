# Invite System

## Description

Trip owners can generate single-use, expiring invite codes. All active, used, and expired codes for a trip are visible in the invite management sheet. Codes can be revoked, and new ones generated on demand.

## Key Files

- `lib/core/supabase/invite_service.dart` — `loadInvites()`, `createInvite()`, `revokeInvite()`, `redeemInvite()`
- `lib/data/invite_data.dart` — `InviteCode` model
- `lib/screens/members_screen.dart` — invite management UI (owner-only)
- `supabase/migrations/002_trip_invites.sql` — `trip_invites` table and `create_trip_invite` / `redeem_trip_invite` RPCs

## How It Works

- **Creating**: `InviteService.createInvite(tripId)` calls the `create_trip_invite` RPC (generates a random code, sets `expires_at` to 7 days, stores single-use intent).
- **Displaying**: `loadInvites()` fetches all non-revoked rows ordered by `created_at DESC`. The UI shows status badges — active, used (`used_at` set), or expired (`expires_at < now()`).
- **Revoking**: sets `revoked_at` via a direct update; the invite disappears from `loadInvites()` on next fetch.
- **Redeeming**: the `redeem_trip_invite` RPC validates the code, adds the caller to `trip_members`, marks `used_at`, and returns the `trip_id`.

## Setup

Migration `002_trip_invites.sql` must be applied. The RPCs are `security definer` so they bypass RLS for the join operation.
