-- =============================================================================
-- WabWay — Migration 022: trip_invites revoked_at + function fix
-- =============================================================================
-- The revoked_at column already exists in the remote DB (added manually).
-- This migration ensures it exists and recreates redeem_trip_invite so the
-- %ROWTYPE compiles against the current schema (column-count mismatch was
-- causing "something went wrong" errors when guests tried to redeem a code).

-- ─── Add revoked_at column if missing ────────────────────────────────────────

alter table trip_invites
  add column if not exists revoked_at timestamptz;

-- ─── Recreate redeem_trip_invite ──────────────────────────────────────────────
-- Forces recompilation against the current table schema (picks up revoked_at
-- in %ROWTYPE) and rejects codes that have been revoked.

create or replace function redeem_trip_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite trip_invites%rowtype;
begin
  -- Find a valid, non-expired, non-revoked invite (case-insensitive, trimmed).
  select * into v_invite
    from trip_invites
   where code       = upper(trim(p_code))
     and revoked_at is null
     and (expires_at is null or expires_at > now());

  if not found then
    raise exception 'invalid_or_expired_code' using errcode = 'P0002';
  end if;

  -- Add caller to trip_members; silently ignore if already a member.
  insert into trip_members (trip_id, user_id, role)
  values (v_invite.trip_id, auth.uid(), 'member')
  on conflict (trip_id, user_id) do nothing;

  -- Record first-use timestamp.
  update trip_invites
     set used_at = now()
   where id = v_invite.id and used_at is null;

  return v_invite.trip_id;
end;
$$;
