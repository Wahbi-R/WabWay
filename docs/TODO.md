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
- [x] **56. Unified import + share screen** — merged `_ImportSheet` (manual import) and `IncomingShareScreen` (Android share intent) into a single `IncomingShareScreen`; import mode shows source-picking step first (file picker, camera, URL paste) then synthesises an `IncomingShare` and continues identically; `showImportScreen()` replaces `showImportSheet()` in home and more screens; `itineraryNote` → `planItem` rename throughout `ShareDestination`; plan-item destination now fully wired with day picker and type chips (2026-07-09, see `docs/features/phase 3/unified-import-share.md`).

### Pending

- [ ] **56. Termux:Boot auto-start** — `pkg install termux-boot`; add `~/.termux/boot/start-server.sh` that runs `cd ~/wabway-server && bash start.sh`; keeps audio server running after phone reboot without manual intervention.
- [x] **57. Paste-caption fallback + server caption proxy** — `_PasteCaptionCard` in `IncomingShareScreen` lets users paste an Instagram/TikTok caption manually; `/caption` endpoint on `wabway-server` fetches captions server-side (yt-dlp primary, HTML scrape fallback) to bypass CORS; proxy URL registered via `OembedService.setProxyUrl`; auto-combined with audio transcript on `/transcribe` (2026-07-09, see `docs/features/phase 3/caption-extraction.md`).
- [x] **58. Photos create-album buttons** — empty state on Photos screen shows `_CreateAlbumCard` with Google Photos and iCloud launch buttons; note that photos don't auto-sync added to guide card subtitle (2026-07-09).
- [x] **59. Document image thumbnails** — `DocService.getThumbnailUrl` generates a 400×280 signed URL with Supabase Storage image transform (CDN-cached after first access); `DocGridCard` header and `DocListRow` leading box show `Image.network` with fade-in for image docs; non-image docs unchanged (2026-07-09, see `docs/features/phase 3/doc-thumbnails.md`).
- [x] **60. Multi-currency receipts** — `home_currency` on trips (default CAD, settable in Trip Settings); exchange rate auto-fetched from Frankfurter API at time of receipt creation and locked in; optional transaction fee field; `home_amount` stored once and never recalculated; ReceiptListTile shows original and home-currency amounts; migration `007_multi_currency_receipts.sql` applied via `supabase db push` (2026-07-09, see `docs/features/phase 3/multi-currency-receipts.md`).
- [x] **61. Auto-fetch spot thumbnails** — on spots load, spots with `imageUrl == null` are queued for Wikipedia thumbnail lookup in background; `_thumbnailAttempted` set prevents re-fetching; results streamed into list and written back to DB (2026-07-09).
- [x] **62. Plan item improvements** — spot picker at top of add-item sheet autofills title/address/city/country/mapsUrl and links the spot; location field now autocompletes via Photon; country field added to `ItineraryItem`; migration `008_itinerary_country.sql` (2026-07-09, see `docs/features/phase 3/plan-item-improvements.md`).
- [x] **65. Google Places search + shared PlaceSearchField** — submit-triggered place search (Enter or icon tap) via wabway-server `/places/search` (Google Places API) with Photon fallback; shared `PlaceSearchField` widget replaces inline search in `add_spot_sheet.dart` and `_LocationField` in `add_item_sheet.dart`; `TakeoutParser.geocodePlace` uses Google Places as step 0 before Nominatim; server `/places/search` endpoint added to `main.py` (2026-07-10, see `docs/features/phase 3/google-places-search.md`).
- [x] **66. App architecture doc** — `docs/architecture.md` covers all 13 feature areas with data flows, connections between features, nav model, state model, env vars, and known redundancies/duplications (2026-07-10).
- [x] **67. Spot sorting** — sort toggle (Newest / A–Z / Most voted) in Spots screen AppBar (mobile & desktop); sort applied after filters and search; `_SpotSort` enum + `_filtered` getter handles all three modes; "Most voted" ranks by must-do count then total votes (2026-07-10, build 31).
- [x] **68. Trip countdown chip** — trip hero on Home shows a context-aware chip: "Starts in N days", "Day X of Y", or "Ended N days ago"; uses trip `startDate`/`endDate`; hidden when no dates are set (2026-07-10, build 31).
- [x] **69. Code deduplication** — fixed `_loadAll`/`_silentReload` duplication in `plan_screen.dart` (merged into single method with `silent` param); extracted `_pushWithState` helper in `more_screen.dart` replacing 6× repeated nav boilerplate; deduplicated AppBar `actions` list in `home_screen.dart` via `_appBarActions` method; removed dead `_showEditTripNameSheet` + unreachable `_EditTripNameSheet` from `more_screen.dart` (2026-07-10, build 31).
- [x] **70. Spot CSV export** — "Export spots as CSV" button in Spots screen AppBar and desktop top bar; exports currently visible spots (after filter + sort) as a standard CSV with name/city/area/country/category/status/address/mapsUrl/notes columns; uses `share_plus` so user can save or forward from the native share sheet (2026-07-10, build 32).
- [x] **71. Tappable trip hero** — trip owner can tap the home screen hero card to open Trip Settings inline; small edit pencil icon shown as visual hint; non-owners are unaffected; `showTripSettingsSheet` already available on the More screen (2026-07-10, build 32).
- [x] **75. Multi-currency home balance card** — balance card on home screen now shows debts/credits per currency separately; total spent uses home-currency equivalents (`homeAmount`) for a consistent cross-currency total; removes the single-currency limitation that previously showed only the biggest debt in one currency (2026-07-10, build 34).
- [x] **76. Accommodations realtime** — added Supabase Postgres CDC subscription to `AccommodationsScreen`; changes made by other trip members now appear automatically without a manual refresh (2026-07-10, build 34).
- [x] **73. Global search — tappable results** — search results now navigate directly to the relevant detail screen on tap; spots open `SpotDetailScreen`, docs open `DocDetailScreen`, travel opens `TravelItemDetailScreen`, receipts open `ReceiptDetailScreen`, plan items open `ItemDetailScreen`; a chevron icon is shown as a hint; `showGlobalSearch` now accepts `tripName`, `userId`, and `members` so detail screens have the context they need (2026-07-10, build 33).
- [x] **74. Travel screen dedup** — merged `_loadAll` and `_silentReload` in `travel_screen.dart` into a single method with `silent` flag, same pattern as `plan_screen.dart` (2026-07-10, build 33).
- [x] **72. Architecture doc + comments** — `docs/architecture.md` created with full feature map, data flows, redundancy table, env vars; `trip_state.dart` annotated with InheritedWidget usage guide; `home_screen.dart`, `plan_screen.dart`, `more_screen.dart`, `spots_screen.dart` all have human-style comments on non-obvious logic (2026-07-10).
- [x] **77. Spot notes preview in list tile** — spot notes now shown inline in the `SpotListTile` (up to 2 lines, ellipsised); notes appear between the city/category row and the vote summary so the most useful info is visible without tapping; hidden when notes are empty (2026-07-10, build 35).
- [x] **78. Receipt category filter** — horizontally scrolling category chips on the Receipts tab (mobile and desktop); only categories that appear in the current list are shown; count shown on each chip; auto-hidden when all receipts share the same category (2026-07-10, build 36).
- [x] **79. Travel items sorted by departure date** — travel items now sort chronologically by departure date so the list reads like a timeline; items with no date (draft bookings) fall to the end (2026-07-10, build 36).
- [x] **80. Tappable activity feed** — activity events on the home screen now navigate directly to the relevant detail screen on tap (spots, documents, travel items, receipts, plan items); a chevron hint is shown on tappable events; member-joined, link-added, and cash-withdrawal events are non-tappable as they have no detail screen (2026-07-10, build 37).
- [x] **81. Remove dead "Settle up" button from home screen** — the balance card's "Settle up" button was a no-op placeholder; removed it and the stale TODO comment; settle-up is fully available in the Money tab (2026-07-10, build 37).
- [x] **82. Cash withdrawal notes preview** — withdrawal notes now shown in the list tile (1 line) so you can see ATM location reminders without opening the detail; consistent with the spot notes preview added in build 35 (2026-07-10, build 38).
- [x] **83. Code comments pass** — added human-style comments in `spots_screen.dart` explaining `_thumbnailAttempted` guard and the fire-and-forget thumbnail fetch pattern (2026-07-10, build 38).
- [x] **84. Links category filter** — horizontally scrolling category chips in the Links screen; only categories present in the loaded links are shown with counts; auto-hides when all links share the same category; uses `CustomScrollView` + `SliverList` so the strip scrolls with the content (2026-07-10, build 39).
- [x] **93. Stays search** — search bar added to Accommodations screen above the status filter; searches name, city, address, and notes; composable with the status filter chips; empty state is context-aware (no items vs. no results) (2026-07-10, build 47).
- [x] **92. Plan search** — search bar added to Plan screen (mobile and desktop); searches item title, location, city, and notes across all days; results shown as a flat list with day context ("Day 3 · Tokyo"); works alongside the existing day-card timeline (2026-07-10, build 46).
- [x] **91. Receipt date grouping** — receipts are grouped under date headers ("Mon, Jul 7") when sorted by date (newest/oldest); headers are omitted for amount-based sorts; implemented as a `_ReceiptListEntry` sealed class with `_DateHeader` and `_ReceiptItem` subtypes (2026-07-10, build 45).
- [x] **90. Code comments pass (build 44)** — added human-style comments to `money_screen.dart` (pending sync badge, derived-state pipeline), `global_search_screen.dart` (parallel Future.wait strategy, closure capture guard), and `links_screen.dart`; fixed missing semicolon parse error in `incoming_share_screen.dart` (2026-07-10, build 44).
- [x] **89. Travel search** — search field at top of Travel screen (mobile and desktop); searches title, location, destination, confirmation number, and notes; works together with the existing type-filter chips; empty state is context-aware (no results vs. no items) (2026-07-10, build 43).
- [x] **88. Receipt sorting** — sort receipts by newest/oldest date or highest/lowest amount via a sort menu next to the filter chips (mobile AppBar and desktop list header); sort applies after the category filter; icon turns blue when a non-default sort is active; uses `homeAmount` for amount sorts so cross-currency comparisons are consistent (2026-07-10, build 42).
- [x] **87. Links search** — search bar added to Links screen; searches title, domain, and notes; works in combination with the category filter so results can be narrowed by both type and keyword; clear button dismisses the query; empty-state message is context-aware (search vs category) (2026-07-10, build 41).
- [x] **86. Spending breakdown by category** — a card at the top of the Receipts tab showing total spent (home currency equivalent) and a per-category row with icon, amount, and a mini proportional bar; auto-hidden when all receipts are in the same category; uses `homeAmount` so mixed-currency trips show a consistent total (2026-07-10, build 40).
- [x] **85. Map screen silent realtime reload** — realtime spot changes no longer trigger a full loading spinner; debounced 400ms silent reload pattern (same as every other screen) keeps the map visible while updates stream in (2026-07-10, build 39).
- [x] **64. CSV file sharing + file type registry** — WabWay appears in Android share menu for CSV/XLS/XLSX; sharing a CSV goes straight to Takeout import; `FileTypeRegistry` centralises all accepted extensions and `ShareContentType` mapping — single edit point for new types; AndroidManifest has comment to keep MIME list in sync (2026-07-09, see `docs/features/phase 3/csv-file-support.md`).
- [x] **63. Spot country + better Maps import** — `country` field added to `Spot` model and DB (migration 009); Maps URL paste in add-spot form now resolves short links, extracts place name, and reverse-geocodes city/country via Nominatim; share flow pre-fills name/city/country when a Maps link is shared (2026-07-09, see `docs/features/phase 3/spot-country-maps-import.md`).

---

## Dead buttons / stubs to wire up

| Location | Button | What it needs |
|---|---|---|
| `home_screen.dart:164,194` | Bell / notifications icon | Route to notification settings screen (see #18) |
| `home_screen.dart:370` | "Settle up" | Real settlement flow (see #17) |
| `more_screen.dart:222` | Notifications settings row | Notification settings screen (see #18) |
| `spots_screen.dart:386` | Filter icon | Advanced filter sheet (see #13) |
| `incoming_share_screen.dart:94` | Travel / Links / Map share destinations | Wire to real flows (see #5) |
