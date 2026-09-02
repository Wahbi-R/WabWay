# Offline-first SWR caching (build 284)

## What it does

Every main feature screen — spots, docs, money, plan, travel, accommodations, shopping, and packing — now loads data in two phases:

1. **Cache phase** (instant): cached data from the previous session is read from `SharedPreferences` and shown immediately, hiding the loading spinner.
2. **Network phase** (background): a fresh fetch runs silently; when it completes the list is updated in place. The spinner only appears on the very first load (empty cache) or on a manual retry.

## Why

The previous behaviour showed a loading spinner on every tab switch, every trip change, and every app cold-start. On slow or no network, users saw an error or stale data only after a full round-trip timeout. The new pattern gives instant perceived performance while still staying up to date.

## Generation counter (anti-flicker)

Each screen owns an `int _loadGen` counter. At the top of `_load`/`_loadAll`:

```dart
final gen = ++_loadGen;
```

Every `await` is followed by:

```dart
if (!mounted || gen != _loadGen) return;
```

This drops stale results when multiple async operations (cache read, network fetch, realtime event) race to update the same list. Only the most recent call wins.

## Service-layer changes

Each service gained two additions:

- `loadAll` / `fetchAll` now writes to `OfflineCache` after a successful network fetch.
- A new `loadFromCache` static method reads and deserialises from the cache.

Services with assembled models (plan, travel) use private `_toJson` / `_fromJson` helpers so the full object graph is round-tripped faithfully.

New cache keys added to `OfflineCache`:
- `accommodationsKey(tripId)`
- `shoppingKey(tripId)`
- `packingKey(tripId)`

(Spots, docs, money, plan, and travel keys already existed.)

## Realtime debounce (shopping fix)

The shopping screen previously triggered `_load(silent: true)` directly from the Supabase realtime callback, bypassing the 400 ms debounce used by every other screen. This is now fixed: the callback schedules through `Timer(400ms)` before calling `_load`.

## Testing

To verify SWR behaviour:

1. Open any feature screen while online — data loads from network and is written to cache.
2. Kill network access (Airplane mode or disable Wi-Fi).
3. Cold-restart the app.
4. Open any feature screen — cached data appears instantly with no spinner and no error.
5. Re-enable network — the next realtime event or tab focus triggers a silent background refresh.

To test generation counter (anti-flicker):

1. Open a screen with cached data.
2. While the background network fetch is running, trigger a realtime event (e.g. have a teammate add an item).
3. The list should update exactly once with the realtime result, not flicker between two versions.
