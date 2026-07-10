# Group Chat Link (Build 77)

## Summary

Organisers can now store a group chat URL on the trip (WhatsApp, Telegram, Signal, or any link) so all members can reach the group's chat with one tap. The link is accessible from the Members screen AppBar whenever it's set.

## What changed

### Database
- **Migration 018** — `group_chat_url text` added to `trips` with `ADD COLUMN IF NOT EXISTS`.

### Data layer
- **`AppTrip`** — added `groupChatUrl` field and parsed from `fromMap`.
- **`TripService.updateTrip`** — added `groupChatUrl` / `clearGroupChatUrl` parameters.

### UI
- **Trip Settings sheet** — new "Group chat link" text field below the budget field; accepts any URL; persisted via `updateTrip`; cleared when the field is left blank.
- **Members screen** — chat bubble icon appears in the AppBar when a group chat URL is set; taps open the URL in an external app (via `url_launcher`).

## Files modified

- `supabase/migrations/018_trip_group_chat_url.sql` (new)
- `lib/core/trip/app_trip.dart`
- `lib/core/supabase/trip_service.dart`
- `lib/screens/trips/trip_settings_sheet.dart`
- `lib/screens/members_screen.dart`
