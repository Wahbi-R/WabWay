-- Security advisor fixes (build 403)

-- 1. shopping_items had RLS disabled — anyone with the anon key could read/write
--    every trip's list. Lock it to trip members, matching the other trip tables.
alter table shopping_items enable row level security;

create policy "shopping_items: members can read"
  on shopping_items for select to authenticated
  using (is_trip_member(trip_id));

create policy "shopping_items: members can insert"
  on shopping_items for insert to authenticated
  with check (is_trip_member(trip_id));

create policy "shopping_items: members can update"
  on shopping_items for update to authenticated
  using (is_trip_member(trip_id))
  with check (is_trip_member(trip_id));

create policy "shopping_items: members can delete"
  on shopping_items for delete to authenticated
  using (is_trip_member(trip_id));

-- 2. Leftover backup table from migration 035, exposed via the API.
drop table if exists _migration_backup_035_linked_spot;

-- 3. Pin search_path on trigger functions.
alter function set_updated_at() set search_path = public;
alter function check_itinerary_item_trip() set search_path = public;

-- 4. SECURITY DEFINER functions were executable by signed-out (anon) callers.
--    Functions get EXECUTE granted to PUBLIC by default, so revoke from both.
--    authenticated keeps EXECUTE: RLS policies call the helpers and the app
--    calls the RPCs. Trigger functions don't need EXECUTE at fire time.
do $$
declare f regprocedure;
begin
  for f in
    select p.oid::regprocedure from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.prosecdef
      and p.proname in (
        'create_trip_invite', 'create_trip_with_owner', 'redeem_trip_invite',
        'transfer_trip_ownership', 'is_trip_member', 'is_trip_owner',
        'spot_trip_id', 'document_trip_id', 'receipt_trip_id',
        'withdrawal_trip_id', 'handle_new_user', 'record_activity')
  loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated, service_role', f);
  end loop;
end $$;
