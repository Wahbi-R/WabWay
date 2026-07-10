-- Shared packing list: one set of items per trip, visible to all members.
-- Members can check off their own items; anyone can add/delete.

create table if not exists packing_items (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references trips(id) on delete cascade,
  title         text not null,
  assigned_to   uuid references auth.users(id) on delete set null,
  is_packed     boolean not null default false,
  packed_by     uuid references auth.users(id) on delete set null,
  sort_order    int not null default 0,
  created_by    uuid not null references auth.users(id) on delete cascade,
  created_at    timestamptz not null default now()
);

create index packing_items_trip_idx on packing_items(trip_id, sort_order);

alter table packing_items enable row level security;

create policy "trip members can read packing items"
  on packing_items for select
  using (
    exists (
      select 1 from trip_members
      where trip_members.trip_id = packing_items.trip_id
        and trip_members.user_id = auth.uid()
    )
  );

create policy "trip members can insert packing items"
  on packing_items for insert
  with check (
    auth.uid() = created_by
    and exists (
      select 1 from trip_members
      where trip_members.trip_id = packing_items.trip_id
        and trip_members.user_id = auth.uid()
    )
  );

create policy "trip members can update packing items"
  on packing_items for update
  using (
    exists (
      select 1 from trip_members
      where trip_members.trip_id = packing_items.trip_id
        and trip_members.user_id = auth.uid()
    )
  );

create policy "trip members can delete packing items"
  on packing_items for delete
  using (
    exists (
      select 1 from trip_members
      where trip_members.trip_id = packing_items.trip_id
        and trip_members.user_id = auth.uid()
    )
  );
