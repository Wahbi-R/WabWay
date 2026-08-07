-- WabWay — Migration 025: add booking URL to travel_items
-- Allows attaching a link to the booking confirmation page for any travel item.

alter table travel_items add column if not exists url text;
