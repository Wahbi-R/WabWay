# Photo Albums

## Overview
A shared coordination screen where trip members drop links to their photo albums (Google Photos, iCloud, Dropbox, etc.) so the whole group can find everyone's photos in one place. No images are stored in Supabase — the feature is purely a URL registry.

## Entry Point
More → Photos (mobile; also visible in the desktop sidebar under Explore)

## Why URL links instead of in-app uploads?
- Everyone already auto-backs up their camera roll to Google Photos or iCloud
- Uploading full camera rolls to Supabase Storage would be expensive
- Shared albums in Google Photos / iCloud already support collaborative upload — multiple people can add photos to the same album natively
- The app's role is coordination: one place to see all the albums

## Album Card
Each saved album shows:
- Service icon and color (Google Photos / iCloud / Dropbox / other), auto-detected from URL domain
- Title (user-provided; defaults to URL domain if left blank)
- Service label + URL domain
- Optional note
- Uploader's initials avatar + name
- Open-in-browser icon; delete icon (own entries only)

Tapping the card opens the URL via `launchUrl` in an external browser/app.

## Add Album Sheet (`lib/screens/photos/add_album_sheet.dart`)
- URL field (required) — `TextInputType.url`
- Service chip — auto-detected from domain (`photos.google.com` → Google Photos, `icloud.com` → iCloud, `dropbox.com` → Dropbox)
- Title field — auto-populated from URL domain when left blank
- Optional note field
- "Add album" button → `PhotoAlbumService.createAlbum()`

## Setup Guide
A collapsible `ExpansionTile` card at the top of the screen, expanded in empty state and collapsed once albums exist. Contains step-by-step instructions for:

**Google Photos (recommended):**
1. Library → New album → name it → Create
2. Share icon → Invite by link or contacts
3. Turn on "Collaborators can add photos & videos"
4. Paste the share link in the app

**Auto-backup tip:** Open the shared album → three-dot menu → "Automatically add photos" — Google Photos suggests camera roll shots to add.

**iCloud Shared Album:**
1. Photos → New Shared Album → invite members by iCloud/email
2. Members upload from their own library
3. Paste the album link in the app

## Data Model (`lib/data/photo_album_data.dart`)

### `AlbumService` enum
`googlePhotos | icloud | dropbox | other`
- `.label`, `.icon`, `.color`, `.softColor` — per-service branding
- `AlbumService.fromUrl(url)` — domain-based auto-detection
- `AlbumService.fromDb(s)` / `.dbValue` — DB serialization

### `TripPhotoAlbum`
`id, tripId, addedById, title, url, service, createdAt, note?`
- `get domain` — strips `www.` prefix from URL host

## Service (`lib/core/supabase/photo_album_service.dart`)
- `loadAlbums(tripId)` → `List<TripPhotoAlbum>` (ordered newest first)
- `createAlbum({tripId, addedBy, title, url, service, note?})` → `TripPhotoAlbum`
- `deleteAlbum(albumId)`

## Realtime
`PhotosScreen` subscribes to `trip_photo_albums` with a `PostgresChangeEvent.all` filter on `trip_id`. Changes are debounced 400ms then silently reloaded — same pattern as `LinksScreen`.

## Supabase Migration
`supabase/migrations/006_trip_photo_albums.sql`

```sql
CREATE TABLE trip_photo_albums (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id     UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  added_by    UUID NOT NULL REFERENCES profiles(id),
  title       TEXT NOT NULL,
  url         TEXT NOT NULL,
  service     TEXT NOT NULL DEFAULT 'other',
  note        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

RLS policies: SELECT for trip members, INSERT for trip members (own `added_by` only), DELETE for own rows.
