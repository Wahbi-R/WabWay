# Import uses the real Add sheets

## Problem
Import (`lib/screens/share/`) re-implemented every entity form in `share_form.dart`
plus an inline plan-item form. The copies drifted: different category lists
(mapped back with lossy `switch`es), travel saved with no from/to, documents
silently dropped the URL, spots saved with `city: 'Unknown'`. Titles were just
the hostname — no page metadata was read.

## Design
- Import keeps what is genuinely Import-specific: source picking, content-type
  detection, the destination picker and the smart extractors (Find places,
  Maps list, CSV, AI itinerary).
- Choosing a destination → **Continue** opens that entity's ONE Add sheet with an
  `ImportPrefill` (`lib/data/share_data.dart`). Every Add sheet accepts
  `prefill:`; it only fills fields for a *new* item and never flips edit mode.
- Draft-returning sheets are persisted through `TravelService.createFromDraft` /
  `PlanService.createItemFromDraft` — the same mapping the Travel/Plan screens use.
- Files for travel/plan items are uploaded as documents first so the sheet's
  `DocMultiPicker` shows them pre-selected; cancelled → the doc is deleted.
- Link metadata: wabway-server `POST /url/meta` (server-side, so it works on web)
  → `UrlMetadataService.fetch`. Reads OpenGraph and the best schema.org JSON-LD
  object (reservations, lodging, events, products). `ListingParser` builds on it.

## Place picker everywhere
`PlaceSearchField` is the only location input: spot name + address, plan item
location, add/edit day city, travel from/to/location (`querySuffix` = airport /
station / port by type), stays city.

## Not done / follow-ups
- Documents still have no URL column (URL is kept in notes) — Library merge (5b).
- No IATA dataset; airport search relies on Google Places with the "airport" bias.
