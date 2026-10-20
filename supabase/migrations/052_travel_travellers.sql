-- Build 427: who's on each booking, with their seat.
--
-- [{ "user_id": uuid|absent, "name": "RAIHAN/WAHBI MR"|absent, "seat": "Car 14 20-D"|absent }]
-- user_id is a trip member; name is as printed on the ticket. Seats listed
-- without names are stored with neither until someone assigns them. Kept on
-- the row (not a join table) so RLS, realtime and the offline cache need no
-- changes.

alter table public.travel_items
  add column if not exists travellers jsonb not null default '[]'::jsonb;
