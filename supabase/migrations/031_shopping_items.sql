create table if not exists shopping_items (
  id          uuid        primary key default gen_random_uuid(),
  trip_id     uuid        not null references trips(id) on delete cascade,
  name        text        not null,
  quantity    text,
  notes       text,
  spot_id     uuid        references spots(id) on delete set null,
  checked     boolean     not null default false,
  checked_by  uuid        references auth.users(id),
  checked_at  timestamptz,
  created_by  uuid        not null references auth.users(id),
  created_at  timestamptz not null default now(),
  sort_order  int         not null default 0
);

create index if not exists shopping_items_trip_id_idx on shopping_items(trip_id);

do $$ begin
  begin
    alter publication supabase_realtime add table shopping_items;
  exception when sqlstate '42710' then null;
  end;
end $$;
