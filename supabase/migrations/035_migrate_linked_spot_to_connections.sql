-- Migration 035: Move itinerary_items.linked_spot_id → trip_connections
--
-- Backup first, then copy existing rows, then clear the old column.
-- The column is left in place (nullable, always null going forward) so the
-- app can be deployed without a breaking schema change; a future migration
-- can DROP it once the code no longer references it at all.

-- 1. Backup
create table if not exists _migration_backup_035_linked_spot as
select
  id          as item_id,
  trip_id,
  linked_spot_id as spot_id,
  now()       as backed_up_at
from itinerary_items
where linked_spot_id is not null;

-- 2. Copy into trip_connections (skip if already there)
insert into trip_connections
  (trip_id, entity_a_type, entity_a_id, entity_b_type, entity_b_id)
select
  trip_id,
  'plan_item',
  id,
  'spot',
  linked_spot_id
from itinerary_items
where linked_spot_id is not null
on conflict (entity_a_id, entity_b_id) do nothing;

-- 3. Clear the old column — new writes go to trip_connections only
update itinerary_items set linked_spot_id = null where linked_spot_id is not null;
