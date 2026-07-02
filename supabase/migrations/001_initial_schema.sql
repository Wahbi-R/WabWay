-- =============================================================================
-- WabWay — Supabase SQL Migration v3 (initial schema)
-- =============================================================================

-- ─── Extensions ───────────────────────────────────────────────────────────────

create extension if not exists "pgcrypto";

-- ─── Enums ────────────────────────────────────────────────────────────────────

create type spot_category as enum (
  'food', 'landmark', 'nature', 'experience', 'shopping', 'nightlife'
);

create type spot_status as enum (
  'idea', 'want_to_go', 'must_do', 'planned', 'booked', 'skipped'
);

create type vote_type as enum (
  'must_do', 'want', 'maybe', 'skip'
);

create type doc_type as enum (
  'flight', 'hotel', 'train', 'ticket', 'reservation',
  'receipt', 'insurance', 'form', 'screenshot', 'other'
);

create type doc_linked_type as enum (
  'spot', 'travel_item', 'receipt', 'cash_withdrawal',
  'itinerary_item', 'itinerary_day', 'trip'
);

create type receipt_category as enum (
  'food', 'transport', 'accommodation', 'activity', 'shopping', 'other'
);

create type itinerary_item_type as enum (
  'spot', 'travel', 'food', 'activity', 'free_time', 'transport', 'other'
);

create type travel_item_type as enum (
  'flight', 'hotel', 'train', 'ticket', 'reservation', 'other'
);

create type trip_member_role as enum ('owner', 'member');

-- ─── Shared updated_at trigger ────────────────────────────────────────────────

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ─── Tables ───────────────────────────────────────────────────────────────────

-- profiles ─────────────────────────────────────────────────────────────────────

