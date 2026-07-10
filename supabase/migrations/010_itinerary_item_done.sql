-- Add is_done flag to itinerary_items so trip members can check off
-- completed activities without deleting them.
alter table itinerary_items
  add column if not exists is_done boolean not null default false;
