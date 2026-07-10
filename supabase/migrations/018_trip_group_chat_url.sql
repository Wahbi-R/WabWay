-- Optional group chat link stored on the trip.
-- Any member can open the link; only the organiser can set/clear it (enforced
-- in-app by only showing the edit field to owners in trip settings).
alter table trips
  add column if not exists group_chat_url text;
