# Wabway – Feature TODO

Checked items are done. Log the date and a one-liner when completing something.

---

## Web + CI/CD (Do First)

- [x] **W1. Fix web build** — conditional export pattern for `share_handler` (native vs web stub) and `platform_file` helper replacing `dart:io` File usage; `flutter build web` compiles cleanly (2026-07-04, see `docs/features/web-build.md`).
- [x] **W2. GitHub Actions CI/CD** — on push to `main`: builds debug APK → creates/updates GitHub Release with APK attached; builds web → deploys to GitHub Pages; secrets-based `.env` creation (2026-07-04, see `docs/features/ci-cd.md`).
- [ ] **W3. Custom domain** — add `CNAME wabway Wahbi-R.github.io` in DNS; set `wabway.wabble.ca` as custom domain in repo Pages settings; GitHub provisions SSL automatically. See `docs/features/ci-cd.md` for full steps.
- [ ] **W4. In-app update checker** — on app start, call `https://api.github.com/repos/{owner}/{repo}/releases/latest`; compare `tag_name` against current build number via `package_info_plus`; if outdated show a persistent banner on the home screen with release notes and a "Download update" button that opens the APK asset `browser_download_url`; banner is Android-only (`kIsWeb` guard). Increment `versionCode` in `pubspec.yaml` with every push.

---

## High Priority

- [x] **1. In-app Import flow** — pick file/link → preview → choose type (Spot / Travel / Plan / Receipt / Document) → save via existing services (2026-07-03, see `docs/features/import-flow.md`)
- [x] **2. Place Search for Spots** — local Japan dataset, search fills name/address/coords/maps_url; "Map ready" indicator; "Open in Google Maps" action (2026-07-03, see `docs/features/place-search.md`)
- [x] **3. Google Maps link handling** — detect `google.com/maps` / `maps.app.goo.gl` / `goo.gl/maps`, extract `@lat,lng`, feed into Spot / Import / Share flows (2026-07-03, see `docs/features/maps-link-handling.md`)
- [x] **4. Map screen** — replace placeholder; show mapped spots with status colour; list/map toggle; tap opens spot detail (2026-07-04, see `docs/features/map-screen.md`)
- [x] **5. Android native share intake** — cold-start & while-open wired; Travel and Receipt destinations implemented; Maps URL title extraction improved; SEND_MULTIPLE intent added (2026-07-04, see `docs/features/share-intake.md`)
- [x] **6. Better document linking targets** — link docs to Receipt, Cash Withdrawal, Travel Item, Plan Item, Day, Spot, Trip from doc detail (2026-07-04, see `docs/features/doc-linking.md`)
- [x] **7. Attach ATM slips to cash withdrawals** — replaced placeholder with real photo-attach flow using `document_links` (2026-07-03)

---

## Medium Priority

- [x] **8. Links section** — replace placeholder screen; save title/URL/notes/category; category auto-detection; Realtime updates; open in browser (2026-07-04, see `docs/features/links.md`)
- [x] **9. Activity events** — real `activity_events` table/triggers; home screen reads from it with per-type icons and colours (2026-07-04, see `docs/features/activity-events.md`)
- [x] **10. Multi-trip switcher** — replace `trips.first`; trip switcher sheet; mobile access via More screen; desktop sidebar header tap (2026-07-04, see `docs/features/trip-switcher.md`)
- [x] **11. Improve invite system** — show all active/used/expired codes; revoke with confirm; single-use; expiry display; generate new code (2026-07-04, see `docs/features/invite-system.md`)
- [x] **12. Trip settings** — edit destination, dates, default currency via full settings sheet; owner-only; refreshes TripState (2026-07-04, see `docs/features/trip-settings.md`)
- [x] **13. Advanced Spots filtering** — filter icon wired; filter by status (multi-select) and city; badge shows active filter count (2026-07-04, see `docs/features/spots-filter.md`)
- [x] **14. Improve Plan editing** — edit day (city/date/notes); move item to another day; duplicate item; inline Move/Duplicate buttons in item detail (2026-07-04, see `docs/features/plan-editing.md`)
- [x] **15. Improve Travel editing** — booking status field (booked/tentative/cancelled) with badge on card and detail; doc-link sync on edit via syncDocLinks (2026-07-04, see `docs/features/travel-editing.md`)
- [x] **16. Receipt/document workflow improvements** — create receipt from doc detail; URL doc open in receipt linked-docs; split proportion bar + percentage labels (2026-07-04, see `docs/features/receipt-doc-workflow.md`)
- [x] **Make "Attach documents" collapsible in Add Plan Item sheet** — tap-to-expand with selected-count badge; auto-expands in edit mode (2026-07-04)

