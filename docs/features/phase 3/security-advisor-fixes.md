# Security advisor fixes (build 403)

Migration: `supabase/migrations/043_security_advisor_fixes.sql`

## What changed

| Advisor finding | Fix |
|---|---|
| `shopping_items` RLS disabled (ERROR) | RLS on; select/insert/update/delete `to authenticated using is_trip_member(trip_id)` |
| `_migration_backup_035_linked_spot` RLS disabled (ERROR) | Table dropped (leftover from 035) |
| `set_updated_at`, `check_itinerary_item_trip` mutable search_path | `set search_path = public` |
| 12 SECURITY DEFINER functions executable by `anon` | `revoke execute ... from public, anon`; `authenticated` + `service_role` keep it |

## Intentionally not fixed

- **Signed-in users can execute SECURITY DEFINER functions** — required. RLS policies call
  `is_trip_member` / `is_trip_owner` / `*_trip_id` as the querying user, and the app calls
  `create_trip_with_owner`, `transfer_trip_ownership`, `create_trip_invite`, `redeem_trip_invite`.
- **Leaked password protection** — dashboard toggle (Auth settings); Pro-plan feature.

## Gotchas

- Functions get `EXECUTE` granted to `PUBLIC` by default — revoking from `anon` alone does nothing.
  Any new SECURITY DEFINER function needs the same `revoke ... from public, anon`.
- Anon queries on tables whose policies call these helpers now **error** (permission denied) instead
  of returning `[]`. The keep-alive workflow therefore pings `profiles`, whose policy is just
  `auth.uid() is not null`.

## Verified (as each role, rolled back)

Member read/insert/update/delete shopping item ✅ · non-member read → 0 rows, insert blocked ·
anon shopping_items → 0 rows · anon profiles → `[]` · anon `is_trip_member` → blocked.

## Build 404 follow-up — `044_private_schema_helpers.sql`

- RLS helpers moved to schema `private` (not exposed via PostgREST → no `/rpc/` endpoint, advisor
  warning cleared). Existing policies keep working because they reference functions by OID.
- **When writing new policies/migrations, call `private.is_trip_member(...)`,
  `private.is_trip_owner(...)`, `private.spot_trip_id(...)` etc.** — unqualified names no longer resolve.
- `handle_new_user` / `record_activity`: authenticated EXECUTE revoked (triggers don't check it).
- Remaining advisor warnings (intentional): the 4 RPCs the app calls — `create_trip_with_owner`,
  `transfer_trip_ownership`, `create_trip_invite`, `redeem_trip_invite` — plus leaked-password protection.
