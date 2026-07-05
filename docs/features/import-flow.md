# Import Flow

## Description

An in-app import sheet that accepts a URL or picked file, lets the user preview the content, choose a destination type (Spot / Travel / Plan item / Receipt / Document), and saves via existing services.

## Key Files

- `lib/screens/import_screen.dart` — main import sheet UI and routing logic
- `lib/core/place_search_service.dart` — `isMapsUrl()` used to detect Google Maps links
- `lib/core/supabase/spot_service.dart`, `travel_service.dart`, `plan_service.dart`, `money_service.dart`, `doc_service.dart` — save targets

## How It Works

1. Entry points: share intake (`incoming_share_screen.dart`) or a manual "Import" action.
2. The user sees a preview of the URL/file and selects a destination type from a picker.
3. Based on the type, the import sheet pre-fills the appropriate add-item form (e.g. the Add Spot sheet for Spot imports, the Add Receipt sheet for Receipt).
4. If the input is a Google Maps URL, `PlaceSearchService.parseLatLng()` extracts coordinates to pre-fill spot fields.
5. The user confirms and the relevant service method (`createSpot`, `createItem`, etc.) is called.

## Setup

No additional setup. Relies on existing Supabase services and tables.
