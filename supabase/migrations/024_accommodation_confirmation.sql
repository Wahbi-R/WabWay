create table if not exists accommodations (
  id               uuid primary key default gen_random_uuid(),
  trip_id          uuid not null references trips(id) on delete cascade,
  name             text not null,
  url              text,
  city             text not null default '',
  address          text,
  latitude         float8,
  longitude        float8,
  price_per_night  numeric,
  currency         text not null default 'USD',
  check_in         date,
  check_out        date,
  status           text not null default 'brainstorming',
  source           text,
  notes            text,
  image_url        text,
  confirmation_number text,
  created_by       uuid references auth.users(id),
  created_at       timestamptz not null default now()
);

alter table accommodations enable row level security;

create policy "trip_members_view_accommodations"
  on accommodations for select
  using (
    exists (
      select 1 from trip_members tm
      where tm.trip_id = accommodations.trip_id
        and tm.user_id = auth.uid()
    )
  );

create policy "trip_members_insert_accommodations"
  on accommodations for insert
  with check (
    exists (
      select 1 from trip_members tm
      where tm.trip_id = accommodations.trip_id
        and tm.user_id = auth.uid()
    )
  );

create policy "trip_members_update_accommodations"
  on accommodations for update
  using (
    exists (
      select 1 from trip_members tm
      where tm.trip_id = accommodations.trip_id
        and tm.user_id = auth.uid()
    )
  );

create policy "trip_members_delete_accommodations"
  on accommodations for delete
  using (
    exists (
      select 1 from trip_members tm
      where tm.trip_id = accommodations.trip_id
        and tm.user_id = auth.uid()
    )
  );
