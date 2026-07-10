# WabWay — Feature Catalogue

> Last updated: 2026-07-10 (build 49)
>
> This document lists every major feature in the app — what it does, how it works internally, and what other features it connects to. Use it as a map when adding something new or hunting for the right place to make a change.

---

## Table of Contents

1. [Authentication & Profile](#1-authentication--profile)
2. [Trip Management](#2-trip-management)
3. [Home Screen](#3-home-screen)
4. [Spots](#4-spots)
5. [Links](#5-links)
6. [Map](#6-map)
7. [Plan / Itinerary](#7-plan--itinerary)
8. [Travel](#8-travel)
9. [Stays / Accommodations](#9-stays--accommodations)
10. [Money](#10-money)
11. [Documents](#11-documents)
12. [Members](#12-members)
13. [Photos](#13-photos)
14. [Global Search](#14-global-search)
15. [Import Flow](#15-import-flow)
16. [Android Share Intake](#16-android-share-intake)
17. [More Screen](#17-more-screen)
18. [Realtime / Offline Behaviour](#18-realtime--offline-behaviour)
19. [Redundancy & Consolidation Notes](#19-redundancy--consolidation-notes)

---

## 1. Authentication & Profile

**What it does:** Email/password and magic-link sign-in via Supabase Auth. After sign-in, the user's profile (display name, avatar) is fetched and made available app-wide through `ProfileState`.

**How it works:**
- `lib/screens/auth/` — sign-in, sign-up, forgot-password screens
- `lib/core/auth/profile_state.dart` — `InheritedWidget` that exposes `ProfileState.of(context)` everywhere; carries `id`, `displayName`, `avatarUrl`
- Supabase RLS policies use the `auth.uid()` function, so every query is automatically scoped to the signed-in user

**Connects to:** Every screen reads `ProfileState.of(context).id` to identify the current user (e.g., which receipts "you" paid, which spots "you" voted on).

---

## 2. Trip Management

**What it does:** Users can belong to multiple trips. The active trip is held in `TripState` and propagated via `InheritedWidget`. A switcher sheet lets users switch trips or create new ones.

**How it works:**
- `lib/core/trip/trip_state.dart` — `TripState` InheritedWidget; exposes `TripState.tripOf(context)` (returns `AppTrip`) and `TripState.membersOf(context)` (returns `List<AppTripMember>`)
- `lib/screens/trips/trip_switcher_sheet.dart` — bottom sheet showing the user's trips; tap to switch active trip
- `lib/screens/trips/trip_settings_sheet.dart` — edit trip name, destination, home currency, start/end dates; owner-only actions
- `lib/core/supabase/trip_service.dart` — CRUD for trips and membership
- `AppTrip` model: `id`, `name`, `destination`, `homeCurrency`, `startDate`, `endDate`, `ownerId`

**Connects to:** Every feature uses `TripState.tripOf(context).id` as the `trip_id` key to scope data. `homeCurrency` is used by the Money screen for cross-currency receipt equivalents.

---

## 3. Home Screen

**What it does:** Landing screen after sign-in. Shows a trip hero card, spending balance summary, next planned day, next travel item, and a recent activity feed.

**How it works:**
- `lib/screens/home_screen.dart` — loads `_HomeData` via `Future.wait` across SpotService, DocService, TravelService, MoneyService, PlanService, MemberService, ActivityService
- `_TripHero` — shows trip name, destination, dates, a countdown chip ("In 14 days" / "Day 3 of 14" / "Returned 2 days ago"), and 3 stat counters (spots saved, days planned, total spent)
- `_QuickBalanceCard` — summarises who owes whom; derives from `_HomeData.balancesByCurrency`
- `_UpcomingCard` — shows the next itinerary day with ≥1 item, and the next upcoming travel item
- `_ActivityFeed` — shows recent `ActivityEvent` objects (spots added/voted, docs uploaded, receipts added, items planned); each row navigates to the relevant detail screen
- `_UpdateBanner` — checks GitHub Releases API on load; shown if a newer build is available

**Connects to:** Spot detail, Doc detail, Travel item detail, Receipt detail, Plan item detail (activity feed tap targets); Trip settings (hero tap for trip owners); Notification settings (bell icon); Global search (search icon); Import flow (download icon).

---

## 4. Spots

**What it does:** A shared list of places the group wants to visit. Each spot has a name, category (Food, Activity, Shopping, etc.), status (Exploring / Planned / Confirmed / MustDo), city/country, optional coordinates, Google Maps URL, notes, and a vote system (Must-do / Want-to / Skip).

**How it works:**
- `lib/screens/spots_screen.dart` — list/grid/map-mode toggle, category filter (with per-category counts), status filter, search, sort (Newest / Alphabetical / Most Voted)
- `lib/screens/spots/` — spot_list_tile, spot_card (grid), spot_detail_screen, add_spot_sheet, spot_vote_summary
- `lib/core/supabase/spot_service.dart` — `loadSpots`, `createSpot`, `updateSpot`, `deleteSpot`, `upsertVote`; also generates thumbnail URLs for image docs linked to a spot
- `lib/data/spot_data.dart` — `Spot`, `SpotVotes`, `SpotStatus`, `SpotCategory` models
- Category filter auto-hides when fewer than 2 categories are present; shows counts
- Realtime: Supabase CDC subscription on the `spots` table; silent reload with 400ms debounce
- CSV export: currently visible (after filter+sort) spots exported as tab-separated text via `share_plus`

**Connects to:** Plan ("Unplanned Spots" panel uses confirmed/planned spots not yet on a day), Map (spots are the map pins), Doc linking (docs can be attached to spots), Global search (spots are one result type).

---

## 5. Links

**What it does:** A shared bookmark list for URLs the group wants to remember — Instagram posts, articles, Maps links, restaurant pages, etc.

**How it works:**
- `lib/screens/links_screen.dart` — search bar, category filter strip (only shows when 2+ categories present, with counts), list of link cards
- `lib/screens/links/add_link_sheet.dart` — URL paste/edit; category auto-detected from domain (e.g., `instagram.com` → Social, `tabelog.com` → Food)
- `lib/core/supabase/links_service.dart` — `loadLinks`, `createLink`, `deleteLink`
- `lib/data/links_data.dart` — `TripLink` model + `LinkCategory` enum (General, Food, Accommodation, Activity, Shopping, Article, Social)
- Opening a link uses `url_launcher` in external app mode
- Realtime: CDC subscription on `trip_links` with 400ms debounce silent reload

**Connects to:** Global search (links not included in search yet — potential future addition), Share intake (URLs shared from other apps go through `IncomingShareScreen` which can save them as links).

---

## 6. Map

**What it does:** Interactive OpenStreetMap showing all spots as coloured pins. Pins are coloured by spot status (green = confirmed, blue = mustDo, etc.). Tapping a pin opens a bottom sheet with spot details.

**How it works:**
- `lib/screens/map_screen.dart` — uses `flutter_map` + `flutter_map_marker_cluster`; loads spots via `SpotService`; `_fitIfNeeded` zooms the camera to fit all visible markers on first load
- Status-colour mapping defined in `lib/data/spot_data.dart` (SpotStatus.color)
- Realtime: CDC subscription with 400ms debounce and `silent: true` load so the map doesn't flash on updates

**Connects to:** Spots (map shows the same spots as the list screen), Spot detail (tap a pin → sheet with "Open full details" → navigates to SpotDetailScreen).

---

## 7. Plan / Itinerary

**What it does:** Day-by-day trip timeline. Each day has a date, city, optional notes, and a list of itinerary items (meals, activities, transport, accommodation, etc.). Items can be reordered by drag-and-drop within a day, moved between days, and linked to spots or documents.

**How it works:**
- `lib/screens/plan_screen.dart` — mobile: scrolling list of `TripDayCard`; desktop: two-panel (day list | detail panel); search bar flattens all items into a search results list
- `lib/screens/plan/day_card.dart` — collapsed/expanded day card with drag-to-reorder items
- `lib/screens/plan/item_detail.dart` / `lib/screens/plan/add_item_sheet.dart` — full item detail and add sheet
- `lib/core/supabase/plan_service.dart` — `loadAll` (returns `List<TripDay>`), `createDay`, `updateDay`, `deleteDay`, `createItem`, `updateItem`, `deleteItem`, `moveItem`, `reorderItemsInDay`, `duplicateItem`
- `lib/data/plan_data.dart` — `TripDay`, `ItineraryItem`, `ItineraryItemType` (Activity, Food, Flight, Hotel, Train, Transport, Other) models
- Unplanned Spots section: confirmed/planned spots that haven't been linked to an item appear at the top; tapping one prefills an add-item sheet with the spot's name and category-mapped type
- ICS calendar export: builds `.ics` text and shares via `share_plus` (native only, not web)
- Realtime: CDC on `itinerary_days` + `itinerary_items`; silent reload with debounce

**Connects to:** Spots (unplanned spots panel, item ↔ spot linking), Docs (items can have attached documents), Travel (items can reference travel bookings indirectly), Global search (plan items are a search result type).

---

## 8. Travel

**What it does:** Tracks flights, hotels, trains, ferries, buses, and car rentals. Each item has a type, title, dates, origin/destination, confirmation number, notes, and linked documents.

**How it works:**
- `lib/screens/travel_screen.dart` — search bar, type filter chips (with per-type counts; hidden when < 2 types present), sorted chronologically (items without a date fall to the end)
- `lib/screens/travel/` — travel_list_tile, travel_detail_screen, add_travel_sheet
- `lib/core/supabase/travel_service.dart` — `loadItems`, `createItem`, `updateItem`, `deleteItem`
- `lib/data/travel_data.dart` — `TravelItem`, `TravelItemType` (Flight, Hotel, Train, Ferry, Bus, Car, Other) models
- Realtime: CDC on `travel_items` with 400ms debounce

**Connects to:** Plan (travel items can be referenced from plan items; `TravelItemDetailScreen` receives `days` for navigation context), Docs (docs can be attached to travel items), Global search.

---

## 9. Stays / Accommodations

**What it does:** A dedicated screen for accommodation options being considered or already booked. Separate from general Travel items because accommodations often require more comparison work (shortlisting, brainstorming) before booking.

**How it works:**
- `lib/screens/accommodations/accommodations_screen.dart` — `CustomScrollView` with search bar + status filter strip; search covers name, city, address, notes
- `lib/screens/photos/add_album_sheet.dart` (note: misnamed dir; this is the add accommodation sheet at `lib/screens/accommodations/add_accommodation_sheet.dart`)
- `lib/core/supabase/accommodation_service.dart` — `loadAll`, `create`, `update`, `delete`
- `lib/data/accommodation_data.dart` — `Accommodation`, `AccommodationStatus` (Brainstorming / Shortlisted / Booked), `AccommodationType`
- Accommodation cards show name, city, check-in/out dates, price, status badge, and a link button (opens the listing URL)
- Realtime: CDC on `accommodations` with 400ms debounce

**Connects to:** Docs (accommodation confirmation docs can be attached; not yet directly wired as a linking target — potential future improvement), Global search (not yet included — potential future addition).

---

## 10. Money

**What it does:** Shared expense tracker. Supports multi-currency receipts, cash withdrawals, per-member splits, and a settle-up flow that calculates who owes whom and suggests minimum transfers.

**How it works:**
- `lib/screens/money_screen.dart` — three tabs: Receipts, Cash, Settle Up
- **Receipts tab:** spending summary card (category breakdown with progress bars, hidden when < 2 categories), category filter strip (with counts), sort button (Newest/Oldest/Highest/Lowest), receipt list grouped under date headers when sorted by date
- `lib/screens/money/receipt_list_tile.dart` / `receipt_detail.dart` / `add_receipt_sheet.dart` — receipt CRUD
- `lib/screens/money/cash_list_tile.dart` / `cash_detail.dart` / `add_cash_sheet.dart` — cash withdrawal CRUD
- `lib/screens/money/settle_up_panel.dart` — balance summary + settlement suggestions + mark-as-settled flow
- `lib/core/supabase/money_service.dart` — `loadReceipts`, `loadWithdrawals`, `createReceipt`, `updateReceipt`, `deleteReceipt`, etc.
- `lib/data/money_data.dart` — `Receipt`, `ReceiptSplit`, `CashWithdrawal`, `MemberBalance`, `SettlementSuggestion`, `ReceiptCategory` (Food, Transport, Accommodation, Activity, Shopping, Other); `homeAmount` = locked home-currency equivalent at time of entry
- Offline sync: `lib/core/sync_queue.dart` — receipts added while offline go into a local queue; synced when connectivity returns; a "N pending" badge shown in the AppBar
- Realtime: CDC on `receipts` + `cash_withdrawals` + `settlements`

**Connects to:** Docs (receipts can have attached doc images — ATM slips, restaurant bills), Members (splits reference trip members), Home screen (balance summary card on home screen derives from the same `balancesByCurrency` calculation), Global search.

---

## 11. Documents

**What it does:** A shared document storage for the trip. Supports uploading photos and files to Supabase Storage, viewing them, and linking them to other trip entities (spots, travel items, plan items, receipts, etc.).

**How it works:**
- `lib/screens/docs_screen.dart` — grid (mobile) or list (desktop) view; type filter + search; `FutureBuilder` thumbnails for image files via `DocService.getThumbnailUrl`
- `lib/screens/docs/doc_card.dart` — `DocGridCard` and `DocListRow` widgets; image docs show a thumbnail via Supabase Storage image transform API (400×280 crop)
- `lib/screens/docs/doc_detail.dart` — full detail with metadata, linked entities, download/share
- `lib/core/supabase/doc_service.dart` — `loadDocuments`, `uploadDocument`, `deleteDocument`, `getThumbnailUrl` (cached per `storagePath`)
- `lib/data/docs_data.dart` — `TripDocument`, `DocType` (Photo, PDF, Passport, Visa, Insurance, Itinerary, Voucher, Other) models
- Linking: `document_links` junction table ties docs to `Receipt`, `CashWithdrawal`, `TravelItem`, `ItineraryItem`, `TripDay`, `Spot`, `Trip`

**Connects to:** Every major entity can have attached documents (Spots, Travel, Plan, Money). Photos screen is separate (album links, not uploads). Global search includes document titles.

---

## 12. Members

**What it does:** Shows the trip's member list, invite new members by email, manage roles, and transfer ownership.

**How it works:**
- `lib/screens/members_screen.dart` — member list with role badges; invite button
- `lib/screens/members/invite_sheet.dart` — email input; sends a Supabase invite
- `lib/core/supabase/member_service.dart` — `loadMembers`, `inviteMember`, `removeMember`, `updateRole`, `transferOwnership`
- `lib/data/member_data.dart` — `AppTripMember` (userId, profile, role), `TripMember` (a slimmer version used by Money for splits)
- Realtime: CDC on `trip_members`

**Connects to:** Money (member list used for receipt splits and balance calculations), Home (activity feed shows member display names), Global search (members list passed in for receipt detail navigation).

---

## 13. Photos

**What it does:** Shared photo album aggregator. Instead of uploading photos to the app, the group pastes shared album links (Google Photos, iCloud, Dropbox, etc.) so everyone can access them from one place.

**How it works:**
- `lib/screens/photos_screen.dart` — list of `TripPhotoAlbum` cards; each card shows the platform icon, title, notes, and a "Open album" button
- `lib/screens/photos/add_album_sheet.dart` — paste album URL; platform auto-detected from domain
- `lib/core/supabase/photo_album_service.dart` — `loadAlbums`, `createAlbum`, `updateAlbum`, `deleteAlbum`
- `lib/data/photo_album_data.dart` — `TripPhotoAlbum`, `PhotoAlbumPlatform` (GooglePhotos, iCloud, Dropbox, OneDrive, Other) models
- Audio transcription banner: a dismissible info card explaining how to get transcripts of TikTok/Instagram Reels via the share flow
- Realtime: CDC on `trip_photo_albums`

**Connects to:** Share intake (TikTok/Instagram URLs shared to WabWay trigger an audio transcription suggestion); Docs (separate feature — album links vs. uploaded files).

---

## 14. Global Search

**What it does:** Full-trip search across all content types in one screen. Results are grouped by type (Spots, Documents, Travel, Receipts, Itinerary) with section headers.

**How it works:**
- `lib/screens/global_search_screen.dart` — launched as a modal route via `showGlobalSearch()`; fetches all 5 data sources in parallel with `Future.wait`; filters client-side on query change
- `_results` getter: iterates each data source and constructs `_Result` objects with `kind`, `title`, `subtitle`, `icon`, and an `onTap` closure that navigates to the relevant detail screen
- Results are grouped by `_ResultKind` enum (spot, doc, travel, receipt, plan) and rendered under section labels
- The `_moneyMembers` getter converts `AppTripMember` → `TripMember` for `ReceiptDetailScreen` which needs the slimmer type
- Launched from: Home screen AppBar search icon

**Connects to:** Every data type (reads from all 5 services), all detail screens (result tap → navigate to the item).

---

## 15. Import Flow

**What it does:** A unified screen for importing data from external sources — Google Takeout JSON, CSV files, OCR'd itineraries, Google Maps URLs, and listing page URLs (Airbnb, Booking.com, etc.).

**How it works:**
- `lib/screens/import/` — entry point `showImportScreen()`, sub-screens for each import type
- `lib/core/ocr/` — `ItineraryScanner` (uses Gemini Vision to extract structured plan data from photos/screenshots), `GeminiParser` (JSON → plan items), `ItineraryParser` (text heuristics fallback)
- `lib/core/places/` — `GoogleMapsParser` (extracts lat/lng from Maps URLs), `ListingParser` (Airbnb/Booking URL → accommodation draft), `SocialPlaceExtractor` (Instagram/TikTok → spot draft), `NominatimService` (reverse geocoding)
- `lib/core/share/` — `FileTypeRegistry` (centralises accepted MIME types and maps them to `ShareContentType`)
- Google Takeout: JSON file → batch-creates spots
- CSV: trips/spots CSV → batch-creates spots (shares the takeout path)
- OCR itinerary: photo/screenshot → Gemini API → `ParsedItineraryScreen` to review before saving

**Connects to:** Spots (most imports create spots), Plan (OCR import can create plan days + items), Travel (listings can create travel items), Accommodations (listing parser creates accommodation drafts).

---

## 16. Android Share Intake

**What it does:** WabWay appears in the Android share sheet for URLs, images, CSV files, and audio files. Receiving content opens `IncomingShareScreen` which routes it to the right flow based on content type.

**How it works:**
- `AndroidManifest.xml` — `intent-filter` for `ACTION_SEND` / `ACTION_SEND_MULTIPLE` covering `text/plain`, `image/*`, `audio/*`, `text/csv`, `application/vnd.ms-excel`, `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
- `lib/screens/share/incoming_share_screen.dart` — `ShareHandler.pending` called on init; content type detected via `FileTypeRegistry`; routes to: spot import (Maps URL/listing), doc upload, CSV takeout import, audio transcription suggestion, or manual import flow
- `lib/core/platform/platform_file.dart` — cross-platform `PlatformFile` wrapper (native uses `dart:io` File, web uses a stub)
- Audio transcription: shows an `AudioTranscriptionBanner` explaining Gemini transcription; no auto-processing yet (future feature)

**Connects to:** All import flows (Maps → spot, listing URL → accommodation, CSV → takeout), Docs (image shares → doc upload), Links (plain URL shares → save as link).

---

## 17. More Screen

**What it does:** Overflow navigation for less-frequently used features: Changelog, Trip Settings, Notification Settings, Diagnostics, and account management (sign out, delete account).

**How it works:**
- `lib/screens/more_screen.dart` — list of tappable rows; each opens its target screen
- Changelog: reads from `lib/core/changelog.dart` (`_kChangelog` list); shown in a bottom sheet sorted newest-first; unread badge uses `SharedPreferences` to track the last-seen build number
- Notification settings: `lib/screens/notification_settings_screen.dart` — static preference toggles (push not yet active, settings stored in-memory for the session)
- Diagnostics: `lib/screens/diagnostics_screen.dart` — shows Supabase connection status, auth state, trip ID, build number

**Connects to:** Trip settings (edit trip metadata), Changelog (build history), Account management (sign out → back to auth screen).

---

## 18. Realtime / Offline Behaviour

**What it does:** Every data screen subscribes to Supabase Realtime CDC (Change Data Capture) events so changes made by other group members appear without a manual refresh. When offline, an `OfflineBanner` is shown and the UI uses the last-loaded data.

**How it works:**
- Pattern used in every screen:
  1. `_channel = supabase.channel('table-$tripId').onPostgresChanges(...)` in `_subscribe()`
  2. Callback cancels any pending `_debounce` timer, then schedules a 400ms `_load(silent: true)`
  3. `_load({bool silent = false})` — when silent=true, the loading spinner is suppressed; only `_error` / `_offline` state is updated on failure
  4. `_channel?.unsubscribe()` in `dispose()`
- Offline detection: `catch` in `_load` checks if it's a network error; if silent, sets `_offline = true` which shows `OfflineBanner`; if not silent, shows the error empty state
- Money screen has an additional `SyncQueue` for receipts added while offline

**Connects to:** Every data screen. The `OfflineBanner` widget (`lib/widgets/offline_banner.dart`) is shared across screens.

---

## 19. Redundancy & Consolidation Notes

These are features that overlap or could potentially be merged:

| Area | Current State | Consolidation Opportunity |
|---|---|---|
| **Import entry points** | Import screen (home AppBar), Share intake (Android), and OCR scanner are three separate flows | Could unify under a single "Add content" sheet that routes to the right import method based on what the user has |
| **Search bars** | Each screen has its own search bar implementation (Links, Travel, Spots, Plan, Stays, Docs all have slightly different TextField implementations) | A shared `WabwaySearchBar` widget would reduce duplication — currently only the border/style/padding patterns are repeated |
| **Filter strips** | Each screen builds its own `WabwayTag`-based horizontal strip — Links, Spots, Money, Accommodations, Travel, Docs all repeat the same `SizedBox(height: 52) + ListView(horizontal)` pattern | A `WabwayFilterStrip<T>` generic widget would collapse ~50 lines repeated 6+ times |
| **Empty states** | `WabwayEmptyState` already exists and is used consistently — no issue here | ✓ Already consolidated |
| **Date formatting** | `fmtDate` in `money_data.dart`, `fmtDayDate` in `plan_data.dart`, `_DateGroupHeader._days/_months` in `money_screen.dart` — three separate date formatting implementations | A shared `lib/core/date_utils.dart` or extension on `DateTime` would unify these |
| **Offline banner** | `OfflineBanner` widget used in some screens (Links, Money) but not others (Spots shows an error state instead) | Decide on a consistent offline UX pattern: either `OfflineBanner` everywhere or the error empty-state everywhere |
| **Stays vs. Travel** | Accommodations ("Stays") and Travel both track lodging — Hotels in Travel Items and Accommodations in the Stays screen overlap | Consider auto-linking: when a Travel item of type `Hotel` is created, offer to create a matching Accommodation entry (or vice versa) |
| **Photo albums vs. Docs** | Photos screen stores external album links; Docs screen stores uploaded files — both are "media the group wants to access" | The Photos screen is intentionally lightweight (no uploads); the overlap is only conceptual, not a code problem |
| **Activity feed vs. Notifications** | Home screen activity feed shows recent changes; Notification settings exist but push isn't active | When push is activated, the activity feed data could be the notification payload source |
