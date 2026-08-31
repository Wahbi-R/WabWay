-- =============================================================================
-- WabWay — Migration 038: tighten trip_invites RLS
-- =============================================================================
-- Drop the direct INSERT policy added in 037. All invite creation must go
-- through the create_trip_invite SECURITY DEFINER RPC, which validates
-- membership and generates a random code — preventing clients from choosing
-- predictable codes, spoofing created_by, or setting arbitrary expiry.
--
-- Add an UPDATE policy so owners can revoke invites (set revoked_at) via the
-- direct Supabase client call in InviteService.revokeInvite().

drop policy if exists "member can create trip invites" on trip_invites;

-- Trip owners can update invite rows for their trip (e.g. set revoked_at).
create policy "owner can update trip invites"
  on trip_invites for update
  using (
    exists (
      select 1 from trip_members
       where trip_members.trip_id = trip_invites.trip_id
         and trip_members.user_id = auth.uid()
         and trip_members.role    = 'owner'
    )
  )
  with check (
    exists (
      select 1 from trip_members
       where trip_members.trip_id = trip_invites.trip_id
         and trip_members.user_id = auth.uid()
         and trip_members.role    = 'owner'
    )
  );
