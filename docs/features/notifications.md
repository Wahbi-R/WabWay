# Notifications

## Description

A settings screen with toggles for four notification categories — Activity, Money, Documents, and Itinerary. Settings persist across app restarts via `SharedPreferences`. All bell/notification buttons throughout the app route here. Push delivery (FCM/Edge Functions) is future work.

## Key Files

- `lib/screens/notification_settings_screen.dart` — toggle UI, SharedPreferences load/save
- `lib/screens/home_screen.dart` — AppBar bell icon routes here
- `lib/screens/more_screen.dart` — "Notifications" settings row routes here

## How It Works

`SharedPreferences` keys:
- `notif_activity` (default: true)
- `notif_money` (default: true)
- `notif_documents` (default: true)
- `notif_itinerary` (default: true)

On `initState`, the screen loads all four booleans. Each `SwitchListTile` calls `_save()` on toggle, which writes all four values back. A loading spinner is shown before the first load completes.

## Limitations

Toggles only affect local preference storage. No push notification delivery is wired — FCM token registration and Supabase Edge Function dispatch are needed for actual push delivery.
