-- Migration 005: Add 'confirmed' value to spot_status enum
-- Run this in Supabase SQL editor before using the Confirmed status in the app.
-- ALTER TYPE … ADD VALUE cannot run inside a transaction, so Supabase runs it
-- outside the implicit transaction automatically.

ALTER TYPE spot_status ADD VALUE IF NOT EXISTS 'confirmed';
