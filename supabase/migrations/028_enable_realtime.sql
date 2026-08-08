-- Enable Supabase Realtime for tables that use live subscriptions.
-- trip_messages may already be in the publication; ignore duplicates.

do $$
begin
  begin
    alter publication supabase_realtime add table trip_messages;
  exception when sqlstate '42710' then null; -- already a member
  end;
  begin
    alter publication supabase_realtime add table location_shares;
  exception when sqlstate '42710' then null;
  end;
  begin
    alter publication supabase_realtime add table trip_members;
  exception when sqlstate '42710' then null;
  end;
  begin
    alter publication supabase_realtime add table message_reactions;
  exception when sqlstate '42710' then null;
  end;
end;
$$;
