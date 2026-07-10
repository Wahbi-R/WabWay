# Emergency Info Card

**Build 63**

## What it does

A dedicated screen under Settings → Emergency Info that stores key contacts and numbers for the trip. Fills in once before departure; readable offline while travelling.

Fields:
- **Local emergency number** — local equivalent of 911 (112 in Europe, 110 in Japan, etc.)
- **Travel insurance** — provider name, policy number (copyable), emergency phone
- **Credit card emergency phone** — the 24/7 number on the back of your card
- **Nearest hospital / clinic** — free text, copyable for pasting into Maps
- **Embassy contacts** — per-country contacts with phone and address
- **Notes** — anything else (doctor contacts, blood type, allergies)

Tapping a phone number opens the native dialer. Tapping a policy number or address copies it to clipboard.

## How it connects

- `lib/data/emergency_data.dart` — `TripEmergencyInfo` model and `EmbassyContact` model
- `lib/core/supabase/emergency_service.dart` — `fetch(tripId)` and `upsert(tripId, info)` via `trip_emergency_info` table; RLS allows all trip members to read/write
- `lib/screens/emergency_screen.dart` — main screen with `_InfoBody` (display) and `_EditSheet` (edit bottom sheet); copy-to-clipboard on policy number, address, and hospital; `launchUrl(tel:)` on phone fields
- `lib/screens/placeholder_screen.dart` (SettingsScreen) — new "Emergency info" tile under TRIP section pushes `EmergencyScreen`
- `supabase/migrations/011_trip_emergency_info.sql` — `trip_emergency_info` table; unique on `trip_id`; RLS for read/insert/update

## Files changed

- `supabase/migrations/011_trip_emergency_info.sql` (new)
- `lib/data/emergency_data.dart` (new)
- `lib/core/supabase/emergency_service.dart` (new)
- `lib/screens/emergency_screen.dart` (new)
- `lib/screens/placeholder_screen.dart` — import + tile
