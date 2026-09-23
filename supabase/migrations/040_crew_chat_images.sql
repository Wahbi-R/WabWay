-- =============================================================================
-- WabWay — Migration 040: crew chat image uploads
-- =============================================================================
-- Adds image_url to trip_messages so users can share photos in group chat.
-- Creates the trip-chat storage bucket (public) with RLS so only trip members
-- can upload, and only the uploader can delete their own files.

-- 1. Column on trip_messages
alter table trip_messages add column if not exists image_url text;

-- 2. Storage bucket
insert into storage.buckets (id, name, public)
values ('trip-chat', 'trip-chat', true)
on conflict (id) do nothing;

-- 3. Only trip members may upload into their trip's folder
create policy "trip members can upload chat images"
  on storage.objects for insert
  with check (
    bucket_id = 'trip-chat'
    and auth.uid() is not null
    and exists (
      select 1 from trip_members
       where trip_members.trip_id = (storage.foldername(name))[1]::uuid
         and trip_members.user_id = auth.uid()
    )
  );

-- 4. Uploader can delete their own images
create policy "uploader can delete chat images"
  on storage.objects for delete
  using (
    bucket_id = 'trip-chat'
    and owner = auth.uid()
  );
