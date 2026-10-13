-- Build 417: make trip_connections the one linking table.
-- COPY (not move) legacy document_links into trip_connections so every
-- "Connected" section shows them. document_links rows are kept untouched;
-- the app reads both and de-duplicates. Insert-only, idempotent.
do $$
declare
  before_links int;
  before_conns int;
  expected int;
  after_conns int;
begin
  select count(*) into before_links from public.document_links;
  select count(*) into before_conns from public.trip_connections;

  with src as (
    select d.trip_id,
           dl.created_by,
           dl.document_id,
           case dl.linked_type::text
             when 'spot'            then 'spot'
             when 'travel_item'     then 'travel'
             when 'receipt'         then 'receipt'
             when 'cash_withdrawal' then 'cash'
             when 'itinerary_item'  then 'plan_item'
           end as peer_type,
           dl.linked_id,
           dl.created_at
      from public.document_links dl
      join public.documents d on d.id = dl.document_id
     where dl.linked_type::text in ('spot','travel_item','receipt','cash_withdrawal','itinerary_item')
  ), new_rows as (
    select s.* from src s
     where not exists (
       select 1 from public.trip_connections c
        where (c.entity_a_id = s.document_id and c.entity_b_id = s.linked_id)
           or (c.entity_a_id = s.linked_id and c.entity_b_id = s.document_id)
     )
  )
  select count(*) into expected from new_rows;

  insert into public.trip_connections
    (trip_id, created_by, entity_a_type, entity_a_id, entity_b_type, entity_b_id, created_at)
  select s.trip_id, s.created_by, 'doc', s.document_id, s.peer_type, s.linked_id, s.created_at
    from (
      select d.trip_id, dl.created_by, dl.document_id,
             case dl.linked_type::text
               when 'spot' then 'spot' when 'travel_item' then 'travel'
               when 'receipt' then 'receipt' when 'cash_withdrawal' then 'cash'
               when 'itinerary_item' then 'plan_item'
             end as peer_type,
             dl.linked_id, dl.created_at
        from public.document_links dl
        join public.documents d on d.id = dl.document_id
       where dl.linked_type::text in ('spot','travel_item','receipt','cash_withdrawal','itinerary_item')
    ) s
   where not exists (
     select 1 from public.trip_connections c
      where (c.entity_a_id = s.document_id and c.entity_b_id = s.linked_id)
         or (c.entity_a_id = s.linked_id and c.entity_b_id = s.document_id)
   )
  on conflict (entity_a_id, entity_b_id) do nothing;

  select count(*) into after_conns from public.trip_connections;

  -- Verify: source untouched, connections grew by exactly the new rows.
  if (select count(*) from public.document_links) <> before_links then
    raise exception 'document_links changed (% -> %)', before_links,
      (select count(*) from public.document_links);
  end if;
  if after_conns <> before_conns + expected then
    raise exception 'trip_connections expected % new rows, got %', expected, after_conns - before_conns;
  end if;
  raise notice 'copied % document_links into trip_connections', expected;
end $$;
