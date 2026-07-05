# Offline Read Cache

## Description

Spots, Documents, and Plan data are cached to `SharedPreferences` on every successful network load. On a subsequent cold-start failure (no connectivity or Supabase unreachable), screens fall back to the cache and show an `OfflineBanner`.

## Key Files

- `lib/core/offline_cache.dart` — `OfflineCache` service (write, read, clear)
- `lib/core/supabase/spot_service.dart` — writes on `loadSpots()`, exposes `loadSpotsFromCache()`
- `lib/core/supabase/doc_service.dart` — writes on `loadDocuments()`, exposes `loadDocumentsFromCache()`
- `lib/screens/spots_screen.dart`, `lib/screens/docs_screen.dart` — offline fallback logic + `OfflineBanner`

## How It Works

`OfflineCache` wraps `SharedPreferences` with `jsonEncode`/`jsonDecode`. Keys:
- `cache_spots_<tripId>`
- `cache_docs_<tripId>`
- `cache_plan_<tripId>`

On each successful `loadSpots()` or `loadDocuments()` call, the raw Supabase row list is written to cache via `OfflineCache.write()`. On failure, the screen calls `loadSpotsFromCache()` / `loadDocumentsFromCache()` and, if data is found, renders it with an `OfflineBanner` at the top indicating stale data.

## Setup

Requires `shared_preferences: ^2.3.0` in `pubspec.yaml`. Run `flutter pub get` after adding.
