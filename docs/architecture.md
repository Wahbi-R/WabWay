# WabWay — Architecture & Feature Map

> Auto-generated 2026-07-10. Update when adding new features or restructuring screens.

---

## App structure

```
lib/
├── main.dart                  # App entry point; Supabase init + ShareHandler init
├── core/                      # Business logic, services, utilities
│   ├── supabase/              # DB read/write; one file per domain
│   ├── places/                # Geocoding pipeline (Nominatim, GoogleMapsParser, TakeoutParser)
│   ├── share/                 # Share-intent handlers (native / web)
│   ├── ocr/                   # PDF+image OCR → itinerary parsing pipeline
│   ├── images/                # Wikipedia thumbnail fetcher
│   ├── auth/                  # AppProfile, ProfileState (InheritedWidget)
│   └── trip/                  # AppTrip, TripState (InheritedWidget), AppTripMember
├── data/                      # Pure model/enum files; no Flutter deps
├── screens/                   # One folder per feature area
│   ├── home_screen.dart
│   ├── spots_screen.dart
│   ├── plan_screen.dart
│   ├── money_screen.dart
│   ├── more_screen.dart
│   ├── travel_screen.dart
│   ├── map_screen.dart
│   ├── docs_screen.dart
│   ├── photos_screen.dart
│   ├── links_screen.dart
│   ├── accommodations/
│   ├── share/                 # Import / share intake flow
│   ├── spots/
│   ├── plan/
│   ├── money/
│   ├── travel/
│   ├── docs/
│   ├── members/
│   └── trips/
└── widgets/                   # Shared design-system widgets
    ├── place_search_field.dart
    ├── wabway_text_field.dart
    └── ...
```

---

## Navigation

The app uses a **custom desktop sidebar / mobile bottom-nav** hybrid (`TripGate`).

Mobile bottom nav tabs: **Home · Spots · Plan · Money · More**

"More" is a menu screen that pushes secondary screens as full routes:
Map, Travel, Photos, Links, Stays (Accommodations), Documents.

All screens inside `TripGate` read the active trip from **`TripState`** (InheritedWidget) and the signed-in user from **`ProfileState`** (InheritedWidget). Neither holds mutable state — they just broadcast values injected at the `TripGate` level.

---

## State model

| Layer | How it works |
|-------|-------------|
| Auth | `Supabase.instance.client.auth` → `AuthGate` wraps the whole app |
| Active trip | `TripState` InheritedWidget set by `TripGate`; calls `TripState.refresh(context)` to reload |
| Screen data | Each screen owns its local `List<X>` and reloads via `didChangeDependencies` when `tripId` changes |
| Real-time | Supabase Realtime channels per screen; debounced 400 ms before silent reload |
| Offline | `OfflineCache` (shared_preferences) stores last JSON payload; read on cold-start failure |

---

## Feature areas

### 1. Spots
**Files:** `spots_screen.dart`, `spots/spot_list_tile.dart`, `spots/spot_detail.dart`, `spots/add_spot_sheet.dart`, `data/spot_data.dart`, `core/supabase/spot_service.dart`

**What it does:**
- Collaborative list of places the group wants to visit on the trip
- Each spot has: name, city, area, country, category (Food / Landmark / Nature / Experience / Shopping / Nightlife), status (Idea → Want to go → Must-do → Confirmed → Planned → Booked / Skipped), optional lat/lng, Maps URL, notes, source URL
- Members can **vote** (Must-do / Want / Maybe / Skip) on each spot
- Members can **comment** on spots
- **Filters:** category strip (horizontal scroll), advanced filter sheet (status multi-select, city)
- **Search:** inline text search across name/city/area
- Wikipedia thumbnails auto-fetched for any spot missing an image
- Desktop: master-detail split; Mobile: list → full detail route

**Data flow:**
```
Supabase `spots` table
  └── SpotService.loadSpots()
        └── Spot model (with SpotVotes, SpotComment list)
              └── SpotsScreen (_spots list)
                    ├── SpotListTile  (list item)
                    └── SpotDetailContent / SpotDetailScreen (detail)
```

