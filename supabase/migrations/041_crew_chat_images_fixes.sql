-- =============================================================================
-- WabWay — Migration 041: fix crew chat image migration issues
-- =============================================================================
-- 1. Extend trip_messages_message_type_check to allow 'image' (missed in 040).
-- 2. Re-create the trip-chat upload policy comparing folder as text instead of
--    casting to uuid — avoids an error on malformed object paths.

-- 1. Check constraint
alter table trip_messages
  drop constraint if exists trip_messages_message_type_check;

alter table trip_messages
  add constraint trip_messages_message_type_check
    check (message_type in ('text', 'location_ping', 'find_me', 'meetup_point', 'image'));

-- 2. Recreate upload policy with text comparison
drop policy if exists "trip members can upload chat images" on storage.objects;

create policy "trip members can upload chat images"
  on storage.objects for insert
  with check (
    bucket_id = 'trip-chat'
    and auth.uid() is not null
    and exists (
      select 1 from trip_members
       where trip_members.trip_id::text = (storage.foldername(name))[1]
         and trip_members.user_id = auth.uid()
    )
  );
