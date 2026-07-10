-- Emergency info card: one row per trip, stores key contacts and numbers
-- accessible offline via the app's cached data.

create table if not exists trip_emergency_info (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references trips(id) on delete cascade,
  -- Insurance
  insurance_provider   text,
  insurance_policy_num text,
  insurance_phone      text,
  -- Credit card emergency line
  card_emergency_phone text,
  -- Local emergency number at the destination (112, 911, 110, etc.)
  local_emergency_num  text,
  -- Nearby hospital / clinic (free text)
  nearest_hospital     text,
  -- Embassy contacts (jsonb array: [{country, phone, address}])
  embassy_contacts     jsonb not null default '[]',
  -- Extra notes
  notes                text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (trip_id)
);

-- Only trip members can read/write emergency info for their trip
alter table trip_emergency_info enable row level security;

create policy "trip members can read emergency info"
  on trip_emergency_info for select
  using (
    exists (
      select 1 from trip_members
      where trip_members.trip_id = trip_emergency_info.trip_id
        and trip_members.user_id = auth.uid()
    )
  );

create policy "trip members can upsert emergency info"
  on trip_emergency_info for insert
  with check (
    exists (
      select 1 from trip_members
      where trip_members.trip_id = trip_emergency_info.trip_id
        and trip_members.user_id = auth.uid()
    )
  );

create policy "trip members can update emergency info"
  on trip_emergency_info for update
  using (
    exists (
      select 1 from trip_members
      where trip_members.trip_id = trip_emergency_info.trip_id
        and trip_members.user_id = auth.uid()
    )
  );