create table profiles (
  id            uuid        primary key references auth.users(id) on delete cascade,
  display_name  text        not null,
  email         text        not null,
  avatar_url    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create trigger trg_profiles_updated_at
  before update on profiles
  for each row execute function set_updated_at();

create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into profiles (id, display_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    coalesce(new.email, '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- trips ────────────────────────────────────────────────────────────────────────

create table trips (
  id                uuid        primary key default gen_random_uuid(),
  name              text        not null,
  destination       text,
  start_date        date,
  end_date          date,
  default_currency  text        not null default 'JPY',
  cover_image_url   text,
  created_by        uuid        not null references profiles(id),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint trips_dates_check
    check (end_date is null or end_date >= start_date),
  constraint trips_currency_fmt
    check (default_currency ~ '^[A-Z]{3}$')
);

create trigger trg_trips_updated_at
  before update on trips
  for each row execute function set_updated_at();

-- trip_members ─────────────────────────────────────────────────────────────────

create table trip_members (
  trip_id    uuid             not null references trips(id) on delete cascade,
  user_id    uuid             not null references profiles(id) on delete cascade,
  role       trip_member_role not null default 'member',
  joined_at  timestamptz      not null default now(),
  primary key (trip_id, user_id)
);

-- spots ────────────────────────────────────────────────────────────────────────

create table spots (
  id          uuid          primary key default gen_random_uuid(),
  trip_id     uuid          not null references trips(id) on delete cascade,
  name        text          not null,
  city        text          not null,
  area        text,
  category    spot_category not null,
  status      spot_status   not null default 'idea',
  source_url  text,
  maps_url    text,
  notes       text,
  added_by    uuid          not null references profiles(id),
  created_at  timestamptz   not null default now(),
  updated_at  timestamptz   not null default now()
);

create trigger trg_spots_updated_at
  before update on spots
  for each row execute function set_updated_at();

-- spot_votes ───────────────────────────────────────────────────────────────────

create table spot_votes (
  spot_id     uuid        not null references spots(id) on delete cascade,
  user_id     uuid        not null references profiles(id) on delete cascade,
  vote        vote_type   not null,
  created_at  timestamptz not null default now(),
  primary key (spot_id, user_id)
);

-- spot_comments ────────────────────────────────────────────────────────────────

create table spot_comments (
  id          uuid        primary key default gen_random_uuid(),
  spot_id     uuid        not null references spots(id) on delete cascade,
  author_id   uuid        not null references profiles(id),
  vote        vote_type,
  body        text        not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger trg_spot_comments_updated_at
  before update on spot_comments
  for each row execute function set_updated_at();

-- documents ────────────────────────────────────────────────────────────────────

create table documents (
  id            uuid        primary key default gen_random_uuid(),
  trip_id       uuid        not null references trips(id) on delete cascade,
  title         text        not null,
  type          doc_type    not null,
  ext           text        not null,
  file_size_kb  integer     check (file_size_kb > 0),
  storage_path  text,
  amount        numeric(12, 2),
  currency      text,
  notes         text,
  uploaded_by   uuid        not null references profiles(id),
  uploaded_at   timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint documents_currency_fmt
    check (currency is null or currency ~ '^[A-Z]{3}$')
);

create trigger trg_documents_updated_at
  before update on documents
  for each row execute function set_updated_at();

-- document_links ───────────────────────────────────────────────────────────────
-- Polymorphic. No label field — resolved at app layer.
-- linked_id carries no DB-enforced FK; orphan prevention is application-layer.

create table document_links (
  id            uuid            primary key default gen_random_uuid(),
  document_id   uuid            not null references documents(id) on delete cascade,
  linked_type   doc_linked_type not null,
  linked_id     uuid            not null,
  created_by    uuid            not null references profiles(id),
  created_at    timestamptz     not null default now(),
  unique (document_id, linked_type, linked_id)
);

-- itinerary_days ───────────────────────────────────────────────────────────────

create table itinerary_days (
  id          uuid        primary key default gen_random_uuid(),
  trip_id     uuid        not null references trips(id) on delete cascade,
  day_number  smallint    not null check (day_number >= 1),
  date        date        not null,
  city        text,
  notes       text,
  created_by  uuid        not null references profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (trip_id, day_number),
  unique (trip_id, date)
);

create trigger trg_itinerary_days_updated_at
  before update on itinerary_days
  for each row execute function set_updated_at();

-- itinerary_items ──────────────────────────────────────────────────────────────

create table itinerary_items (
  id                uuid                primary key default gen_random_uuid(),
  trip_id           uuid                not null references trips(id) on delete cascade,
  day_id            uuid                not null references itinerary_days(id) on delete cascade,
  title             text                not null,
  type              itinerary_item_type not null,
  time              time,
  city              text,
  location          text,
  maps_url          text,
  confirmation_url  text,
  notes             text,
  linked_spot_id    uuid                references spots(id) on delete set null,
  sort_order        smallint            not null default 0,
  created_by        uuid                not null references profiles(id),
  created_at        timestamptz         not null default now(),
  updated_at        timestamptz         not null default now()
);

create trigger trg_itinerary_items_updated_at
  before update on itinerary_items
  for each row execute function set_updated_at();

create or replace function check_itinerary_item_trip()
returns trigger
language plpgsql
as $$
begin
  if (select trip_id from itinerary_days where id = new.day_id) <> new.trip_id then
    raise exception
      'itinerary_items.trip_id (%) does not match itinerary_days.trip_id for day_id (%)',
      new.trip_id, new.day_id
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger trg_itinerary_item_trip_check
  before insert or update of trip_id, day_id on itinerary_items
  for each row execute function check_itinerary_item_trip();

-- receipts ─────────────────────────────────────────────────────────────────────

create table receipts (
  id          uuid             primary key default gen_random_uuid(),
  trip_id     uuid             not null references trips(id) on delete cascade,
  title       text             not null,
  amount      numeric(12, 2)   not null check (amount > 0),
  currency    text             not null,
  paid_by     uuid             not null references profiles(id),
  category    receipt_category not null,
  date        date             not null,
  notes       text,
  created_at  timestamptz      not null default now(),
  updated_at  timestamptz      not null default now(),
  constraint receipts_currency_fmt
    check (currency ~ '^[A-Z]{3}$')
);

create trigger trg_receipts_updated_at
  before update on receipts
  for each row execute function set_updated_at();

-- receipt_splits ───────────────────────────────────────────────────────────────

create table receipt_splits (
  receipt_id  uuid           not null references receipts(id) on delete cascade,
  user_id     uuid           not null references profiles(id) on delete cascade,
  amount      numeric(12, 2) not null check (amount > 0),
  is_settled  boolean        not null default false,
  settled_at  timestamptz,
  primary key (receipt_id, user_id),
  constraint receipt_splits_settled_at_check
    check (is_settled = false or settled_at is not null)
);

-- cash_withdrawals ─────────────────────────────────────────────────────────────

create table cash_withdrawals (
  id            uuid           primary key default gen_random_uuid(),
  trip_id       uuid           not null references trips(id) on delete cascade,
  withdrawn_by  uuid           not null references profiles(id),
  amount        numeric(12, 2) not null check (amount > 0),
  currency      text           not null,
  atm_fee       numeric(12, 2) not null default 0 check (atm_fee >= 0),
  date          date           not null,
  notes         text,
  created_at    timestamptz    not null default now(),
  updated_at    timestamptz    not null default now(),
  constraint cash_withdrawals_currency_fmt
    check (currency ~ '^[A-Z]{3}$')
);

create trigger trg_cash_withdrawals_updated_at
  before update on cash_withdrawals
  for each row execute function set_updated_at();

-- cash_distributions ───────────────────────────────────────────────────────────

create table cash_distributions (
  withdrawal_id  uuid           not null references cash_withdrawals(id) on delete cascade,
  user_id        uuid           not null references profiles(id) on delete cascade,
  amount         numeric(12, 2) not null check (amount >= 0),
  primary key (withdrawal_id, user_id)
);

-- travel_items ─────────────────────────────────────────────────────────────────

create table travel_items (
  id                        uuid             primary key default gen_random_uuid(),
  trip_id                   uuid             not null references trips(id) on delete cascade,
  title                     text             not null,
  type                      travel_item_type not null,
  date                      date,
  end_date                  date,
  time                      time,
  end_time                  time,
  location                  text,
  destination               text,
  confirmation_number       text,
  address                   text,
  notes                     text,
  linked_itinerary_item_id  uuid             references itinerary_items(id) on delete set null,
  linked_day_id             uuid             references itinerary_days(id) on delete set null,
  created_by                uuid             not null references profiles(id),
  created_at                timestamptz      not null default now(),
  updated_at                timestamptz      not null default now(),
  constraint travel_items_dates_check
    check (end_date is null or end_date >= date)
);

create trigger trg_travel_items_updated_at
  before update on travel_items
  for each row execute function set_updated_at();

-- ─── Indexes ──────────────────────────────────────────────────────────────────

create index idx_trip_members_user_id         on trip_members(user_id);
create index idx_spots_trip_id                on spots(trip_id);
create index idx_spots_status                 on spots(trip_id, status);
create index idx_spots_added_by               on spots(added_by);
create index idx_spot_votes_spot_id           on spot_votes(spot_id);
create index idx_spot_comments_spot_created   on spot_comments(spot_id, created_at);
create index idx_documents_trip_id            on documents(trip_id);
create index idx_documents_type               on documents(trip_id, type);
create index idx_document_links_document_id   on document_links(document_id);
create index idx_document_links_linked        on document_links(linked_type, linked_id);
create index idx_itinerary_days_trip_id       on itinerary_days(trip_id);
create index idx_itinerary_items_trip_id      on itinerary_items(trip_id);
create index idx_itinerary_items_day_id       on itinerary_items(day_id);
create index idx_itinerary_items_linked_spot  on itinerary_items(linked_spot_id)
  where linked_spot_id is not null;
create index idx_receipts_trip_id             on receipts(trip_id);
create index idx_receipts_date                on receipts(trip_id, date);
create index idx_receipt_splits_user_id       on receipt_splits(user_id);
create index idx_receipt_splits_unsettled     on receipt_splits(receipt_id)
  where is_settled = false;
create index idx_cash_withdrawals_trip_id     on cash_withdrawals(trip_id);
create index idx_cash_distributions_user_id   on cash_distributions(user_id);
create index idx_travel_items_trip_id         on travel_items(trip_id);
create index idx_travel_items_date            on travel_items(trip_id, date);
create index idx_travel_items_type            on travel_items(trip_id, type);

-- ─── RLS helper functions ─────────────────────────────────────────────────────

create or replace function is_trip_member(p_trip_id uuid)
returns boolean
language sql
security definer stable
set search_path = public
as $$
  select exists (
    select 1 from trip_members
    where trip_id = p_trip_id and user_id = auth.uid()
  );
$$;

create or replace function is_trip_owner(p_trip_id uuid)
returns boolean
language sql
security definer stable
set search_path = public
as $$
  select exists (
    select 1 from trip_members
    where trip_id = p_trip_id and user_id = auth.uid() and role = 'owner'
  );
$$;

create or replace function spot_trip_id(p_spot_id uuid)
returns uuid
language sql
security definer stable
set search_path = public
as $$
  select trip_id from spots where id = p_spot_id;
$$;

create or replace function document_trip_id(p_document_id uuid)
returns uuid
language sql
security definer stable
set search_path = public
as $$
  select trip_id from documents where id = p_document_id;
$$;

create or replace function receipt_trip_id(p_receipt_id uuid)
returns uuid
language sql
security definer stable
set search_path = public
as $$
  select trip_id from receipts where id = p_receipt_id;
$$;

create or replace function withdrawal_trip_id(p_withdrawal_id uuid)
returns uuid
language sql
security definer stable
set search_path = public
as $$
  select trip_id from cash_withdrawals where id = p_withdrawal_id;
$$;

-- ─── RPC: create_trip_with_owner ──────────────────────────────────────────────
-- Security definer bypasses RLS to atomically create trip + owner membership.
-- Direct INSERT on trips is intentionally blocked at the RLS layer.

create or replace function create_trip_with_owner(
  p_name              text,
  p_destination       text    default null,
  p_start_date        date    default null,
  p_end_date          date    default null,
  p_default_currency  text    default 'JPY',
  p_cover_image_url   text    default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip_id  uuid;
  v_user_id  uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Not authenticated' using errcode = 'P0001';
  end if;

  if p_name is null or trim(p_name) = '' then
    raise exception 'Trip name is required' using errcode = 'P0001';
  end if;

  if p_end_date is not null and p_start_date is not null
     and p_end_date < p_start_date then
    raise exception 'end_date must be >= start_date' using errcode = 'P0001';
  end if;

  if p_default_currency !~ '^[A-Z]{3}$' then
    raise exception 'default_currency must be a 3-letter ISO code' using errcode = 'P0001';
  end if;

  v_trip_id := gen_random_uuid();

  insert into trips (id, name, destination, start_date, end_date,
                     default_currency, cover_image_url, created_by)
  values (v_trip_id, trim(p_name), p_destination, p_start_date, p_end_date,
          p_default_currency, p_cover_image_url, v_user_id);

  insert into trip_members (trip_id, user_id, role)
  values (v_trip_id, v_user_id, 'owner');

  return v_trip_id;
end;
$$;

-- ─── Enable RLS ───────────────────────────────────────────────────────────────

alter table profiles            enable row level security;
alter table trips               enable row level security;
alter table trip_members        enable row level security;
alter table spots               enable row level security;
alter table spot_votes          enable row level security;
alter table spot_comments       enable row level security;
alter table documents           enable row level security;
alter table document_links      enable row level security;
alter table itinerary_days      enable row level security;
alter table itinerary_items     enable row level security;
alter table receipts            enable row level security;
alter table receipt_splits      enable row level security;
alter table cash_withdrawals    enable row level security;
alter table cash_distributions  enable row level security;
alter table travel_items        enable row level security;

-- ─── RLS policies ─────────────────────────────────────────────────────────────

-- profiles ─────────────────────────────────────────────────────────────────────

create policy "profiles: user can insert own profile"
  on profiles for insert
  with check (id = auth.uid());

create policy "profiles: authenticated users can read"
  on profiles for select
  using (auth.uid() is not null);

create policy "profiles: owner can update own profile"
  on profiles for update
  using     (id = auth.uid())
  with check (id = auth.uid());

-- trips ────────────────────────────────────────────────────────────────────────
-- No INSERT policy. All creation goes through create_trip_with_owner() RPC.

create policy "trips: members can read"
  on trips for select
  using (is_trip_member(id));

create policy "trips: owner can update"
  on trips for update
  using     (is_trip_owner(id))
  with check (is_trip_owner(id));

create policy "trips: owner can delete"
  on trips for delete
  using (is_trip_owner(id));

-- trip_members ─────────────────────────────────────────────────────────────────

create policy "trip_members: members can read"
  on trip_members for select
  using (is_trip_member(trip_id));

create policy "trip_members: owner can add members"
  on trip_members for insert
  with check (is_trip_owner(trip_id));

create policy "trip_members: owner can update member roles"
  on trip_members for update
  using     (is_trip_owner(trip_id) and user_id <> auth.uid())
  with check (is_trip_owner(trip_id));

create policy "trip_members: owner can remove other members"
  on trip_members for delete
  using (is_trip_owner(trip_id) and user_id <> auth.uid());

-- spots ────────────────────────────────────────────────────────────────────────

create policy "spots: members can read"
  on spots for select
  using (is_trip_member(trip_id));

create policy "spots: members can insert"
  on spots for insert
  with check (is_trip_member(trip_id) and added_by = auth.uid());

create policy "spots: adder or owner can update"
  on spots for update
  using     (is_trip_member(trip_id) and (added_by = auth.uid() or is_trip_owner(trip_id)))
  with check (is_trip_member(trip_id));

create policy "spots: adder or owner can delete"
  on spots for delete
  using (added_by = auth.uid() or is_trip_owner(spot_trip_id(id)));

-- spot_votes ───────────────────────────────────────────────────────────────────

create policy "spot_votes: members can read"
  on spot_votes for select
  using (is_trip_member(spot_trip_id(spot_id)));

create policy "spot_votes: members can insert own vote"
  on spot_votes for insert
  with check (is_trip_member(spot_trip_id(spot_id)) and user_id = auth.uid());

create policy "spot_votes: members can update own vote"
  on spot_votes for update
  using     (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "spot_votes: members can delete own vote"
  on spot_votes for delete
  using (user_id = auth.uid());

-- spot_comments ────────────────────────────────────────────────────────────────

create policy "spot_comments: members can read"
  on spot_comments for select
  using (is_trip_member(spot_trip_id(spot_id)));

create policy "spot_comments: members can insert"
  on spot_comments for insert
  with check (is_trip_member(spot_trip_id(spot_id)) and author_id = auth.uid());

create policy "spot_comments: author can update"
  on spot_comments for update
  using     (author_id = auth.uid())
  with check (author_id = auth.uid() and is_trip_member(spot_trip_id(spot_id)));

create policy "spot_comments: author or owner can delete"
  on spot_comments for delete
  using (author_id = auth.uid() or is_trip_owner(spot_trip_id(spot_id)));

-- documents ────────────────────────────────────────────────────────────────────

create policy "documents: members can read"
  on documents for select
  using (is_trip_member(trip_id));

create policy "documents: members can insert"
  on documents for insert
  with check (is_trip_member(trip_id) and uploaded_by = auth.uid());

create policy "documents: uploader or owner can update"
  on documents for update
  using     (uploaded_by = auth.uid() or is_trip_owner(trip_id))
  with check (is_trip_member(trip_id));

create policy "documents: uploader or owner can delete"
  on documents for delete
  using (uploaded_by = auth.uid() or is_trip_owner(trip_id));

-- document_links ───────────────────────────────────────────────────────────────

create policy "document_links: members can read"
  on document_links for select
  using (is_trip_member(document_trip_id(document_id)));

create policy "document_links: members can insert"
  on document_links for insert
  with check (
    is_trip_member(document_trip_id(document_id))
    and created_by = auth.uid()
  );

create policy "document_links: creator or owner can delete"
  on document_links for delete
  using (
    created_by = auth.uid()
    or is_trip_owner(document_trip_id(document_id))
  );

-- itinerary_days ───────────────────────────────────────────────────────────────

create policy "itinerary_days: members can read"
  on itinerary_days for select
  using (is_trip_member(trip_id));

create policy "itinerary_days: members can insert"
  on itinerary_days for insert
  with check (is_trip_member(trip_id) and created_by = auth.uid());

create policy "itinerary_days: members can update"
  on itinerary_days for update
  using     (is_trip_member(trip_id))
  with check (is_trip_member(trip_id));

create policy "itinerary_days: owner can delete"
  on itinerary_days for delete
  using (is_trip_owner(trip_id));

-- itinerary_items ──────────────────────────────────────────────────────────────

create policy "itinerary_items: members can read"
  on itinerary_items for select
  using (is_trip_member(trip_id));

create policy "itinerary_items: members can insert"
  on itinerary_items for insert
  with check (is_trip_member(trip_id) and created_by = auth.uid());

create policy "itinerary_items: members can update"
  on itinerary_items for update
  using     (is_trip_member(trip_id))
  with check (is_trip_member(trip_id));

create policy "itinerary_items: members can delete"
  on itinerary_items for delete
  using (is_trip_member(trip_id));

-- receipts ─────────────────────────────────────────────────────────────────────

create policy "receipts: members can read"
  on receipts for select
  using (is_trip_member(trip_id));

create policy "receipts: members can insert"
  on receipts for insert
  with check (is_trip_member(trip_id) and paid_by = auth.uid());

create policy "receipts: payer or owner can update"
  on receipts for update
  using     (paid_by = auth.uid() or is_trip_owner(trip_id))
  with check (is_trip_member(trip_id));

create policy "receipts: payer or owner can delete"
  on receipts for delete
  using (paid_by = auth.uid() or is_trip_owner(trip_id));

-- receipt_splits ───────────────────────────────────────────────────────────────

create policy "receipt_splits: members can read"
  on receipt_splits for select
  using (is_trip_member(receipt_trip_id(receipt_id)));

create policy "receipt_splits: members can insert"
  on receipt_splits for insert
  with check (is_trip_member(receipt_trip_id(receipt_id)));

create policy "receipt_splits: settle own or payer or owner can update"
  on receipt_splits for update
  using (
    user_id = auth.uid()
    or exists (
      select 1 from receipts r
      where r.id = receipt_id
        and (r.paid_by = auth.uid() or is_trip_owner(r.trip_id))
    )
  )
  with check (is_trip_member(receipt_trip_id(receipt_id)));

-- cash_withdrawals ─────────────────────────────────────────────────────────────

create policy "cash_withdrawals: members can read"
  on cash_withdrawals for select
  using (is_trip_member(trip_id));

create policy "cash_withdrawals: members can insert"
  on cash_withdrawals for insert
  with check (is_trip_member(trip_id) and withdrawn_by = auth.uid());

create policy "cash_withdrawals: withdrawer or owner can update"
  on cash_withdrawals for update
  using     (withdrawn_by = auth.uid() or is_trip_owner(trip_id))
  with check (is_trip_member(trip_id));

create policy "cash_withdrawals: withdrawer or owner can delete"
  on cash_withdrawals for delete
  using (withdrawn_by = auth.uid() or is_trip_owner(trip_id));

-- cash_distributions ───────────────────────────────────────────────────────────

create policy "cash_distributions: members can read"
  on cash_distributions for select
  using (is_trip_member(withdrawal_trip_id(withdrawal_id)));

create policy "cash_distributions: members can insert"
  on cash_distributions for insert
  with check (is_trip_member(withdrawal_trip_id(withdrawal_id)));

create policy "cash_distributions: members can update"
  on cash_distributions for update
  using     (is_trip_member(withdrawal_trip_id(withdrawal_id)))
  with check (is_trip_member(withdrawal_trip_id(withdrawal_id)));

-- travel_items ─────────────────────────────────────────────────────────────────

create policy "travel_items: members can read"
  on travel_items for select
  using (is_trip_member(trip_id));

create policy "travel_items: members can insert"
  on travel_items for insert
  with check (is_trip_member(trip_id) and created_by = auth.uid());

create policy "travel_items: members can update"
  on travel_items for update
  using     (is_trip_member(trip_id))
  with check (is_trip_member(trip_id));

create policy "travel_items: members can delete"
  on travel_items for delete
  using (is_trip_member(trip_id));

-- ─── Storage policies ─────────────────────────────────────────────────────────
-- Bucket: trip-documents (private, created manually in Supabase dashboard)
-- Path format: {trip_id}/{document_id}.{ext}
-- trip_id is always segment 1, extracted with split_part(name, '/', 1)::uuid

create policy "storage: trip members can read"
  on storage.objects for select
  using (
    bucket_id = 'trip-documents'
    and is_trip_member(split_part(name, '/', 1)::uuid)
  );

create policy "storage: trip members can upload"
  on storage.objects for insert
  with check (
    bucket_id = 'trip-documents'
    and is_trip_member(split_part(name, '/', 1)::uuid)
    and auth.uid() is not null
  );

create policy "storage: uploader or owner can delete"
  on storage.objects for delete
  using (
    bucket_id = 'trip-documents'
    and (
      owner = auth.uid()
      or is_trip_owner(split_part(name, '/', 1)::uuid)
    )
  );
