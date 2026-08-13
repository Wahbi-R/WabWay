# Offline Strategy

## Goal

Make the app useful when the user has no internet connection, without storing everything permanently. The target is: **anything you've recently seen should still be visible offline, and any changes you make offline should sync when you reconnect.**

---

## Phase 1 — Image caching (quick win)

**Package:** `cached_network_image`

When a network image is loaded via `CachedNetworkImage`, it is automatically saved to a temporary cache folder on the device. Next time the same image is requested, it loads from disk — no network needed. The OS can evict the cache under memory pressure, but in practice recently-seen images will work offline.

**What to do:**
- Add `cached_network_image` to `pubspec.yaml`
- Replace any `Image.network(...)` calls with `CachedNetworkImage(imageUrl: ...)`
- Replace `NetworkImage(...)` in `DecorationImage` / `CircleAvatar` with `CachedNetworkImageProvider(...)`

This is the highest-impact lowest-effort improvement. Users who viewed a spot's photos yesterday will still see them tomorrow with no connection.

---

## Phase 2 — Structured data caching

**Package:** `hive_flutter` (or `isar` for larger datasets)

Store the last-fetched version of key data types on-device so the app renders something useful immediately on launch, even before Supabase responds.

**Data to cache:**
- Trips list (`trips` table)
- Active trip's spots, itinerary days, accommodations, shopping items
- Members list

**Pattern:**
1. App launches → read from Hive immediately → show data
2. In background → fetch from Supabase → update Hive + refresh UI
3. If Supabase fetch fails → stay on Hive data, show a subtle "offline" indicator

This is the "stale-while-revalidate" pattern. The user always sees something fast, and it's always fresh when connected.

---

## Phase 3 — Offline writes / sync queue

Allow users to make changes (add a spot, check off a shopping item) while offline, with those changes automatically applied to Supabase when connectivity returns.

**Package:** `connectivity_plus` (to detect connection state)

**Pattern:**
1. User makes a change → write to Hive immediately (optimistic)
2. Try to write to Supabase → if it fails due to no connection, add to a `_pendingQueue` stored in Hive
3. `connectivity_plus` stream detects reconnection → drain the queue in order
4. If a queued write fails for a non-network reason (e.g. conflict) → surface an error to the user

**Conflict handling (keep it simple):**
- Last-write wins for most fields (name, notes, quantity)
- Checked state on shopping items: if both offline and server changed, prefer checked=true (non-destructive)
- Spots: no conflict risk since each user creates their own

---

## Notes

- Riverpod providers are the natural place for the cache layer: each provider decides "do I read from Hive or fetch from Supabase?" in one place, and all screens that depend on it stay in sync automatically.
- Phase 1 is completely independent and can be done any time.
- Phase 2 and 3 are best done after the Riverpod migration since providers make the caching logic clean and centralised.
- Images: even with Phase 2 in place, we rely on `cached_network_image` for photos — storing image bytes in Hive would be wasteful and slow.
