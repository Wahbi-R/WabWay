-- location_shares: live GPS broadcasts per user per trip
create table location_shares (
  id              uuid             primary key default gen_random_uuid(),
  trip_id         uuid             not null references trips(id)    on delete cascade,
  user_id         uuid             not null references profiles(id) on delete cascade,
  lat             double precision not null,
  lng             double precision not null,
  is_active       boolean          not null default true,
  last_updated_at timestamptz      not null default now(),
  unique(trip_id, user_id)
);

alter table location_shares enable row level security;

create policy "members can read location shares"
  on location_shares for select
  using (
    exists (
      select 1 from trip_members
      where trip_members.trip_id = location_shares.trip_id
        and trip_members.user_id = auth.uid()
    )
  );

create policy "users manage own location share"
  on location_shares for all
  using  (user_id = auth.uid())
  with check (user_id = auth.uid());


-- trip_messages: group chat within a trip (text + location pings)
create table trip_messages (
  id           uuid primary key default gen_random_uuid(),
  trip_id      uuid not null references trips(id)    on delete cascade,
  author_id    uuid not null references profiles(id) on delete cascade,
  body         text not null check (char_length(body) <= 1000),
  message_type text not null default 'text'
                check (message_type in ('text', 'location_ping')),
  lat          double precision,
  lng          double precision,
  created_at   timestamptz not null default now()
);

alter table trip_messages enable row level security;

create policy "members can read messages"
  on trip_messages for select
  using (
    exists (
      select 1 from trip_members
      where trip_members.trip_id = trip_messages.trip_id
        and trip_members.user_id = auth.uid()
    )
  );

create policy "members can insert messages"
  on trip_messages for insert
  with check (
    author_id = auth.uid()
    and exists (
      select 1 from trip_members
      where trip_members.trip_id = trip_messages.trip_id
        and trip_members.user_id = auth.uid()
    )
  );

create index on trip_messages (trip_id, created_at desc);
