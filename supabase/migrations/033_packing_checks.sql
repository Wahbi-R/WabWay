-- Per-person packing checks: each member independently checks off each item.
-- The old single is_packed / assigned_to / packed_by columns are left in place
-- but ignored by the app going forward.

create table if not exists packing_checks (
  id          uuid primary key default gen_random_uuid(),
  item_id     uuid not null references packing_items(id) on delete cascade,
  trip_id     uuid not null references trips(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  checked_at  timestamptz not null default now(),
  unique (item_id, user_id)
);

create index packing_checks_item_idx on packing_checks(item_id);
create index packing_checks_trip_idx on packing_checks(trip_id, user_id);

alter table packing_checks enable row level security;

create policy "trip members can read packing checks"
  on packing_checks for select
  using (
    exists (
      select 1 from trip_members
      where trip_members.trip_id = packing_checks.trip_id
        and trip_members.user_id = auth.uid()
    )
  );

create policy "users can insert their own packing check"
  on packing_checks for insert
  with check (auth.uid() = user_id);

create policy "users can delete their own packing check"
  on packing_checks for delete
  using (auth.uid() = user_id);

do $$
begin
  begin
    alter publication supabase_realtime add table packing_items;
  exception when sqlstate '42710' then null;
  end;
  begin
    alter publication supabase_realtime add table packing_checks;
  exception when sqlstate '42710' then null;
  end;
end;
$$;
