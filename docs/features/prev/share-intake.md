# Android Native Share Intake

## What it does

Handles Android `ACTION_SEND` and `ACTION_SEND_MULTIPLE` intents so users can share content from other apps (Google Maps, Chrome, Photos, Files) directly into WabWay.

## Intent filters (AndroidManifest.xml)

| MIME type | Use case |
|---|---|
| `text/plain` | URLs shared from any app |
| `image/*` | Receipt photos, screenshots |
| `application/pdf` | Booking confirmations |
| `image/*` (SEND_MULTIPLE) | Multiple images at once |

## Share handler (`share_handler.dart`)

Singleton `ShareHandler.instance` bridges the plugin to Flutter:
- **Cold-start**: `getInitialMedia()` called in `init()` — captures shares that launched the app
- **While-running**: `getMediaStream()` — captures shares when app is already open
- **Auth guard**: URLs starting with `com.example.wabway://` are ignored (auth callbacks)
- **Title extraction**: Google Maps URLs get a human-readable title from the `/maps/place/` path segment or `?q=` parameter; falls back to the raw URL truncated to 80 chars

## Content type detection (`share_data.dart`)

URL patterns matched: `maps.google.com`, `goo.gl/maps`, `maps.app.goo.gl`, `instagram.com`, `tiktok.com`/`vm.tiktok.com`, `youtube.com`/`youtu.be`, file extensions (`.pdf`, `.png`), and keyword heuristics for restaurants/receipts/screenshots.

## Destinations wired in `incoming_share_screen.dart`

| Destination | What happens |
|---|---|
| **Spot** | `SpotService.createSpot`; Maps URL → `maps_url` field, coordinates extracted if full URL |
| **Document** | File upload via `DocService.uploadAndCreate`; link-only text saved as URL doc |
| **Travel item** | `TravelService.createItem`; if file shared → uploads doc and links it via `DocService.addLink` |
| **Receipt** | `MoneyService.createReceipt` with single split at full amount; if image shared → uploads doc and links it |
| **Link** | Coming soon (awaiting #8 Links feature) |
| **Itinerary note** | Coming soon (needs day selection UI) |

## Files changed

| File | Change |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | Added `SEND_MULTIPLE image/*` intent filter |
| `lib/core/share/share_handler.dart` | Added `_niceTitle()` for Maps URL title extraction |
| `lib/screens/share/incoming_share_screen.dart` | Wired `travelItem` and `receipt` destinations; added `_travelItemType` and `_receiptCategory` converters |
