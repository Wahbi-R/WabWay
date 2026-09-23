-- Allow multiple itinerary days on the same date (e.g. split day for two cities).
ALTER TABLE itinerary_days DROP CONSTRAINT IF EXISTS itinerary_days_trip_id_date_key;
