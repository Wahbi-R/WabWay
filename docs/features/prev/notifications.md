# Notifications Settings

## Overview

Routes all dead notification buttons (bell icon in Home AppBar, Notifications row in More screen) to a real settings screen with per-category toggles.

## Screen

**`NotificationSettingsScreen`** (`lib/screens/notification_settings_screen.dart`)

Four toggles:

| Toggle | Covers |
|---|---|
| Activity feed | New events in the trip activity feed |
| Money | New receipts, withdrawals, and settlements |
| Documents | New documents added to the trip |
| Itinerary | Plan changes and new travel bookings |

Settings are held in a static `_NotifPrefs` store (persists for the app session). A banner explains that push delivery is not yet active.

## Wired buttons

| Location | Element |
|---|---|
| `home_screen.dart:178,214` | Bell icon in AppBar (both error-state and normal AppBar) |
| `more_screen.dart:274` | Notifications row in Settings section |

## Next steps

When push notifications are implemented:
- Replace `_NotifPrefs` static store with `shared_preferences` or a Supabase `user_notification_prefs` row.
- Subscribe to FCM/APNs and gate delivery on the stored toggle values.
