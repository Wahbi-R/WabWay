# WabWay — Supabase Setup

## 1. Create the Supabase project

1. Go to [supabase.com](https://supabase.com) → New Project.
2. Choose a region close to your users.
3. Set a strong database password and save it somewhere safe.
4. Wait for provisioning (~2 min).

## 2. Apply the migration

### Option A — Supabase CLI (recommended)

```bash
# Install the CLI if you haven't already
npm install -g supabase

# Log in and link to your project
supabase login
supabase link --project-ref <your-project-ref>

# Push the migration
supabase db push
```

`<your-project-ref>` is the string in your project URL:
`https://app.supabase.com/project/<your-project-ref>`

### Option B — SQL Editor in the dashboard

1. Open your project → **SQL Editor** → **New query**.
2. Paste the entire contents of `migrations/001_initial_schema.sql`.
3. Click **Run**.

## 3. Create the storage bucket

The migration includes storage *policies*, but the bucket itself must be
created manually:

1. Go to **Storage** → **New bucket**.
2. Name: `trip-documents`
3. Public: **No** (private bucket).
4. Recommended limits (set under bucket settings):
   - Max file size: `52428800` (50 MB)
   - Allowed MIME types: leave empty to allow all, or restrict to
     `application/pdf,image/*,application/vnd.openxmlformats-officedocument.*`

## 4. Enable the Auth trigger

The `handle_new_user()` trigger fires on `auth.users` insert to auto-create
a row in `public.profiles`. Supabase creates this trigger automatically when
the migration runs, but confirm it is listed under
**Database → Triggers → on_auth_user_created**.

## 5. Required environment variables

Add these to your Flutter app (e.g. via `--dart-define` or a `.env` loader):

| Variable | Where to find it |
|---|---|
| `SUPABASE_URL` | Project Settings → API → Project URL |
| `SUPABASE_ANON_KEY` | Project Settings → API → `anon` `public` key |

Never commit the `service_role` key to source control. It is not needed by
the Flutter client.

## 6. Verify RLS is enabled

After applying the migration, check **Database → Tables** in the dashboard.
Every table should show a **RLS enabled** badge. If any table shows
**RLS disabled**, run:

```sql
alter table <table_name> enable row level security;
```

## 7. File structure

```
supabase/
  migrations/
    001_initial_schema.sql   ← full schema, enums, RLS, RPCs, storage policies
  README.md                  ← this file
```

Future migrations go in `supabase/migrations/` with sequential prefixes:
`002_add_invites.sql`, `003_seed_japan_trip.sql`, etc.