**Connects to:**
- Plan: Spot can be linked to an itinerary item; "Unplanned Spots" section in Plan shows confirmed/planned spots not yet on a day
- Share: Google Maps link or Takeout CSV → creates new Spot
- Maps screen: all spots appear as pins

---

### 2. Plan
**Files:** `plan_screen.dart`, `plan/day_card.dart`, `plan/item_tile.dart`, `plan/item_detail.dart`, `plan/add_item_sheet.dart`, `data/plan_data.dart`, `core/supabase/plan_service.dart`

**What it does:**
- Day-by-day itinerary with ordered items per day
- Each **day**: date, city, optional notes
- Each **item**: title, type (Spot/Travel/Food/Activity/Free Time/Transport/Other), time (24h string), city, country, location/address, Maps URL, confirmation URL, notes, optional linked Spot, optional linked Documents, sort order
- Items can be **reordered** within a day (drag handles), **moved** between days, **duplicated**
- "Unplanned Spots" panel shows confirmed/planned spots not yet scheduled — tap to pick a day
- **Export:** plain-text share, `.ics` calendar file
- Desktop: split list/detail with day-header detail panel

**Data flow:**
```
Supabase `itinerary_days` + `itinerary_items` tables
  └── PlanService.loadAll()
        └── List<TripDay> (each holds List<ItineraryItem>)
              └── PlanScreen
                    ├── TripDayCard  (day + item list)
                    └── ItemDetailContent / ItemDetailScreen
```

**Connects to:**
- Spots: items can be linked to a Spot (`linkedSpotId`)
- Documents: items can reference docs (`linkedDocIds`)
- Home: "Coming up" card shows next day / next item
- Travel: displayed alongside plan in "Coming up" logic

---

### 3. Money
**Files:** `money_screen.dart`, `money/receipt_list_tile.dart`, `money/receipt_detail.dart`, `money/add_receipt_sheet.dart`, `money/cash_list_tile.dart`, `money/cash_detail.dart`, `money/add_cash_sheet.dart`, `money/settle_up_panel.dart`, `data/money_data.dart`, `core/supabase/money_service.dart`, `core/supabase/settlement_service.dart`

**What it does:**
- **Receipts tab**: log shared expenses; paid-by member + per-member split
- **Cash tab**: log ATM withdrawals
- **Settle-up tab**: calculated balance per member (who owes whom)
- Receipts have: title, amount, currency (trip default), home-currency equivalent (locked at creation via Frankfurter API exchange rate), transaction fee %, category, date, notes, optional receipt photo
- Multi-currency: amounts stored in foreign currency; `homeAmount` = amount × rate locked at time of purchase
- Settle-up uses `calculateBalances()` from `money_data.dart` — pure function over receipts + withdrawals

**Data flow:**
```
Supabase `receipts` + `cash_withdrawals` + `settlements` tables
  └── MoneyService.loadReceipts/loadWithdrawals
        └── MoneyScreen
              ├── ReceiptListTile / ReceiptDetail
              ├── CashListTile / CashDetail
              └── SettleUpPanel (reads calculateBalances())
```

**Connects to:**
- Home: "Quick balance" card shows net owed/owing for current user

---

### 4. Travel
**Files:** `travel_screen.dart`, `travel/travel_item_card.dart`, `travel/travel_item_detail.dart`, `travel/add_travel_sheet.dart`, `data/travel_data.dart`, `core/supabase/travel_service.dart`

**What it does:**
- Tracks transport legs: Flights, Trains, Ferries, Buses, Car rentals
- Each item: type, title, origin/destination (city names), departure/arrival date+time, confirmation URL, confirmation number, notes, optional linked docs
- Filterable by transport type
- Desktop: master-detail split

**Connects to:**
- Home: "Coming up" card falls back to next travel item if no plan day found
- Documents: can link travel docs to a travel item

---

### 5. Documents
**Files:** `docs_screen.dart`, `docs/doc_card.dart`, `docs/doc_detail.dart`, `docs/add_doc_sheet.dart`, `data/docs_data.dart`, `core/supabase/doc_service.dart`

**What it does:**
- Stores trip documents per trip: PDFs, images, Word/Excel files
- Two modes: **upload** (stored in Supabase Storage under `trip-documents/`) or **link** (URL only)
- Grid + list view toggle
- Image docs show a thumbnail (Supabase Storage image transform, 400×280, CDN-cached)
- Documents can be linked to Plan items and Travel items

