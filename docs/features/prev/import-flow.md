# Import Flow

## Entry points

- **Home screen** — download icon (`Icons.download_rounded`) in the app bar
- **More screen** — "Import file or link" row under the Import section

Both call `showImportSheet(context)` from `lib/screens/import/import_sheet.dart`.

## Flow (2 steps)

### Step 1 — Source

User picks where the content is coming from:

- **Pick a file** — `FilePicker` (PDF, jpg, jpeg, png, docx, xlsx, webp, heic). File jumps straight to Step 2.
- **Add a photo** — `ImagePicker` via a camera/gallery sheet. Photo jumps straight to Step 2.
- **Paste a link** — URL text field + "Continue with link" button.

If the URL contains `google.com/maps`, `maps.app.goo.gl`, or `goo.gl/maps`, the Spot destination is auto-selected and the Maps URL field is pre-filled.

Title is auto-filled from the filename (extension stripped) or from the domain name of a URL.

### Step 2 — Details

**Source preview bar** shows the filename/extension/size or the URL.

**Destination chips** (single-select):

| Chip | Creates |
|---|---|
| Document | `documents` row (+ storage upload if file) |
| Spot | `spots` row via `SpotService.createSpot` |
| Travel | `travel_items` row via `TravelService.createItem` |
| Plan item | `itinerary_items` row via `PlanService.createItem` |
| Receipt | `receipts` row via `MoneyService.createReceipt` |

**Sub-form per destination:**

- **Document** — doc type chip grid (`DocType` enum)
- **Spot** — city field, optional Maps URL field, category chip grid, status chip grid
- **Travel** — type chip grid (`TravelItemType` enum)
- **Plan item** — day dropdown (loads from `PlanService.loadAll`), item type chip grid (`ItineraryItemType`)
- **Receipt** — amount + currency fields, category chip grid

All destinations share a **Title** field and an optional **Notes** field.

## Save logic

1. If a file or photo was picked → `DocService.uploadAndCreate` → returns `TripDocument`
2. Entity is created via the appropriate service
3. If a document was uploaded → `DocService.addLink` links it to the entity using the correct `DocLinkedType`

For receipts with no splits available at import time, a single split for the importing user at the full amount is created. Splits can be edited from receipt detail later.

For link-only Document imports (no file), a `documents` row is inserted directly with the URL stored in `notes`. No storage upload.

## Files

| File | Role |
|---|---|
| `lib/screens/import/import_sheet.dart` | Full import sheet — source picker, details step, submit logic |
| `lib/screens/home_screen.dart` | Import button added to app bar |
| `lib/screens/more_screen.dart` | Import row added under Import section |

## Constraints / out of scope

- No OCR, no automatic PDF parsing, no AI extraction
- No email inbox import
- All existing services reused (`DocService`, `SpotService`, `TravelService`, `PlanService`, `MoneyService`)
- Database schema unchanged
