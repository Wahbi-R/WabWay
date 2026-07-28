-- Add planned cost to itinerary items
ALTER TABLE itinerary_items
  ADD COLUMN IF NOT EXISTS planned_cost NUMERIC,
  ADD COLUMN IF NOT EXISTS currency     TEXT;
