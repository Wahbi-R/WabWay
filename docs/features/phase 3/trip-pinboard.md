# Trip Pinboard

**Build:** 72  
**Area:** Home, More → Settings

## What it does

A shared notice board where any trip member can post short notes visible to
everyone. Ideal for on-the-go info like Airbnb check-in codes, meeting times,
reminder messages, or anything the whole group should see instantly.

## User-facing changes

- **Pinboard card on Home screen** — appears automatically when there are pinned
  notes; hidden when empty so it doesn't clutter the home screen for new trips.
  Shows up to 3 pinned notes with a "See all" link.
- **Pinboard screen** (Settings → Pinboard) — full list of all notes (pinned +
  unpinned); post button in AppBar; swipe-down to refresh.
- **Post a note** — dialog with a textarea (up to 500 chars); posted notes appear
  on everyone's home screen immediately.
- **Unpin / delete** — three-dot menu on your own notes lets you unpin (keeps
  the note in history) or delete it entirely.

## Implementation

| Layer | Change |
|---|---|
| Supabase | Migration `016_trip_pins.sql` — `trip_pins` table with `id`, `trip_id`, `author_id`, `body`, `is_pinned`, `created_at`; full per-member RLS |
| `lib/data/pins_data.dart` | `TripPin` model with `fromMap` |
| `lib/core/supabase/pins_service.dart` | `fetchPinned`, `fetchAll`, `post`, `unpin`, `delete` |
| `lib/screens/pins_screen.dart` | Full-screen pins list with post dialog; `_PinCard` with author avatar, timestamp, unpin/delete menu |
| `lib/screens/home_screen.dart` | `_PinboardCard` self-loading stateful widget; hidden when no pinned notes |
| `lib/screens/placeholder_screen.dart` | "Pinboard" tile added to Settings → Trip section |

## Notes

- Home card auto-hides when `_pins` is empty — zero noise for trips that don't use it.
- No realtime subscription yet — reload on navigate back from PinsScreen covers the common case.
- "See all" taps open PinsScreen and reload the card on return.
