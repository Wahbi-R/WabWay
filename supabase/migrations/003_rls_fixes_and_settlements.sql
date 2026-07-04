-- =============================================================================
-- WabWay — Migration 003: RLS fixes + settlements table
-- =============================================================================

-- ─── Fix: Allow non-owner members to leave their own trip ─────────────────────
-- The existing DELETE policy only allows owners to remove OTHER members.
-- Non-owners have no policy to delete their own row → leaveTrip() was silently
-- failing. Add a policy that lets any member delete their own row.

create policy "trip_members: member can leave own trip"
  on trip_members for delete
  using (user_id = auth.uid());

-- ─── Fix: Ownership transfer via safe RPC ─────────────────────────────────────
-- The UPDATE policy blocks self-updates (user_id <> auth.uid()), so the
-- two-step client-side transfer (promote new → demote self) fails on step 2
-- because after promoting the new owner, the old owner tries to demote themselves
-- but the RLS condition user_id <> auth.uid() rejects it.
--
-- Solution: a security-definer RPC that does both steps atomically, bypassing
-- the self-update restriction.

create or replace function transfer_trip_ownership(
  p_trip_id      uuid,
  p_new_owner_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_id uuid;
begin
  v_caller_id := auth.uid();

  -- Must be authenticated
  if v_caller_id is null then
    raise exception 'Not authenticated' using errcode = 'P0001';
  end if;

  -- Caller must currently be an owner
  if not exists (
    select 1 from trip_members
    where trip_id = p_trip_id and user_id = v_caller_id and role = 'owner'
  ) then
    raise exception 'Only trip owners can transfer ownership' using errcode = 'P0001';
  end if;

  -- Target must be a member
  if not exists (
    select 1 from trip_members
    where trip_id = p_trip_id and user_id = p_new_owner_id
  ) then
    raise exception 'Target user is not a trip member' using errcode = 'P0001';
  end if;

  -- Cannot transfer to self
  if p_new_owner_id = v_caller_id then
    raise exception 'Cannot transfer ownership to yourself' using errcode = 'P0001';
  end if;

  -- Promote new owner
  update trip_members
    set role = 'owner'
    where trip_id = p_trip_id and user_id = p_new_owner_id;

  -- Demote current owner to member
  update trip_members
    set role = 'member'
    where trip_id = p_trip_id and user_id = v_caller_id;
end;
$$;

-- ─── Settlements table ────────────────────────────────────────────────────────

create table if not exists settlements (
  id              uuid        primary key default gen_random_uuid(),
  trip_id         uuid        not null references trips(id) on delete cascade,
  from_member_id  uuid        not null references auth.users(id),
  to_member_id    uuid        not null references auth.users(id),
  amount          numeric     not null check (amount > 0),
  currency        text        not null default 'JPY',
  note            text,
  settled_at      timestamptz not null default now(),
  settled_by      uuid        not null references auth.users(id)
);

create index if not exists idx_settlements_trip_id
  on settlements(trip_id);

alter table settlements enable row level security;

create policy "settlements: members can read"
  on settlements for select
  using (is_trip_member(trip_id));

create policy "settlements: members can insert"
  on settlements for insert
  with check (is_trip_member(trip_id) and settled_by = auth.uid());

create policy "settlements: inserter or owner can delete"
  on settlements for delete
  using (settled_by = auth.uid() or is_trip_owner(trip_id));

-- ─── trip_links table ─────────────────────────────────────────────────────────
-- (Created during links feature; RLS may not have been applied)

create table if not exists trip_links (
  id          uuid        primary key default gen_random_uuid(),
  trip_id     uuid        not null references trips(id) on delete cascade,
  title       text        not null,
  url         text        not null,
  notes       text,
  category    text,
  added_by    uuid        not null references profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Only enable RLS if not already enabled (idempotent-ish)
alter table trip_links enable row level security;

-- Policies are intentionally CREATE OR REPLACE-style via DROP IF EXISTS
-- so re-running this migration is safe.
do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'trip_links'
      and policyname = 'trip_links: members can read'
  ) then
    execute 'create policy "trip_links: members can read"
      on trip_links for select
      using (is_trip_member(trip_id))';
  end if;
  if not exists (
    select 1 from pg_policies
    where tablename = 'trip_links'
      and policyname = 'trip_links: members can insert'
  ) then
    execute 'create policy "trip_links: members can insert"
      on trip_links for insert
      with check (is_trip_member(trip_id) and added_by = auth.uid())';
  end if;
  if not exists (
    select 1 from pg_policies
    where tablename = 'trip_links'
      and policyname = 'trip_links: adder or owner can update'
  ) then
    execute 'create policy "trip_links: adder or owner can update"
      on trip_links for update
      using     (added_by = auth.uid() or is_trip_owner(trip_id))
      with check (is_trip_member(trip_id))';
  end if;
  if not exists (
    select 1 from pg_policies
    where tablename = 'trip_links'
      and policyname = 'trip_links: adder or owner can delete'
  ) then
    execute 'create policy "trip_links: adder or owner can delete"
      on trip_links for delete
      using (added_by = auth.uid() or is_trip_owner(trip_id))';
  end if;
end $$;

-- ─── activity_events table ────────────────────────────────────────────────────
-- (May exist from activity feature; ensure RLS is on)

alter table if exists activity_events enable row level security;
