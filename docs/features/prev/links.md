# Links Section

## What it does

Replaces the placeholder Links screen with a full-featured link board where the group can save any URL — Instagram posts, TikTok videos, Tabelog reviews, booking pages, news articles, Maps links — tagged with a category and optional notes.

## Features

- **Save any URL** with a title, category, and optional notes
- **7 categories**: General, Food & drink, Stay, Activity, Shopping, Article, Social — each with a distinct colour and icon
- **Auto-detect category** from known domains on URL entry (Tabelog/Yelp/Gurunavi → Food, Booking.com/Agoda → Stay, Instagram/TikTok/YouTube → Social, Amazon/Rakuten → Shopping, Maps URL → Food)
- **Auto-fill title** from domain when title field is empty
- **Open in browser** — tapping any card opens the URL in the external browser
- **Delete with confirm dialog** — optimistic removal with server-side revert on failure
- **Realtime** — Supabase Postgres changes subscription; 400 ms debounce to avoid re-fetches on rapid bursts
- **Empty state** with descriptive copy and a CTA button
- **Pull-to-refresh**

## SQL migration (run in Supabase)

```sql
create table if not exists trip_links (
  id          uuid primary key default gen_random_uuid(),
  trip_id     uuid not null references trips(id) on delete cascade,
  added_by    uuid not null references profiles(id),
  title       text not null,
  url         text not null,
  category    text not null default 'general',
  notes       text,
  created_at  timestamptz not null default now()
);

create index if not exists trip_links_trip_id_idx on trip_links(trip_id);

alter table trip_links enable row level security;

create policy "Trip members can view links"
  on trip_links for select
  using (
    exists (
      select 1 from trip_members
      where trip_members.trip_id = trip_links.trip_id
        and trip_members.user_id = auth.uid()
    )
  );

create policy "Trip members can insert links"
  on trip_links for insert
  with check (
    exists (
      select 1 from trip_members
      where trip_members.trip_id = trip_links.trip_id
        and trip_members.user_id = auth.uid()
    )
  );

create policy "Link owner can delete"
  on trip_links for delete
  using (added_by = auth.uid());
```

## Files

| File | Change |
|---|---|
| `lib/data/links_data.dart` | `LinkCategory` enum (label, icon, color, softColor) + `TripLink` model with `domain` getter |
| `lib/core/supabase/links_service.dart` | `LinksService.loadLinks`, `createLink`, `deleteLink` |
| `lib/screens/links/add_link_sheet.dart` | Bottom sheet: URL + title + category chip grid + notes; auto-detects category; calls `LinksService.createLink` |
| `lib/screens/links_screen.dart` | Main screen: list with `_LinkCard`; Realtime subscription; add/delete; empty/error/loading states |
| `lib/shell/app_shell.dart` | Added `import links_screen.dart` |
| `lib/screens/placeholder_screen.dart` | Removed `LinksScreen` stub |
