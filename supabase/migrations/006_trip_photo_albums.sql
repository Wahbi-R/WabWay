-- Trip photo albums: members share links to their Google Photos / iCloud / Dropbox albums
CREATE TABLE IF NOT EXISTS trip_photo_albums (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id     UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  added_by    UUID NOT NULL REFERENCES profiles(id),
  title       TEXT NOT NULL,
  url         TEXT NOT NULL,
  service     TEXT NOT NULL DEFAULT 'other',
  note        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE trip_photo_albums ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view albums"
  ON trip_photo_albums FOR SELECT
  USING (
    trip_id IN (
      SELECT trip_id FROM trip_members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Members can add albums"
  ON trip_photo_albums FOR INSERT
  WITH CHECK (
    trip_id IN (
      SELECT trip_id FROM trip_members WHERE user_id = auth.uid()
    )
    AND added_by = auth.uid()
  );

CREATE POLICY "Own rows can be deleted"
  ON trip_photo_albums FOR DELETE
  USING (added_by = auth.uid());
