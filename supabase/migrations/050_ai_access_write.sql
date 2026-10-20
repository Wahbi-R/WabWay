-- Build 424: AI access can add and edit (opt-in per token).
--
-- ai_access_tokens.can_write: chosen when the token is created; existing tokens
-- stay read-only. wabway-server performs writes AS THE USER (short-lived JWT),
-- so RLS and the activity-feed triggers apply exactly as in the app.
--
-- ai_created_items: every row an AI creates, so undo_ai_changes can only ever
-- remove what that token added. Server-only (service role); clients have no
-- access.

alter table public.ai_access_tokens
  add column can_write boolean not null default false;

grant select (can_write) on public.ai_access_tokens to authenticated;

-- New two-argument overload; the one-argument version from 048 stays for
-- older app builds (PostgREST picks the overload by the argument names sent).
create function public.create_ai_access_token(p_name text, p_can_write boolean)
 returns text
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  v_uid   uuid := auth.uid();
  v_name  text := nullif(btrim(coalesce(p_name, '')), '');
  v_token text;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  if (select count(*) from public.ai_access_tokens
       where user_id = v_uid and revoked_at is null) >= 10 then
    raise exception 'too_many_tokens' using errcode = 'P0001';
  end if;

  v_token := 'wbw_' || encode(extensions.gen_random_bytes(32), 'hex');

  insert into public.ai_access_tokens (user_id, name, token_hash, token_prefix, can_write)
  values (
    v_uid,
    left(coalesce(v_name, 'AI assistant'), 60),
    encode(extensions.digest(v_token, 'sha256'), 'hex'),
    left(v_token, 12),
    coalesce(p_can_write, false)
  );

  return v_token;
end;
$function$;

revoke execute on function public.create_ai_access_token(text, boolean) from public, anon;
grant execute on function public.create_ai_access_token(text, boolean) to authenticated;

create table public.ai_created_items (
  id           uuid primary key default gen_random_uuid(),
  token_id     uuid not null references public.ai_access_tokens(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  trip_id      uuid not null references public.trips(id) on delete cascade,
  entity_type  text not null,
  entity_id    uuid not null,
  label        text,
  created_at   timestamptz not null default now()
);

create index ai_created_items_token_idx on public.ai_created_items (token_id, created_at desc);

alter table public.ai_created_items enable row level security;
revoke all on public.ai_created_items from anon, authenticated;
