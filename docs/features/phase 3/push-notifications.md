# Push Notifications (FCM)

**Build:** 103  
**Date:** 2026-08-06

## Overview

Full end-to-end push notification support for Android via Firebase Cloud Messaging (FCM). Crew members receive push alerts when anyone adds a spot, sends a crew message, logs a receipt, or creates a travel item — respecting per-category preferences set in Notification Settings.

## Package rename

The Android package ID was changed from the Flutter default (`com.example.wabway`) to the correct reverse-domain identifier (`ca.wabble.wabway`) matching the production domain `wabway.wabble.ca`. All affected files were updated:

- `android/app/build.gradle.kts` — `namespace` + `applicationId`
- `android/app/src/main/AndroidManifest.xml` — auth callback scheme
- `android/app/src/main/kotlin/` — directory restructured from `com/example/wabway/` to `ca/wabble/wabway/`; `package` declaration updated in `MainActivity.kt`
- `lib/core/share/share_handler_native.dart`, `lib/core/supabase/auth_service.dart`, `lib/screens/crew_screen.dart`, `lib/screens/map_screen.dart` — package references updated
- `web/.well-known/assetlinks.json` — package name + real SHA-256 fingerprint from `wabway-release.jks`

## Architecture

### Firebase / Gradle setup

Modern Flutter projects use `pluginManagement` in `settings.gradle.kts` — the legacy `buildscript { classpath() }` block conflicts with it. The Google Services plugin is declared in `settings.gradle.kts` plugins block with `apply false`, then applied in `android/app/build.gradle.kts`. `google-services.json` (project config, no private key) is committed to the repo.

### Device token storage

`device_tokens` table (migration `020_device_tokens.sql`):

```sql
create table if not exists device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null default 'android',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);
```

RLS: users can only read/write their own tokens. Tokens are upserted on login (and on FCM token refresh). Stale/unregistered tokens are deleted automatically by the Edge Function after a failed delivery attempt.

### Edge Function (`send-notification`)

Located at `supabase/functions/send-notification/index.ts`. Deployed with `--no-verify-jwt` (called server-side from the Flutter app, not from a browser session).

Flow:
1. Builds a JWT from the `FCM_SERVICE_ACCOUNT` Supabase secret (service account JSON)
2. Exchanges it for an OAuth2 access token at `oauth2.googleapis.com/token`
3. Queries `trip_members` for all members of the trip, excluding the sender
4. Fetches their FCM tokens from `device_tokens`
5. POSTs to FCM HTTP v1 API for each token
6. On `UNREGISTERED` / `INVALID_REGISTRATION` error, deletes the stale token

The FCM private key is stored only in Supabase Vault — never in the repo.

### NotificationService (`lib/core/notifications/notification_service.dart`)

Singleton initialized in `main.dart` (after `Firebase.initializeApp()`). Skips entirely on web (`kIsWeb` guard). Responsibilities:

- Requests Android notification permission
- Saves + refreshes the FCM device token to Supabase
- Handles taps on notifications (foreground, background, terminated) by calling a `TabSwitcher` callback registered by `AppShell`

### PushNotifier (`lib/core/notifications/push_notifier.dart`)

Top-level helper `pushNotify(...)` called after write operations. Features:
- `prefKey` param — checks SharedPreferences before sending; skips if the user disabled that category
- Fire-and-forget — errors are logged but never surfaced to the UI
- No-op on web

### Tab deep linking

`AppShell.setTabSwitcher` registers a `void Function(String screenKey)` callback with `NotificationService`. When a notification is tapped, `_handleTap` extracts the `screen` key from `message.data` and calls the callback. `AppShell` maps screen keys to tab indices for both mobile and desktop layouts.

## Notification events

| Trigger | Title | Screen key | Pref key |
|---|---|---|---|
| Crew message sent | "New crew message" | `crew` | `notif_crew` |
| Spot added (not edited) | "New spot added" | `spots` | `notif_activity` |
| Receipt added (not edited) | "New receipt added" | `money` | `notif_money` |
| Travel item created | "New travel item added" | `travel` | `notif_itinerary` |

## Notification Settings screen

Removed the "Push notifications coming soon" banner. Added real toggles backed by SharedPreferences for: Crew chat, Spots, Money, Travel, Documents. Constants exported from `notification_settings_screen.dart` so pref keys stay in one place.
