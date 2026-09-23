-- Allow any trip member to update (rename) a document, not just the uploader or owner.
drop policy if exists "documents: uploader or owner can update" on documents;

create policy "documents: any member can update"
  on documents for update
  using  (is_trip_member(trip_id))
  with check (is_trip_member(trip_id));
