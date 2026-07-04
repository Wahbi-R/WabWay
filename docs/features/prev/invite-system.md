# Improved Invite System

## What changed

The invite sheet now loads all of the trip's invite codes (active, used, expired) instead of just generating a new one blind. Owners can revoke codes before they're used.

## Features

- **Active codes** shown with expiry date, Copy and Revoke buttons
- **Used / expired codes** shown in a separate section (read-only)
- **Revoke** with confirmation dialog; optimistic removal with server revert on failure
- **Generate new code** button always available; creates a fresh single-use 7-day code
- **Status badges**: Active (blue), Used (green), Expired (red)
- Single-use by default: once redeemed, `used_at` is set and the code becomes inactive

## SQL changes required

If the `trip_invites` table doesn't already have `revoked_at`, `used_at`, and `expires_at` columns, run:

```sql
alter table trip_invites
  add column if not exists revoked_at timestamptz,
  add column if not exists used_at    timestamptz,
  add column if not exists expires_at timestamptz;

-- Update redeem function to stamp used_at
create or replace function redeem_trip_invite(p_code text)
returns uuid language plpgsql security definer as $$
declare
  v_invite  trip_invites%rowtype;
  v_trip_id uuid;
begin
  select * into v_invite
    from trip_invites
   where code = upper(p_code)
     and revoked_at is null
     and used_at    is null
     and (expires_at is null or expires_at > now())
  for update;

  if not found then
    raise exception 'invalid or expired invite code' using errcode = 'P0002';
  end if;

  -- Add user to trip
  insert into trip_members(trip_id, user_id, role)
  values (v_invite.trip_id, auth.uid(), 'member')
  on conflict do nothing;

  -- Mark as used
  update trip_invites
     set used_at = now()
   where id = v_invite.id;

  return v_invite.trip_id;
end;
$$;

-- RLS: trip owners can read/update their codes
create policy "Owner can view invites" on trip_invites for select
  using (exists (
    select 1 from trip_members
    where trip_members.trip_id = trip_invites.trip_id
      and trip_members.user_id = auth.uid()
      and trip_members.role = 'owner'
  ));

create policy "Owner can update invites" on trip_invites for update
  using (exists (
    select 1 from trip_members
    where trip_members.trip_id = trip_invites.trip_id
      and trip_members.user_id = auth.uid()
      and trip_members.role = 'owner'
  ));
```

## Files

| File | Change |
|---|---|
| `lib/data/invite_data.dart` | New `InviteCode` model with `isActive`, `isUsed`, `isExpired`, `displayCode` |
| `lib/core/supabase/invite_service.dart` | Added `loadInvites`, `revokeInvite`; `createInvite` now returns `InviteCode` |
| `lib/screens/members/invite_sheet.dart` | Rewritten: `DraggableScrollableSheet`; `_CodesSection` widget; active/inactive grouping; copy+revoke per code; generate new at bottom |
