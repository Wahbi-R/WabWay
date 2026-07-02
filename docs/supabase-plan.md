# Wabway Supabase Backend Plan

_Generated: 2026-07-01. Based on mock data in `lib/data/` and screens in `lib/screens/`._

---

## 1. Tables

### `profiles`
Extends Supabase Auth users. One row per user.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | Matches `auth.users.id` |
| `display_name` | `text` NOT NULL | Shown in UI (Alex, Jordan, etc.) |
| `email` | `text` | Copied from auth for display |
| `avatar_url` | `text` | Storage path or external URL |
| `created_at` | `timestamptz` | Default `now()` |

---

### `trips`
Top-level entity. Every other table references a trip.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `name` | `text` NOT NULL | "Japan, November" |
| `start_date` | `date` | |
| `end_date` | `date` | |
| `created_by` | `uuid` FK → `profiles.id` | Trip creator / owner |
| `created_at` | `timestamptz` | |
| `updated_at` | `timestamptz` | |

---

### `trip_members`
Junction table linking users to trips with a role.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `trip_id` | `uuid` FK → `trips.id` ON DELETE CASCADE | |
| `user_id` | `uuid` FK → `profiles.id` ON DELETE CASCADE | |
| `role` | `text` | `'organiser'` or `'member'` |
| `joined_at` | `timestamptz` | When the user accepted the invite |

Unique constraint: `(trip_id, user_id)`.

---

### `trip_invites`
Pending invitations before a user joins.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `trip_id` | `uuid` FK → `trips.id` ON DELETE CASCADE | |
| `invited_by` | `uuid` FK → `profiles.id` | |
| `email` | `text` | Invitee's email address |
| `token` | `text` UNIQUE | Short random token for the invite link |
| `status` | `text` | `'pending'`, `'accepted'`, `'expired'` |
| `expires_at` | `timestamptz` | |
| `created_at` | `timestamptz` | |

---

### `spots`
Places the group has saved to the trip.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `trip_id` | `uuid` FK → `trips.id` ON DELETE CASCADE | |
| `name` | `text` NOT NULL | |
| `city` | `text` | |
| `area` | `text` | |
| `category` | `text` | `'food'`, `'landmark'`, `'nature'`, `'experience'`, `'shopping'`, `'nightlife'` |
| `status` | `text` | `'idea'`, `'want_to_go'`, `'must_do'`, `'planned'`, `'booked'`, `'skipped'` |
| `source_url` | `text` | |
| `maps_url` | `text` | |
| `notes` | `text` | |
| `added_by` | `uuid` FK → `profiles.id` | |
| `created_at` | `timestamptz` | |
| `updated_at` | `timestamptz` | |

---

### `spot_votes`
Each user's vote on a spot.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `spot_id` | `uuid` FK → `spots.id` ON DELETE CASCADE | |
| `user_id` | `uuid` FK → `profiles.id` ON DELETE CASCADE | |
| `vote` | `text` NOT NULL | `'must_do'`, `'want'`, `'maybe'`, `'skip'` |
| `created_at` | `timestamptz` | |

Unique constraint: `(spot_id, user_id)` — one vote per user per spot.

---

### `spot_comments`
User comments on spots, optionally paired with a vote.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `spot_id` | `uuid` FK → `spots.id` ON DELETE CASCADE | |
| `user_id` | `uuid` FK → `profiles.id` | |
| `vote` | `text` | Snapshot of the user's vote at time of comment (nullable) |
| `text` | `text` NOT NULL | |
| `created_at` | `timestamptz` | |

---

### `receipts`
Shared expenses paid by one member, split among many.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `trip_id` | `uuid` FK → `trips.id` ON DELETE CASCADE | |
| `title` | `text` NOT NULL | |
| `amount` | `numeric(12,2)` NOT NULL | Total amount |
| `currency` | `text` NOT NULL | ISO code: `'JPY'`, `'USD'`, `'EUR'` |
| `paid_by` | `uuid` FK → `profiles.id` | |
| `category` | `text` | `'food'`, `'transport'`, `'accommodation'`, `'activity'`, `'shopping'`, `'other'` |
| `date` | `date` | |
| `notes` | `text` | |
| `created_at` | `timestamptz` | |

