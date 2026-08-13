-- Add link URL and image URL to shopping items

ALTER TABLE shopping_items
  ADD COLUMN IF NOT EXISTS link_url   TEXT,
  ADD COLUMN IF NOT EXISTS image_url  TEXT;