**Connects to:**
- Plan: `linkedDocIds` on itinerary items
- Travel: can link travel docs
- Share/import: incoming PDFs or images can be saved as docs via the share intake

---

### 6. Accommodations (Stays)
**Files:** `accommodations/accommodations_screen.dart`, `accommodations/add_accommodation_sheet.dart`, `data/accommodation_data.dart`, `core/supabase/accommodation_service.dart`

**What it does:**
- Tracks hotel/AirBnB/hostel bookings
- Fields: name, type (hotel/hostel/apartment/etc.), location, check-in/check-out dates, confirmation number, URL, notes, booked-by member
- List view with date range display

---

### 7. Photos
**Files:** `photos_screen.dart`, `photos/add_album_sheet.dart`, `data/photo_album_data.dart`, `core/supabase/photo_album_service.dart`

**What it does:**
- Shared album link collection: Google Photos, iCloud, Dropbox, generic links
- Each album: label, URL, service auto-detected from URL
- Tap to open in browser
- Empty state guides user to create a Google Photos / iCloud shared album

---

### 8. Links
**Files:** `links_screen.dart`, `links/add_link_sheet.dart`, `data/links_data.dart`, `core/supabase/links_service.dart`

**What it does:**
- Shared bookmark list for the trip (tickets, reservations, articles, etc.)
- Each link: title, URL, optional notes
- Tap to open in browser

---

### 9. Map
**Files:** `map_screen.dart`

**What it does:**
- Displays all trip spots as map pins (Flutter Map / Leaflet)
- Category-colour pins
- Tap pin to see spot name and category

---

### 10. Share / Import
**Files:** `share/incoming_share_screen.dart`, `share/maps_import_screen.dart`, `share/parsed_itinerary_screen.dart`, `share/extracted_spots_screen.dart`, `share/maps_web_scrape_screen.dart`, `core/share/`, `core/ocr/`, `core/places/`

**What it does — full pipeline:**

```
Android Share Intent  ─┐
In-app Import button  ─┤
                        ▼
              IncomingShareScreen
              (detects content type)
                    │
          ┌─────────┼──────────┐
          ▼         ▼          ▼
       Image/PDF   URL       CSV/Excel
          │         │          │
          │    Maps URL?       │
          │      ├── Yes ──→ add_spot_sheet (pre-filled)
          │      └── No ───→ ShareForm (route to spot/doc/plan)
          │                   │
          ▼                   ▼
    OCR pipeline         MapsImportScreen
    (pdf_reader           (Takeout JSON/CSV)
     ocr_service           geocodePlace pipeline:
     gemini_parser)         0. Google Places (/places/search)
          │                 1. Nominatim by name
          ▼                 2. Nominatim by URL slug
    ParsedItineraryScreen   3. GoogleMapsParser.fetchCoordsFromUrl
    (booking docs →
     plan items)
```

**Content types handled:**

| Type | Detected by | Action |
|------|------------|--------|
| Google Maps URL | `PlaceSearchService.isMapsUrl` | Resolve via `/maps/enrich` → pre-fill add_spot |
| Short Maps URL (goo.gl) | Same | Follow redirects first |
| CSV file | extension + MIME | → MapsImportScreen (Takeout CSV) |
| GeoJSON / Takeout JSON | content detection | → MapsImportScreen |
| Image/PDF | MIME / SharedMediaType | → OCR pipeline or add_doc |
| Plain text/URL | fallback | → ShareForm |

---

### 11. Place Search
**Files:** `core/place_search_service.dart`, `widgets/place_search_field.dart`, `core/places/nominatim_service.dart`, `core/places/google_maps_parser.dart`, `core/places/takeout_parser.dart`, `wabway-server/main.py`

**What it does:**
- Unified place search used in Add Spot and Add Plan Item
- Submit-triggered (Enter or icon tap — not per keystroke, to avoid burning API credits)
- Pipeline: **wabway-server `/places/search`** (Google Places) → fallback **Photon** (OSM)
- Also used by `TakeoutParser.geocodePlace` as step 0

