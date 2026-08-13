-- Universal cross-entity linking table (Option C: new pairs only).
-- Existing foreign keys (linked_spot_id, linked_doc_ids, etc.) are left intact.
-- entity types: 'spot' | 'plan_item' | 'travel' | 'stay' | 'doc' | 'link'

create table if not exists trip_connections (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references trips(id) on delete cascade,
  entity_a_type text not null,
  entity_a_id   uuid not null,
  entity_b_type text not null,
  entity_b_id   uuid not null,
  created_by    uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  unique (entity_a_id, entity_b_id)
);

create index trip_connections_trip_idx      on trip_connections(trip_id);
create index trip_connections_entity_a_idx  on trip_connections(entity_a_id);
create index trip_connections_entity_b_idx  on trip_connections(entity_b_id);

alter table trip_connections enable row level security;

create policy "trip members can read connections"
  on trip_connections for select
  using (
    exists (
      select 1 from trip_members
      where trip_members.trip_id = trip_connections.trip_id
        and trip_members.user_id = auth.uid()
    )
  );

create policy "trip members can insert connections"
  on trip_connections for insert
  with check (
    auth.uid() = created_by
    and exists (
      select 1 from trip_members
      where trip_members.trip_id = trip_connections.trip_id
        and trip_members.user_id = auth.uid()
    )
  );

create policy "trip members can delete connections"
  on trip_connections for delete
  using (
    exists (
      select 1 from trip_members
      where trip_members.trip_id = trip_connections.trip_id
        and trip_members.user_id = auth.uid()
    )
  );

do $$
begin
  begin
    alter publication supabase_realtime add table trip_connections;
  exception when sqlstate '42710' then null;
  end;
end;
$$;