---

### `receipt_splits`
Per-member portion of a receipt, with settlement tracking.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `receipt_id` | `uuid` FK → `receipts.id` ON DELETE CASCADE | |
| `user_id` | `uuid` FK → `profiles.id` ON DELETE CASCADE | |
| `amount` | `numeric(12,2)` NOT NULL | Share owed by this user |
| `is_settled` | `boolean` DEFAULT `false` | |

Unique constraint: `(receipt_id, user_id)`.

---

### `cash_withdrawals`
ATM withdrawals where one person takes out cash and distributes it.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `trip_id` | `uuid` FK → `trips.id` ON DELETE CASCADE | |
| `withdrawn_by` | `uuid` FK → `profiles.id` | |
| `amount` | `numeric(12,2)` NOT NULL | |
| `atm_fee` | `numeric(12,2)` DEFAULT `0` | |
| `currency` | `text` NOT NULL | |
| `date` | `date` | |
| `notes` | `text` | |
| `created_at` | `timestamptz` | |

---

### `cash_distributions`
Per-member allocation of a cash withdrawal.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `withdrawal_id` | `uuid` FK → `cash_withdrawals.id` ON DELETE CASCADE | |
| `user_id` | `uuid` FK → `profiles.id` ON DELETE CASCADE | |
| `amount` | `numeric(12,2)` NOT NULL | |

Unique constraint: `(withdrawal_id, user_id)`.

---

### `trip_days`
One row per day in the trip itinerary.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `trip_id` | `uuid` FK → `trips.id` ON DELETE CASCADE | |
| `day_number` | `int` NOT NULL | 1-indexed |
| `date` | `date` NOT NULL | |
| `city` | `text` | |
| `notes` | `text` | |

Unique constraint: `(trip_id, day_number)`.

---

### `itinerary_items`
Scheduled events within a trip day.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `day_id` | `uuid` FK → `trip_days.id` ON DELETE CASCADE | |
| `trip_id` | `uuid` FK → `trips.id` | Denormalized for RLS queries |
| `title` | `text` NOT NULL | |
| `type` | `text` | `'spot'`, `'travel'`, `'food'`, `'activity'`, `'free_time'`, `'transport'`, `'other'` |
| `time` | `time` | 24h, nullable for flexible items |
| `city` | `text` | |
| `location` | `text` | Human-readable address / venue name |
| `maps_url` | `text` | |
| `confirmation_url` | `text` | |
| `notes` | `text` | |
| `linked_spot_id` | `uuid` FK → `spots.id` SET NULL | |
| `sort_order` | `int` | Manual ordering within the day |
| `created_at` | `timestamptz` | |

---

### `documents`
Files uploaded to the trip (PDFs, images, etc.).

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `trip_id` | `uuid` FK → `trips.id` ON DELETE CASCADE | |
| `title` | `text` NOT NULL | |
| `type` | `text` | `'flight'`, `'hotel'`, `'train'`, `'ticket'`, `'reservation'`, `'receipt_doc'`, `'insurance'`, `'form'`, `'screenshot'`, `'other'` |
| `ext` | `text` | File extension: `'pdf'`, `'jpg'`, `'png'` |
| `storage_path` | `text` | Path in Supabase Storage |
| `file_size_kb` | `int` | |
| `amount` | `numeric(12,2)` | Optional financial amount on doc |
| `currency` | `text` | |
| `notes` | `text` | |
| `uploaded_by` | `uuid` FK → `profiles.id` | |
| `uploaded_at` | `timestamptz` | |

---

### `document_links`
Polymorphic links from a document to other entities.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `document_id` | `uuid` FK → `documents.id` ON DELETE CASCADE | |
| `linked_type` | `text` | `'spot'`, `'travel_item'`, `'receipt'`, `'cash_withdrawal'`, `'itinerary_item'`, `'itinerary_day'`, `'trip'` |
| `linked_id` | `uuid` NOT NULL | ID of the linked entity (no FK — polymorphic) |
| `label` | `text` | Display label for the link |

---

