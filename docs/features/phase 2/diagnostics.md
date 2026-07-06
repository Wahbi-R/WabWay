# Diagnostics Screen

## Description

A developer/support screen showing app version, Supabase connection status, and active user/trip info. Every row is copyable to clipboard. Accessible via More → Debug.

## Key Files

- `lib/screens/diagnostics_screen.dart` — full screen implementation
- `lib/screens/more_screen.dart` — "Debug" row (or similar) navigates here

## How It Works

`DiagnosticsScreen` accepts optional `AppProfile` and `AppTrip` constructor params passed from the More screen.

Displayed rows:
| Label | Source |
|---|---|
| App version | `PackageInfo.fromPlatform()` (native only; `—` on web) |
| Supabase URL | `String.fromEnvironment('SUPABASE_URL')` |
| Supabase connection | `supabase.from('trips').select('id').limit(1)` — shows "Connected ✓" or error text |
| User ID | `profile.id` |
| Display name | `profile.displayName` |
| Email | `profile.email` |
| Active trip ID | `trip.id` |
| Active trip name | `trip.name` |

Each row has a copy icon that calls `Clipboard.setData` and shows a brief snackbar confirmation. A "Re-check connection" button re-runs the Supabase ping.

## Setup

No setup required. The `package_info_plus` package is already in `pubspec.yaml`.
