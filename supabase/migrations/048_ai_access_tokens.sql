-- Build 419: personal access tokens for the WabWay MCP server (AI access).
--
-- A token lets an AI assistant (Claude, ChatGPT, …) read the owner's trips,
-- bookings and documents through wabway-server's /mcp endpoint. Only a
-- SHA-256 hash is stored; the plaintext is returned once by
-- create_ai_access_token and never again. wabway-server resolves the hash
-- with the service role key and scopes every read to the owner's trips.
--
-- Clients can list and revoke their own tokens but never insert directly
-- (no INSERT grant), so the hash always comes from the RPC.

create table public.ai_access_tokens (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name          text not null check (char_length(name) between 1 and 60),
  token_hash    text not null unique,
  token_prefix  text not null,
  created_at    timestamptz not null default now(),
  last_used_at  timestamptz,
  revoked_at    timestamptz
);

create index ai_access_tokens_user_idx on public.ai_access_tokens (user_id);

alter table public.ai_access_tokens enable row level security;

create policy "ai_access_tokens: owner reads"
  on public.ai_access_tokens for select to authenticated
  using (user_id = (select auth.uid()));

create policy "ai_access_tokens: owner revokes"
  on public.ai_access_tokens for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.ai_access_tokens from anon, authenticated;
grant select (id, user_id, name, token_prefix, created_at, last_used_at, revoked_at)
  on public.ai_access_tokens to authenticated;
grant update (revoked_at) on public.ai_access_tokens to authenticated;

-- Returns the plaintext token ("wbw_" + 64 hex chars). Shown to the user once.
create or replace function public.create_ai_access_token(p_name text)
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

  insert into public.ai_access_tokens (user_id, name, token_hash, token_prefix)
  values (
    v_uid,
    left(coalesce(v_name, 'AI assistant'), 60),
    encode(extensions.digest(v_token, 'sha256'), 'hex'),
    left(v_token, 12)
  );

  return v_token;
end;
$function$;

revoke execute on function public.create_ai_access_token(text) from public, anon;
grant execute on function public.create_ai_access_token(text) to authenticated;