### `activity_events`
Append-only log powering the home screen activity feed.

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `trip_id` | `uuid` FK → `trips.id` ON DELETE CASCADE | |
| `actor_id` | `uuid` FK → `profiles.id` | |
| `event_type` | `text` | `'receipt_added'`, `'spot_saved'`, `'plan_updated'`, `'member_joined'`, `'doc_uploaded'`, etc. |
| `entity_type` | `text` | What was acted on |
| `entity_id` | `uuid` | ID of the acted-on entity |
| `meta` | `jsonb` | Snapshot label ("Ramen Ichiran · ¥4,800") |
| `created_at` | `timestamptz` | |

---

## 2. Relationships

```
trips
 ├── trip_members (many-to-many: trips ↔ profiles)
 ├── trip_invites (pending invites)
 ├── spots
 │    ├── spot_votes (one vote per user per spot)
 │    └── spot_comments
 ├── receipts
 │    └── receipt_splits (one per member)
 ├── cash_withdrawals
 │    └── cash_distributions (one per member)
 ├── trip_days
 │    └── itinerary_items → linked_spot_id → spots
 ├── documents → document_links → {spots, receipts, cash_withdrawals, itinerary_items, trip_days, trips}
 └── activity_events
```

Key cross-entity links:
- `itinerary_items.linked_spot_id` → `spots.id` (plan items can reference a spot)
- `document_links.linked_id` → any entity UUID (flexible cross-linking: a ticket doc links to both a receipt and a spot)
- `documents` ↔ `receipts`: linked via `document_links` with `linked_type = 'receipt'`
- `itinerary_items` ↔ `documents`: linked via the inverse — `document_links` with `linked_type = 'itinerary_item'`

---

## 3. Row Level Security

### Strategy overview
Every read/write query must pass through a trip-membership check. The core pattern: a user can access any row where `trip_id` appears in their `trip_members` set.

### Helper function (used in all policies)
```sql
create or replace function is_trip_member(p_trip_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from trip_members
    where trip_id = p_trip_id
    and user_id = auth.uid()
  );
$$;
```

### Per-table policies

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| `profiles` | Any authenticated user (for display names) | Via auth trigger only | Own row only | — |
| `trips` | `is_trip_member(id)` | Any authenticated user | Organiser only | Organiser only |
| `trip_members` | `is_trip_member(trip_id)` | Organiser only (or self-join via invite token) | Organiser only | Organiser only |
| `trip_invites` | Organiser of trip | Organiser of trip | — | Organiser of trip |
| `spots` | `is_trip_member(trip_id)` | `is_trip_member(trip_id)` | Any member | Author or organiser |
| `spot_votes` | `is_trip_member` via spots join | `is_trip_member` + own `user_id` | Own row only | Own row only |
| `spot_comments` | `is_trip_member` via spots join | `is_trip_member` + own `user_id` | Own row only | Own row only |
| `receipts` | `is_trip_member(trip_id)` | `is_trip_member(trip_id)` | `paid_by = auth.uid()` or organiser | `paid_by = auth.uid()` or organiser |
| `receipt_splits` | Via receipt → trip membership | Via receipt → trip membership | Own `is_settled` flag only | — |
| `cash_withdrawals` | `is_trip_member(trip_id)` | `is_trip_member(trip_id)` | `withdrawn_by = auth.uid()` | `withdrawn_by = auth.uid()` |
| `cash_distributions` | Via withdrawal → trip membership | Via withdrawal → trip membership | Own row only | — |
| `trip_days` | `is_trip_member(trip_id)` | Organiser only | Any member | Organiser only |
| `itinerary_items` | `is_trip_member(trip_id)` | Any member | Any member | Author or organiser |
| `documents` | `is_trip_member(trip_id)` | `is_trip_member(trip_id)` | `uploaded_by = auth.uid()` | `uploaded_by = auth.uid()` or organiser |
| `document_links` | Via document → trip membership | Via document → trip membership | — | `uploaded_by` of parent doc |
| `activity_events` | `is_trip_member(trip_id)` | Via server-side triggers only | — | — |

### Notes
- `activity_events` should be INSERT-only from a `security definer` function or database trigger, never directly from the client.
- Settlement marking (`is_settled`) on `receipt_splits` is the one case where a non-author can write: the debtor marks their own split settled.

