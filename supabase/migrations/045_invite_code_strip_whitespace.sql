-- Build 412: invite codes are displayed as "1D70 D387" (space for readability).
-- Older app versions send the code exactly as typed, so the RPC strips ALL
-- whitespace and dashes, not just leading/trailing. Same signature → existing
-- grants are preserved; existing codes are unaffected.
create or replace function public.redeem_trip_invite(p_code text)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_invite trip_invites%rowtype;
begin
  -- Find a valid, non-expired, non-revoked invite (case-insensitive,
  -- ignoring any spaces/dashes the user typed).
  select * into v_invite
    from trip_invites
   where code       = upper(regexp_replace(p_code, '[\s-]', '', 'g'))
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
$function$;
