-- Shared pinboard for quick group messages on a trip.
-- Members post short notes (check-in codes, meet times, reminders)
-- that appear on the home screen for everyone.
create table if not exists trip_pins (
  id         uuid primary key default gen_random_uuid(),
  trip_id    uuid not null references trips(id) on delete cascade,
  author_id  uuid not null references auth.users(id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 500),
  is_pinned  boolean not null default true,
  created_at timestamptz not null default now()
);

alter table trip_pins enable row level security;

create policy "Trip members can read pins"
  on trip_pins for select
  using (
    exists (
      select 1 from trip_members tm
      where tm.trip_id = trip_pins.trip_id
        and tm.user_id = auth.uid()
    )
  );

create policy "Trip members can insert pins"
  on trip_pins for insert
  with check (
    author_id = auth.uid()
    and exists (
      select 1 from trip_members tm
      where tm.trip_id = trip_pins.trip_id
        and tm.user_id = auth.uid()
    )
  );

create policy "Authors can update own pins"
  on trip_pins for update
  using (author_id = auth.uid());

create policy "Authors can delete own pins"
  on trip_pins for delete
  using (author_id = auth.uid());

create index on trip_pins (trip_id, created_at desc);