---

## 4. Storage Buckets

### `trip-documents`
**Purpose:** PDFs and confirmation files (flights, hotel bookings, tickets, insurance, forms).

- Access: Private — authenticated trip members only
- Path convention: `{trip_id}/{document_id}.{ext}`
- Max file size: 20 MB
- Allowed MIME types: `application/pdf`, `image/*`
- RLS: Download allowed if `is_trip_member(trip_id)` (extracted from path prefix)
- Upload: Any trip member

### `receipt-photos`
**Purpose:** Photos of paper receipts (JPG/PNG captures).

- Access: Private — trip members only
- Path convention: `{trip_id}/receipts/{receipt_id}.{ext}`
- Max file size: 8 MB
- Allowed MIME types: `image/*`
- RLS: Same trip-membership check on path prefix

### `spot-photos`
**Purpose:** User-uploaded photos associated with spots (optional future feature, no mock UI yet but likely needed early).

- Access: Private — trip members only
- Path convention: `{trip_id}/spots/{spot_id}/{uuid}.{ext}`
- Max file size: 10 MB
- Allowed MIME types: `image/*`

### `avatars`
**Purpose:** User profile photos.

- Access: Public read (needed for display across trip members), write restricted to own folder
- Path convention: `{user_id}/avatar.{ext}`
- Max file size: 2 MB
- Allowed MIME types: `image/*`

---

## 5. Auth Flow

### Recommended Supabase Auth setup

**Primary methods:**
1. **Magic link (email OTP)** — lowest friction for a private social app; no passwords to forget
2. **Google OAuth** — high adoption in the target demographic, fast sign-in
3. **Email + password** — fallback for users who prefer it

**Session handling in Flutter:**
- Use `supabase_flutter` package (`Supabase.initialize()` in `main.dart`)
- Store session via the built-in `GoTrueClient` (persisted to `SharedPreferences` automatically)
- Use a `StreamBuilder` on `Supabase.instance.client.auth.onAuthStateChange` to drive a top-level router (unauthenticated → login screen, authenticated → home)
- On cold start, the client auto-restores the session; show a splash/loading screen while awaiting `authStateChange` to emit the first event

**Profile creation:**
- Add a Postgres trigger `on insert on auth.users` → inserts into `profiles` with `display_name` defaulting to the email username portion
- User can update `display_name` and `avatar_url` from a Settings screen

---

## 6. Trip Invite Flow

### How it works

1. **Organiser generates an invite link** from the Members screen ("Invite friends" button)
   - Client calls a Supabase Edge Function `create-invite`
   - Function inserts a row into `trip_invites` with a random `token` (e.g. `nanoid(12)`), `status = 'pending'`, `expires_at = now() + 7 days`
   - Function returns the invite URL: `https://wabway.app/join/{token}`

2. **Invitee opens the link**
   - Deep link or web handler reads the token
   - If the user is not signed in → redirect to login/signup first, preserving the token in state
   - If signed in → call Edge Function `accept-invite`

3. **`accept-invite` Edge Function:**
   - Look up `trip_invites` where `token = $token` and `status = 'pending'` and `expires_at > now()`
   - Insert into `trip_members(trip_id, user_id, role='member', joined_at=now())`
   - Update `trip_invites.status = 'accepted'`
   - Update the invitee's email on the invite row if not already set
   - Return the `trip_id` → client navigates into the trip

4. **Invite expiry:**
   - A scheduled Supabase pg_cron job (or Edge Function cron) sets `status = 'expired'` where `expires_at < now()` nightly

### Permissions for shared trips
- All `is_trip_member()` RLS policies apply immediately after `trip_members` insert
- Role `'organiser'` has extra permissions (delete spots, manage members, edit trip dates)
- Role `'member'` can add spots, receipts, documents, itinerary items, and vote

### Email notifications (optional Phase 2)
- Supabase Edge Function sends email via Resend or Postmark when an invite is created
- Also notify all members via Supabase Realtime (or push) when a new member joins

---

## 7. Integration Order

Recommended order to connect features to Supabase (each builds on the last):

