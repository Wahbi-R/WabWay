-- =============================================================================
-- WabWay — Migration 002: trip_invites
-- =============================================================================

-- ─── Table ────────────────────────────────────────────────────────────────────

create table trip_invites (
  id          uuid        primary key default gen_random_uuid(),
  trip_id     uuid        not null references trips(id) on delete cascade,
  code        text        not null unique,
  created_by  uuid        references profiles(id),
  expires_at  timestamptz,
  used_at     timestamptz,
  created_at  timestamptz not null default now()
);

-- ─── RLS ──────────────────────────────────────────────────────────────────────

alter table trip_invites enable row level security;

-- Trip owners can view invites for their trip.
create policy "owner can view trip invites"
  on trip_invites for select
  using (
    exists (
      select 1 from trip_members
       where trip_members.trip_id = trip_invites.trip_id
         and trip_members.user_id = auth.uid()
         and trip_members.role    = 'owner'
    )
  );

-- Trip owners can create invites (direct INSERT is owner-only as a belt-and-
-- suspenders guard; the RPC also enforces this via security definer logic).
create policy "owner can create trip invites"
  on trip_invites for insert
  with check (
    exists (
      select 1 from trip_members
       where trip_members.trip_id = trip_invites.trip_id
         and trip_members.user_id = auth.uid()
         and trip_members.role    = 'owner'
    )
  );

-- Trip owners can delete invites for their trip.
create policy "owner can delete trip invites"
  on trip_invites for delete
  using (
    exists (
      select 1 from trip_members
       where trip_members.trip_id = trip_invites.trip_id
         and trip_members.user_id = auth.uid()
         and trip_members.role    = 'owner'
    )
  );

-- No direct UPDATE policy — used_at is written only by the redeem RPC
-- (security definer), which bypasses RLS.

-- ─── RPC: create_trip_invite ──────────────────────────────────────────────────
-- Called by trip owners. Generates a random 8-character code and inserts a
-- row that expires in 7 days. Returns the plain-text code.

create or replace function create_trip_invite(p_trip_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  -- Caller must be the trip owner.
  if not exists (
    select 1 from trip_members
     where trip_id = p_trip_id
       and user_id = auth.uid()
       and role    = 'owner'
  ) then
    raise exception 'not_owner' using errcode = 'P0001';
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

-- ─── RPC: redeem_trip_invite ──────────────────────────────────────────────────
-- Called by any authenticated user. Validates the code, adds the caller to
-- trip_members (no-op if already a member), records first-use timestamp, and
-- returns the trip_id so the client can navigate directly into the trip.

create or replace function redeem_trip_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite trip_invites%rowtype;
begin
  -- Find a valid, non-expired invite (case-insensitive, whitespace-trimmed).
  select * into v_invite
    from trip_invites
   where code       = upper(trim(p_code))
     and (expires_at is null or expires_at > now());

  if not found then
    raise exception 'invalid_or_expired_code' using errcode = 'P0002';
  end if;

  -- Add caller to trip_members; silently ignore if already a member.
  insert into trip_members (trip_id, user_id, role)
  values (v_invite.trip_id, auth.uid(), 'member')
  on conflict (trip_id, user_id) do nothing;

  -- Record first-use timestamp (codes are reusable; used_at tracks first use).
  update trip_invites
     set used_at = now()
   where id = v_invite.id and used_at is null;

  return v_invite.trip_id;
end;
$$;
