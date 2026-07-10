-- Comments on plan itinerary items.
-- Lets trip members leave short notes on any activity, e.g.
-- "restaurant is closed Mondays" or "bring sunscreen".
create table if not exists itinerary_item_comments (
  id         uuid primary key default gen_random_uuid(),
  item_id    uuid not null references itinerary_items(id) on delete cascade,
  author_id  uuid not null references auth.users(id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

-- Only trip members who can see the item's trip may read/write comments.
alter table itinerary_item_comments enable row level security;

create policy "Trip members can read item comments"
  on itinerary_item_comments for select
  using (
    exists (
      select 1 from itinerary_items ii
      join itinerary_days id on id.id = ii.day_id
      join trip_members tm on tm.trip_id = id.trip_id
      where ii.id = itinerary_item_comments.item_id
        and tm.user_id = auth.uid()
    )
  );

create policy "Trip members can insert item comments"
  on itinerary_item_comments for insert
  with check (
    author_id = auth.uid()
    and exists (
      select 1 from itinerary_items ii
      join itinerary_days id on id.id = ii.day_id
      join trip_members tm on tm.trip_id = id.trip_id
      where ii.id = item_id
        and tm.user_id = auth.uid()
    )
  );

create policy "Authors can delete own item comments"
  on itinerary_item_comments for delete
  using (author_id = auth.uid());

create index on itinerary_item_comments (item_id, created_at);