### 1. Auth + Profiles (foundation)
All other features require a user identity. Implement sign-in (magic link + Google), auto-create profile on signup, and the session router. **No feature is buildable without this.**

### 2. Trips + Trip Members
Implement trip creation, fetching the active trip, and the member list. This unlocks the home screen hero card with real data and the Members screen. Establish the `is_trip_member()` RLS helper here.

### 3. Spots + Voting
Spots are the most socially engaging feature and the first thing users interact with together. Connecting spots and votes here will demonstrate real-time collaboration early (Supabase Realtime subscription on `spots` and `spot_votes`).

### 4. Money (Receipts + Cash Withdrawals)
High-value, trust-sensitive feature. Once Auth and trips are solid, connect receipts and splits. The balance calculation (`calculateBalances`) can move server-side as a Postgres view or function to avoid floating-point drift.

### 5. Documents + Storage
Upload files to `trip-documents` bucket; create `document_links` after upload. Implement download/view.

### 6. Plan (Itinerary)
`trip_days` and `itinerary_items` are read-heavy and write-light. Connect last because they depend on spots and documents being in Supabase first (for linking).

### 7. Activity Feed
Once other tables are in Supabase, add database triggers that insert into `activity_events`. The home screen feed then subscribes via Realtime.

### 8. Trip Invite Flow
Polish the invite deep-link handling after Auth is stable in production.

---

## 8. Risks & Model Mismatches

### 1. Polymorphic `document_links`
The mock uses `DocLinkedType` (spot, receipt, cash_withdrawal, itinerary_item, itinerary_day, trip). Storing these as a `linked_id uuid` column with no FK constraint is necessary because Postgres can't have a FK pointing at multiple tables. This means referential integrity is application-enforced only. **Risk:** orphaned links if a spot or receipt is deleted. **Mitigation:** add cascade delete logic in the `documents` deletion path, or replace with separate nullable FK columns (`linked_spot_id`, `linked_receipt_id`, etc.) at the cost of wider rows.

### 2. Member identity as display string vs. UUID
Mock data uses plain strings for authorship (`addedBy: 'Alex'`, `author: 'Jordan'`). In Supabase every reference must be a UUID pointing to `profiles.id`. All UI components that render a member name must join to `profiles`. **Risk:** the Flutter UI will need significant refactoring in display widgets (spot comments, vote lists, receipt splits) — none of them currently resolve UUIDs.

### 3. Vote aggregation (SpotVotes class)
The `SpotVotes` class holds four lists of voter names computed in-memory. In Supabase, votes live in `spot_votes` as individual rows. The UI must query counts via a Postgres view or a Supabase RPC (`get_spot_votes(spot_id)`) rather than relying on the embedded struct. **Risk:** N+1 query pattern if the app queries votes per-spot in a list view. **Mitigation:** use a view that aggregates votes in SQL and return it alongside spots.

### 4. Balance calculation done client-side
`calculateBalances()` and `suggestSettlements()` in `money_data.dart` iterate all receipts and withdrawals in memory. This works for small groups but will drift on floating-point rounding across platforms. **Risk:** two members calculating independently may get different balances. **Mitigation:** move this to a Postgres function using `numeric` arithmetic, expose as an RPC, and return canonical balances from the server.

### 5. `isSettled` flag on `receipt_splits` vs. full settlement records
The mock has a boolean `isSettled` per split. A production app typically needs settlement records (who paid whom, when, how much) to support reversals and audit. Consider a `settlements` table instead of / alongside the flag.

### 6. `kYouId = 'you'` identity token
The mock hardcodes `'you'` as the current user's ID. Every place this appears in logic must be replaced with `supabase.auth.currentUser!.id` in production — it's a systemic find-and-replace across all data files.

### 7. No multi-trip support in mock
The mock assumes exactly one trip. Supabase needs a trip selector / default-trip concept. The app's nav should accept a `trip_id` parameter or store the active trip ID in app state.

### 8. DateTime vs. date
`Receipt.date` is `DateTime` (with time component) but only the date is displayed and relevant. Store as `date` in Postgres; reconstruct as `DateTime` at midnight local time in the Flutter layer. The time component should not be used for ordering.
