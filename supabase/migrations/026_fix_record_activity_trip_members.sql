-- Fix record_activity() trigger: trip_members has no `id` column (composite PK).
-- Use NEW.user_id as the entity_id for member_joined events.

create or replace function record_activity()
returns trigger language plpgsql security definer
set search_path = public
as $$
declare
  v_trip_id   uuid;
  v_title     text;
  v_type      text;
  v_entity_id uuid;
begin
  v_type := TG_ARGV[0];

  if TG_TABLE_NAME = 'spots' then
    v_trip_id   := NEW.trip_id;
    v_title     := NEW.name;
    v_entity_id := NEW.id;
  elsif TG_TABLE_NAME = 'receipts' then
    v_trip_id   := NEW.trip_id;
    v_title     := NEW.title || ' · ' || NEW.amount::text || ' ' || NEW.currency;
    v_entity_id := NEW.id;
  elsif TG_TABLE_NAME = 'cash_withdrawals' then
    v_trip_id   := NEW.trip_id;
    v_title     := NEW.amount::text || ' ' || NEW.currency;
    v_entity_id := NEW.id;
  elsif TG_TABLE_NAME = 'travel_items' then
    v_trip_id   := NEW.trip_id;
    v_title     := NEW.title;
    v_entity_id := NEW.id;
  elsif TG_TABLE_NAME = 'itinerary_items' then
    select d.trip_id into v_trip_id
      from itinerary_days d where d.id = NEW.day_id;
    v_title     := NEW.title;
    v_entity_id := NEW.id;
  elsif TG_TABLE_NAME = 'documents' then
    v_trip_id   := NEW.trip_id;
    v_title     := NEW.title;
    v_entity_id := NEW.id;
  elsif TG_TABLE_NAME = 'trip_links' then
    v_trip_id   := NEW.trip_id;
    v_title     := NEW.title;
    v_entity_id := NEW.id;
  elsif TG_TABLE_NAME = 'trip_members' then
    v_trip_id   := NEW.trip_id;
    v_title     := null;
    v_entity_id := NEW.user_id;  -- trip_members has no id column
  end if;

  if v_trip_id is null then
    return NEW;
  end if;

  insert into activity_events(trip_id, actor_id, event_type, entity_id, entity_title)
  values (v_trip_id, auth.uid(), v_type, v_entity_id, v_title);

  return NEW;
end;
$$;
