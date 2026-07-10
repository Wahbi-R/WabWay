-- Add 'visited' to the spot_status enum.
-- This maps to SpotStatus.visited in Flutter and appears after 'booked'
-- in the status progression (idea → confirmed → booked → visited).
alter type spot_status add value if not exists 'visited' after 'booked';