---

## Lower Priority / Later

- [x] **17. Settle Up flow** — `settlements` table; suggested settlements; mark as paid; persist; Realtime updates (2026-07-04, see `docs/features/settle-up.md`)
- [x] **18. Notifications** — settings UI with activity/money/docs/itinerary toggles; all dead bell/notification buttons routed to it; push delivery noted as future work (2026-07-04, see `docs/features/notifications.md`)
- [x] **19. Destination autocomplete** — local ~110-entry country/city dataset; `RawAutocomplete` in create and settings flows; no paid APIs (2026-07-04, see `docs/features/destination-autocomplete.md`)
- [x] **20. Owner transfer / leave-trip safety** — transfer ownership sheet (member picker); delete trip confirmation; leave trip hidden for owners (2026-07-04, see `docs/features/owner-transfer.md`)
- [x] **21. Branding polish** — adaptive launcher icons regenerated; splash screen uses brand cream (#F8F3EA) with centered icon (2026-07-04)
- [x] **22. Production cleanup** — `.env` gitignored confirmed; `.env.example` present; README updated with setup/build/migration instructions (2026-07-04)
- [x] **23. Offline / on-trip reliability** — stale data preserved on silent reload failure; `OfflineBanner` on Spots/Money/Travel screens when reload fails (2026-07-04)
- [x] **24. Global search** — search icon in Home AppBar; loads Spots/Docs/Travel/Receipts/Plan in parallel; grouped results by category (2026-07-04, see `lib/screens/global_search_screen.dart`)
- [x] **25. Empty / loading / error state polish** — links_screen no-flicker fix (silent reload); offline banners on Docs/Links screens; consistent retry actions (2026-07-04)
- [x] **26. Security / RLS review** — found and fixed 3 gaps: leaveTrip policy, ownership-transfer RPC (migration 003), settlements RLS; activity_events/trip_links RLS ensured (2026-07-04, see `supabase/migrations/003_rls_fixes_and_settlements.sql`)

---

## New / Upcoming

### High Priority

- [ ] **27. App name branding fix** — rename all occurrences of "Wabway" to "WabWay" (capital W mid-word): `android/app/src/main/AndroidManifest.xml` app label, `pubspec.yaml` name/description, any hardcoded strings in the UI, and the README title.
- [ ] **28. In-app update checker** — on app start, hit the GitHub Releases API (`https://api.github.com/repos/{owner}/{repo}/releases/latest`); compare `tag_name` against current build number via `package_info_plus`; if outdated show a persistent banner on the home screen with release notes and a "Download update" button opening the APK asset `browser_download_url`; Android-only (`kIsWeb` guard). Increment `versionCode` in `pubspec.yaml` with every push.
- [ ] **29. Profile editing** — let users edit display name and avatar initials; reflected across activity feed, money, comments, members, and invites.
- [ ] **30. Remove member** — owner can remove a trip member with a confirmation dialog; member is kicked from the trip immediately.
- [ ] **31. Document download + share** — "Download" button in doc detail currently calls _openFile (same as Open); wire it to actually save to device; add a Share button using the system share sheet.
- [ ] **32. Mixed-currency settle-up** — if a trip has receipts in multiple currencies, balances and settlement suggestions treat all amounts as the same unit; add per-currency grouping or a base-currency conversion.
- [ ] **33. Real place search (replace local dataset)** — swap the current ~110-entry hardcoded country/city list in `destination_autocomplete.dart` and spot place search with a live API so searching "Sensoji" suggests "Sensoji Temple, Asakusa, Tokyo" with address and coordinates auto-filled. Use Photon (`https://photon.komoot.io/api/?q={query}&limit=6`); free, no API key, excellent Japan coverage, purpose-built for autocomplete with clean structured fields. Results fill spot name, city, area, address, coordinates, and maps URL automatically. Debounce requests by 350ms so only 1 request fires per search instead of one per keystroke.
- [ ] **34. Edit spot** — spots currently have no edit flow; add an edit sheet (reuse the add spot form) accessible from the spot detail screen; any member can edit, owner can edit anything; updates reflected in Realtime across devices.
- [ ] **35. "Confirmed" spot status + green map pin** — add a `confirmed` value to the `spot_status` DB enum (`ALTER TYPE spot_status ADD VALUE IF NOT EXISTS 'confirmed';`) meaning "we are definitely going here, reservation or not"; show as solid green pin on map and green badge in spot list; sits between `must_do` and `planned` in the status progression. Note: `booked` already exists and is green — decide whether `confirmed` replaces it semantically for spots (no reservation needed, just group consensus) or sits alongside it.
- [ ] **36. Confirmed spots → Plan integration** — in the Plan screen, add a collapsible "Unplanned spots" section above the days list showing all spots with status `confirmed` or `planned` that are not yet linked to any itinerary day; tapping one opens a day-picker sheet to add it as a plan item on that day and optionally set a time; once added to a day it disappears from the unplanned section. This bridges the "we know we're going here" → "which day are we going" workflow.

### Medium Priority

- [ ] **37. Spot address field** — add a street address field to spots (stored in DB as `address text` column); show it in spot detail below city/area; pre-fill from place search result; display on the map detail sheet.
- [ ] **38. Map tiles in English** — current tile URL (`tile.openstreetmap.org`) shows place names in Japanese; swap to Carto Voyager tiles (`https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png`) which render romanized/English labels globally, are free, and require no API key. One-line change in `map_screen.dart`.
- [ ] **39. Map screen Realtime + fixes** — three gaps: (1) no Supabase Realtime subscription so pin colours don't update when someone changes a spot status from the Spots tab; (2) `myVote: null` is hardcoded when opening spot detail from a map pin — should load the user's actual vote; (3) map view has no pull-to-refresh, only the list view does.
- [ ] **40. Offline read cache** — cache last-loaded trip data locally (SharedPreferences or Hive) so the app shows real data on cold start without internet, not just an error screen.
- [ ] **41. Trip cover photo** — `cover_image_url` exists in the DB and `AppTrip` model but there is no UI to set one; add a photo picker in trip settings.
- [ ] **42. Trip export** — export itinerary, travel bookings, documents list, money summary, and spots as PDF or CSV for post-trip reference and reimbursement.
- [ ] **43. Calendar export** — export travel items and itinerary days to device calendar or an .ics file.
- [ ] **44. Push notifications** — currently the notification settings UI is wired but toggles do nothing persistent; implement real push delivery via Supabase Edge Functions + FCM.

### Lower Priority

- [ ] **45. Plan item drag-to-reorder** — items can be moved between days but not reordered within a day by drag; add `ReorderableListView` within each day.
- [ ] **46. First-run onboarding** — short walkthrough explaining create/join trip, import, spots, documents, money, and map for new users.
- [ ] **47. Diagnostics screen** — show app version, Supabase connection status, active trip ID, user ID, storage bucket status, and recent errors; useful for support and debugging.
- [ ] **48. QA checklist + test data reset guide** — document core smoke tests (invite flow, real-time updates, receipt splits, doc upload/view), two-device tests, Android share tests, web tests, and how to create/reset a safe test trip without affecting real trip data.

---

## Dead buttons / stubs to wire up

| Location | Button | What it needs |
|---|---|---|
| `home_screen.dart:164,194` | Bell / notifications icon | Route to notification settings screen (see #18) |
| `home_screen.dart:370` | "Settle up" | Real settlement flow (see #17) |
| `more_screen.dart:222` | Notifications settings row | Notification settings screen (see #18) |
| `spots_screen.dart:386` | Filter icon | Advanced filter sheet (see #13) |
| `incoming_share_screen.dart:94` | Travel / Links / Map share destinations | Wire to real flows (see #5) |
