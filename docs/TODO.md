# Wabway – Feature TODO

Checked items are done. Log the date and a one-liner when completing something.

---

## Web + CI/CD (Do First)

- [x] **W1. Fix web build** — conditional export pattern for `share_handler` (native vs web stub) and `platform_file` helper replacing `dart:io` File usage; `flutter build web` compiles cleanly (2026-07-04, see `docs/features/web-build.md`).
- [x] **W2. GitHub Actions CI/CD** — on push to `main`: builds debug APK → creates/updates GitHub Release with APK attached; builds web → deploys to GitHub Pages; secrets-based `.env` creation (2026-07-04, see `docs/features/ci-cd.md`).
- [x] **W3. Custom domain** — CNAME configured in Porkbun DNS; custom domain set in GitHub Pages; SSL certificate approved and enforced by GitHub (2026-07-04, live at https://wabway.wabble.ca).
- [x] **W4. In-app update checker** — implemented as item #28; `UpdateChecker.check()` hits GitHub Releases API; `_UpdateBanner` shown in Home screen (Android only) (2026-07-04).

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

- [x] **27. App name branding fix** — renamed user-facing "Wabway" → "WabWay" in AndroidManifest label, main.dart title, sign-in screen, sidebar fallback, and member sheet error strings (2026-07-04).
- [x] **28. In-app update checker** — `UpdateChecker.check()` hits GitHub Releases API on app start (Android only, `!kIsWeb`); compares build number from `package_info_plus`; shows dismissible `_UpdateBanner` in Home screen with release notes and download link (opens APK via `url_launcher`); added `http: ^1.2.0` and `package_info_plus: ^8.0.0` to pubspec (2026-07-04).
- [x] **29. Profile editing** — edit name sheet already existed; fixed `ProfileState.updateShouldNotify` to also compare `displayName`/`avatarUrl` so name changes propagate to all screens immediately (2026-07-04).
- [x] **30. Remove member** — owner sees a remove icon on each non-owner member row; confirmation dialog; calls `TripService.removeMember`; refreshes TripState (2026-07-04).
- [x] **31. Document download + share** — Share button added to doc detail actions using `share_plus`; gets signed URL for file docs or uses `notes` URL for link docs; web guard shows snack instead (2026-07-04).
- [x] **32. Android App Links for magic link auth** — HTTPS intent filter added to `AndroidManifest.xml` for `wabway.wabble.ca` with `android:autoVerify="true"`; template `web/.well-known/assetlinks.json` created (deploy with GitHub Pages); **action needed**: replace `REPLACE_WITH_YOUR_SHA256_CERT_FINGERPRINT` in `assetlinks.json` with real fingerprint from `keytool -list -v -keystore release.jks` (2026-07-04).
- [x] **33. Mixed-currency settle-up** — added `calculateBalancesGrouped()` that groups balances per currency; `SettleUpPanel` refactored to accept `balancesByCurrency`/`suggestionsByCurrency` maps; renders separate balance cards per currency with currency badge when multi-currency; suggested payments list shows per-currency amounts (2026-07-04).
- [x] **34. Real place search (Photon API)** — replaced local dataset with live `photon.komoot.io` API; `searchPhoton()` returns structured name/city/area/address/coords; 350ms debounce + local fallback for immediate results while request is in flight; category inferred from OSM type; added `http: ^1.2.0` to pubspec (run `flutter pub get`) (2026-07-04).
- [x] **35. Edit spot** — edit sheet reuses add spot form pre-filled with existing values; edit pencil icon in detail title row and AppBar; `SpotService.updateSpot`; in-place update in spots_screen and map_screen lists (2026-07-04).
- [x] **36. "Confirmed" spot status + green map pin** — added `confirmed` to `SpotStatus` enum (between mustDo and planned); green badge + green map pin; migration `005_confirmed_spot_status.sql` runs `ALTER TYPE spot_status ADD VALUE IF NOT EXISTS 'confirmed'` (run in Supabase SQL editor); both `booked` and `confirmed` show as green (2026-07-04).
- [x] **37. Confirmed spots → Plan integration** — collapsible "Unplanned Spots" section above the days list in Plan screen; shows confirmed/planned spots not yet linked to any day; tapping opens `_DayPickerSheet` with day list + optional time picker; on confirm creates `ItineraryItem` with `linkedSpotId`; disappears from section once added (2026-07-04).

### Medium Priority

- [x] **37. Spot address field** — address text field added to add/edit spot form (pre-filled from Photon search); already shown in spot detail; edit form pre-fills from existing spot; `_addressCtrl` synced in both create and update paths (2026-07-04).
- [x] **38. Map tiles in English** — swapped to Carto Voyager tiles with `subdomains: ['a','b','c','d']`; English/romanized labels worldwide (2026-07-04).
- [x] **39. Map screen Realtime + fixes** — added Realtime subscription for `spots`/`spot_votes`; fixed `myVote: null` by computing from `spot.votes.*`; added refresh IconButton in AppBar (2026-07-04).
- [x] **40. Offline read cache** — `OfflineCache` service using `shared_preferences`; `SpotService`/`DocService` write raw rows on every successful load and expose `loadFromCache()`; Spots and Docs screens fall back to cache on cold-start failure and show offline banner (2026-07-04). Run `flutter pub get` for `shared_preferences: ^2.3.0`.
- [x] **41. Trip cover photo** — `_CoverPhotoField` in trip settings sheet; picks from gallery via `image_picker`; uploads to `trip-covers` Supabase storage bucket; shows preview with remove button; wired into `TripService.updateTrip()` (2026-07-04). Create `trip-covers` bucket in Supabase Storage (public) before using.
- [x] **42. Trip export** — "Export" button in Plan screen (mobile AppBar + desktop top bar); generates a plain-text itinerary with day/city/date headers, timed + untimed items, and notes; shares via `share_plus` system sheet; web shows a snack explaining it's not supported (2026-07-04).
- [x] **43. Calendar export** — `_exportToCalendar()` in plan_screen.dart generates a VCALENDAR/.ics with one VEVENT per itinerary item (date-only or datetime, with location/notes); written to `Directory.systemTemp` and shared via `share_plus` as `text/calendar`; calendar icon in mobile AppBar and desktop top bar; web guard shows a snack (2026-07-04).
- [x] **44. Push notifications (persistence)** — notification settings now persist across app restarts via `SharedPreferences` (`notif_activity/money/documents/itinerary` keys); loads on init with spinner guard; FCM/Edge Functions push delivery remains future work (2026-07-04).

### Lower Priority

- [x] **45. Plan item drag-to-reorder** — `_ReorderableItemList` with drag handles in `TripDayCard`; `sortOrder` added to `ItineraryItem` model and read by `_itemFromRow`; `sortedItems` respects `sortOrder` for untimed items; `PlanService.reorderItemsInDay()` persists new order; wired to both mobile and desktop plan layouts (2026-07-04).
- [x] **46. First-run onboarding** — 5-page `PageView` dialog shown on first launch (tracked in SharedPreferences `onboarding_v1_shown`); covers Welcome, Spots voting, Plan/itinerary, Money splits, and Documents; Skip and Next buttons; triggered from `home_screen.dart` via `showOnboardingIfNeeded()` (2026-07-04).
- [x] **47. Diagnostics screen** — shows app version, Supabase URL + connection check, user ID/name/email, active trip ID/name; copy-to-clipboard on each row; accessible via More → Debug (2026-07-04).
- [x] **48. QA checklist + test data reset guide** — `docs/QA_CHECKLIST.md` covers 13 test areas (auth, invite, spots/plan/money/docs two-device tests, onboarding, diagnostics, web build) and a SQL snippet for resetting test trip data (2026-07-04).

---

---

## Phase 3 — Maps Import & Media

### Completed

- [x] **49. Google Maps import** — share any Maps URL → WabWay; resolves short links via redirect tracking; Nominatim geocoding fallback; WebView scraper for JS-rendered list pages (5 regex patterns); KML import for My Maps (2026-07-07, see `docs/features/phase 3/google-maps-import.md`).
- [x] **50. Google Takeout CSV import** — fast sync parse + instant list display; three-step background geocoding per place (Nominatim name → URL slug → Google Maps page fetch); deduplication by URL; Notes column preserved; unfound places flagged "No location found" instead of dropped; progress counter "Finding locations… X of Y" (2026-07-07, see `docs/features/phase 3/google-takeout-import.md`).
- [x] **51. Spot images (Wikipedia thumbnails)** — `WikipediaImageService` fetches thumbnail URL from Wikipedia REST API (fallback: MediaWiki pageimages API); URL stored in `spots.image_url`; shown in list tile and detail header; no local storage (2026-07-07, see `docs/features/phase 3/spot-images.md`).
- [x] **52. OCR itinerary scanner** — two-pass OCR with `google_mlkit_text_recognition`; Gemini AI fallback for multi-column booking formats; PDF text-layer extraction before image OCR; parse mode shown in banner (2026-07-07, see `docs/features/phase 3/ocr-itinerary-scanner.md`).
- [x] **53. Changelog sheet** — auto-shows once on upgrade (compares `PackageInfo.buildNumber` to `SharedPrefs last_seen_build`); accessible from More → What's new; `DraggableScrollableSheet` with release list; const `_kChangelog` list in `changelog.dart` (2026-07-09, see `docs/features/phase 3/changelog-sheet.md`).
- [x] **54. Photo albums** — Photos screen under More; members add links to Google Photos / iCloud / Dropbox albums; service auto-detected from URL; step-by-step guide for Google Photos collaborative albums; Realtime sync; migration `006_trip_photo_albums.sql` applied via `supabase db push` (2026-07-09, see `docs/features/phase 3/photo-albums.md`).
- [x] **55. Audio transcription for share intake** — `wabway-server/` Python server (faster-whisper + spaCy NER, zero API cost) runs on LG G8 via Termux; Flutter gets "Extract from audio" banner in share screen (hidden when `AUDIO_SERVER_URL` unset); `SocialPlaceExtractor.extractFromAudio` POSTs to server, geocodes returned place names via Nominatim (2026-07-09, see `docs/features/phase 3/audio-transcription.md`).

### Pending

- [ ] **56. Termux:Boot auto-start** — `pkg install termux-boot`; add `~/.termux/boot/start-server.sh` that runs `cd ~/wabway-server && bash start.sh`; keeps audio server running after phone reboot without manual intervention.

---

## Dead buttons / stubs to wire up

| Location | Button | What it needs |
|---|---|---|
| `home_screen.dart:164,194` | Bell / notifications icon | Route to notification settings screen (see #18) |
| `home_screen.dart:370` | "Settle up" | Real settlement flow (see #17) |
| `more_screen.dart:222` | Notifications settings row | Notification settings screen (see #18) |
| `spots_screen.dart:386` | Filter icon | Advanced filter sheet (see #13) |
| `incoming_share_screen.dart:94` | Travel / Links / Map share destinations | Wire to real flows (see #5) |
