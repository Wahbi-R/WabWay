-- Add country field to itinerary items
alter table itinerary_items add column if not exists country text;
