-- =============================================================================
-- WabWay — Migration 004: activity_events table + travel_items.status column
-- =============================================================================

-- ─── activity_events ──────────────────────────────────────────────────────────

create table if not exists activity_events (
  id           uuid        primary key default gen_random_uuid(),
  trip_id      uuid        not null references trips(id) on delete cascade,
  actor_id     uuid        not null references profiles(id),
  event_type   text        not null,
  entity_id    uuid        not null,
  entity_title text,
  meta         jsonb,
  created_at   timestamptz not null default now()
);

create index if not exists activity_events_trip_id_idx
  on activity_events(trip_id, created_at desc);

alter table activity_events enable row level security;

do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'activity_events'
      and policyname = 'Trip members can view activity'
  ) then
    execute '
      create policy "Trip members can view activity"
        on activity_events for select
        using (
          exists (
            select 1 from trip_members
            where trip_members.trip_id = activity_events.trip_id
              and trip_members.user_id = auth.uid()
          )
        )';
  end if;
end $$;

-- ─── record_activity() trigger function ───────────────────────────────────────

create or replace function record_activity()
returns trigger language plpgsql security definer
set search_path = public
as $$
declare
  v_trip_id uuid;
  v_title   text;
  v_type    text;
begin
  v_type := TG_ARGV[0];

  if TG_TABLE_NAME = 'spots' then
    v_trip_id := NEW.trip_id;
    v_title   := NEW.name;
  elsif TG_TABLE_NAME = 'receipts' then
    v_trip_id := NEW.trip_id;
    v_title   := NEW.title || ' · ' || NEW.amount::text || ' ' || NEW.currency;
  elsif TG_TABLE_NAME = 'cash_withdrawals' then
    v_trip_id := NEW.trip_id;
    v_title   := NEW.amount::text || ' ' || NEW.currency;
  elsif TG_TABLE_NAME = 'travel_items' then
    v_trip_id := NEW.trip_id;
    v_title   := NEW.title;
  elsif TG_TABLE_NAME = 'itinerary_items' then
    select d.trip_id into v_trip_id
      from itinerary_days d where d.id = NEW.day_id;
    v_title := NEW.title;
  elsif TG_TABLE_NAME = 'documents' then
    v_trip_id := NEW.trip_id;
    v_title   := NEW.title;
  elsif TG_TABLE_NAME = 'trip_links' then
    v_trip_id := NEW.trip_id;
    v_title   := NEW.title;
  elsif TG_TABLE_NAME = 'trip_members' then
    v_trip_id := NEW.trip_id;
    v_title   := null;
  end if;

  if v_trip_id is null then
    return NEW;
  end if;

  insert into activity_events(trip_id, actor_id, event_type, entity_id, entity_title)
  values (v_trip_id, auth.uid(), v_type, NEW.id, v_title);

  return NEW;
end;
$$;

-- ─── Triggers (CREATE OR REPLACE requires PG 14+; Supabase runs PG 15) ────────

create or replace trigger trg_spot_added
  after insert on spots
  for each row execute function record_activity('spot_added');

create or replace trigger trg_receipt_added
  after insert on receipts
  for each row execute function record_activity('receipt_added');

create or replace trigger trg_withdrawal_added
  after insert on cash_withdrawals
  for each row execute function record_activity('withdrawal_added');

create or replace trigger trg_travel_item_added
  after insert on travel_items
  for each row execute function record_activity('travel_item_added');

create or replace trigger trg_plan_item_added
  after insert on itinerary_items
  for each row execute function record_activity('plan_item_added');

create or replace trigger trg_document_added
  after insert on documents
  for each row execute function record_activity('document_added');

create or replace trigger trg_link_added
  after insert on trip_links
  for each row execute function record_activity('link_added');

create or replace trigger trg_member_joined
  after insert on trip_members
  for each row execute function record_activity('member_joined');

-- ─── travel_items.status column ───────────────────────────────────────────────

alter table travel_items
  add column if not exists status text not null default 'booked'
  check (status in ('booked', 'tentative', 'cancelled'));
