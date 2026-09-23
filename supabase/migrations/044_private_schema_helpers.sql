-- Clear remaining "Signed-In Users Can Execute SECURITY DEFINER Function"
-- advisor warnings that aren't needed by the app (build 404).

-- 1. RLS helper functions → private schema (not exposed via PostgREST, so no
--    /rest/v1/rpc/* endpoint). Existing policies reference functions by OID,
--    so they keep working unchanged. NEW policies must call them as
--    private.is_trip_member(...) etc.
create schema if not exists private;
grant usage on schema private to authenticated, service_role;

alter function public.is_trip_member(uuid)     set schema private;
alter function public.is_trip_owner(uuid)      set schema private;
alter function public.spot_trip_id(uuid)       set schema private;
alter function public.document_trip_id(uuid)   set schema private;
alter function public.receipt_trip_id(uuid)    set schema private;
alter function public.withdrawal_trip_id(uuid) set schema private;

-- 2. Trigger functions: EXECUTE isn't checked when a trigger fires, and they
--    can't be called directly anyway (return type trigger).
revoke execute on function public.handle_new_user() from authenticated;
revoke execute on function public.record_activity() from authenticated;
