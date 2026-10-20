-- Build 426: check-in / check-out times on stays.
--
-- The hotel's policy times ("check-in from 15:00, check-out by 11:00"), kept
-- apart from the check_in / check_out dates so nights and date sorting are
-- unchanged. Same `time` type as travel_items.time / end_time.

alter table public.accommodations
  add column if not exists check_in_time  time,
  add column if not exists check_out_time time;
