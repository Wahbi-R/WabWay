-- =============================================================================
-- WabWay — Migration 037: allow any trip member to create/view invite codes
-- =============================================================================

-- Drop owner-only SELECT/INSERT policies and replace with member-level ones.

drop policy if exists "owner can view trip invites"   on trip_invites;
drop policy if exists "owner can create trip invites" on trip_invites;

-- Any trip member can view invite codes for their trip.
create policy "member can view trip invites"
  on trip_invites for select
  using (
    exists (
      select 1 from trip_members
       where trip_members.trip_id = trip_invites.trip_id
         and trip_members.user_id = auth.uid()
    )
  );

-- Any trip member can create invites (RPC also enforces membership).
create policy "member can create trip invites"
  on trip_invites for insert
  with check (
    exists (
      select 1 from trip_members
       where trip_members.trip_id = trip_invites.trip_id
         and trip_members.user_id = auth.uid()
    )
  );

-- ─── RPC: create_trip_invite — updated to allow any member ───────────────────

create or replace function create_trip_invite(p_trip_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  -- Caller must be a trip member.
  if not exists (
    select 1 from trip_members
     where trip_id = p_trip_id
       and user_id = auth.uid()
  ) then
    raise exception 'not_member' using errcode = 'P0001';
  end if;

  -- Generate an 8-character uppercase hex code from a fresh UUID.
  v_code := upper(left(replace(gen_random_uuid()::text, '-', ''), 8));

  insert into trip_invites (trip_id, code, created_by, expires_at)
  values (
    p_trip_id,
    v_code,
    auth.uid(),
    now() + interval '7 days'
  );

  return v_code;
end;
$$;
