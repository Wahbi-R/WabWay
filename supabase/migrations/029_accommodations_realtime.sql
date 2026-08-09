-- Enable Supabase Realtime for the accommodations table so the map
-- screen receives live updates when stays are added or edited.

do $$
begin
  begin
    alter publication supabase_realtime add table accommodations;
  exception when sqlstate '42710' then null; -- already a member
  end;
end;
$$;
