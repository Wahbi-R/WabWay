# Links

## Description

A dedicated Links section where members can save URLs (articles, booking sites, social posts, etc.) with a title, optional notes, and an auto-detected category. Displays in real-time via Supabase Realtime; links open in the system browser.

## Key Files

- `lib/screens/links_screen.dart` — full screen with add sheet and Realtime subscription
- `lib/core/supabase/links_service.dart` — `loadLinks()`, `createLink()`, `deleteLink()`
- `lib/data/links_data.dart` — `TripLink` model, `LinkCategory` enum

## How It Works

1. `LinksService.loadLinks(tripId)` fetches `trip_links` ordered newest-first.
2. A Supabase Realtime channel (`trip_links:trip_id=eq.<id>`) pushes inserts/deletes; the screen refreshes on change.
3. Category is auto-detected from the URL (keyword matching) and can be overridden in the add sheet.
4. Categories: `general`, `food`, `accommodation`, `activity`, `shopping`, `article`, `social`.
5. Tapping a link opens `url_launcher`'s `launchUrl`.

## Setup

`trip_links` table is created in migration `001_initial_schema.sql`. RLS restricts access to trip members. Activity trigger (`trg_link_added`) in migration `004` fires on insert.
