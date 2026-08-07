create table if not exists message_reactions (
  id         uuid primary key default gen_random_uuid(),
  message_id uuid not null references trip_messages(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  emoji      text not null,
  created_at timestamptz default now(),
  unique (message_id, user_id, emoji)
);

alter table message_reactions enable row level security;

create policy "trip_members_view_reactions"
  on message_reactions for select
  using (
    exists (
      select 1 from trip_messages m
      join trip_members tm on tm.trip_id = m.trip_id
      where m.id = message_reactions.message_id
        and tm.user_id = auth.uid()
    )
  );

create policy "trip_members_add_reactions"
  on message_reactions for insert
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from trip_messages m
      join trip_members tm on tm.trip_id = m.trip_id
      where m.id = message_reactions.message_id
        and tm.user_id = auth.uid()
    )
  );

create policy "trip_members_delete_reactions"
  on message_reactions for delete
  using (user_id = auth.uid());
