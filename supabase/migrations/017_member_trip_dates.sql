-- Per-member arrival and departure dates within a trip.
-- Lets members indicate when they actually join/leave the group.
-- Useful when not everyone travels together the whole time.
alter table trip_members
  add column if not exists arrival_date   date,
  add column if not exists departure_date date;