**Server endpoints:**
- `POST /places/search` — text query, optional lat/lng bias, returns up to N results
- `POST /maps/enrich` — takes a Google Maps URL + coords, returns full place details
- `POST /transcribe` — audio file → Whisper transcription → place extraction
- `GET /caption` — fetches Instagram/TikTok caption server-side (bypasses CORS)

---

### 12. Activity Feed
**Files:** `core/supabase/activity_service.dart`, `data/activity_data.dart`

**What it does:**
- Reads `activity_log` Supabase table
- Events are written by DB triggers when records are inserted/updated/deleted
- Home screen shows the 20 most recent events with actor name, verb, entity title, and relative timestamp

---

### 13. Members & Invites
**Files:** `members/add_member_sheet.dart`, `members/invite_sheet.dart`, `core/supabase/invite_service.dart`, `core/supabase/trip_member_service.dart`

**What it does:**
- **Add by email**: searches profiles, adds directly
- **Invite code**: generates a short code; recipient enters it in "Join trip" flow
- Owner can remove members and transfer ownership

---

## Redundancies / known duplications

### Resolved
- ~~`_LocationField` in `add_item_sheet.dart`~~ — replaced by `PlaceSearchField` (build 30)
- ~~Inline debounced search in `add_spot_sheet.dart`~~ — replaced by `PlaceSearchField` (build 30)
- ~~Three separate `allowedExtensions` lists~~ — unified into `FileTypeRegistry` (build 29)
- ~~MIME detection logic duplicated in share_handler and incoming_share_screen~~ — unified into `FileTypeRegistry` (build 29)

### Still present
| Redundancy | Location | Notes |
|-----------|----------|-------|
| `_showEditTripNameSheet` defined but never called | `more_screen.dart:597` | Dead code; `showTripSettingsSheet` is used instead |
| Nav boilerplate: `ProfileState(TripState(MaterialPageRoute(...)))` | `more_screen.dart` | Repeated 6× for Map/Travel/Photos/Links/Stays/Docs |
| `_loadAll` and `_silentReload` nearly identical | `plan_screen.dart:88,117` | The only diff is whether loading state is set |
| AppBar `actions` list | `home_screen.dart` | Copy-pasted in both error and success build paths |
| `_monthAbbr` constants inline in `_fmtTripDates` | `home_screen.dart:305` | Identical array could be a shared const |

---

## Data model overview

```
Trip (AppTrip)
  ├── TripMember[]        (trip_members table)
  ├── Spot[]              (spots + spot_votes + spot_comments)
  │     └── PlaceSuggestion (ephemeral, from place search)
  ├── TripDay[]           (itinerary_days)
  │     └── ItineraryItem[]  (itinerary_items)
  ├── Receipt[]           (receipts + receipt_splits)
  ├── CashWithdrawal[]    (cash_withdrawals)
  ├── Settlement[]        (settlements)
  ├── TravelItem[]        (travel_items)
  ├── TripDocument[]      (trip_documents, Supabase Storage)
  ├── Accommodation[]     (accommodations)
  ├── TripPhotoAlbum[]    (photo_albums)
  ├── TripLink[]          (trip_links)
  └── ActivityEvent[]     (activity_log — read-only, written by DB triggers)
```

---

## Key environment variables (.env)

| Variable | Used by |
|----------|---------|
| `SUPABASE_URL` | Supabase client init |
| `SUPABASE_ANON_KEY` | Supabase client init |
| `AUDIO_SERVER_URL` | `PlaceSearchService`, `MapsImportService` — wabway-server base URL |

**wabway-server** (separate Python FastAPI process on the same device):

| Variable | Purpose |
|----------|---------|
| `GOOGLE_PLACES_API_KEY` | `/places/search` + `/maps/enrich` — Google Places (New) API |
| `GEMINI_API_KEY` | `/ocr` — Gemini Vision fallback for complex documents |
| `PORT` | Server listen port (default 8000) |

---

## Build & deploy

```bash
# Flutter app (debug APK with env injection)
flutter build apk --debug --dart-define-from-file=.env

# wabway-server (Termux on device)
git pull origin master && ./start.sh
```

Migrations: `supabase db push` from the project root.
