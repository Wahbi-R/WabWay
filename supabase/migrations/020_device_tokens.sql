create table if not exists device_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  token       text not null,
  platform    text not null default 'android', -- 'android' | 'ios'
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, token)
);

alter table device_tokens enable row level security;

-- Users can only manage their own tokens
create policy "own tokens" on device_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Edge Functions (service role) can read all tokens to send notifications
-- No extra policy needed — service role bypasses RLS
