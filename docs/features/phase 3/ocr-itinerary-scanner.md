# OCR / Itinerary Scanner

## Overview
WabWay can parse travel itineraries from shared files (PDF, images) and auto-populate trip plan items. Two modes are supported: local OCR (on-device) and AI parsing (Gemini).

## Entry Points
- **Import sheet** (`ImportSheet`) — shown from the share intake screen when a PDF or image is shared
- **Inline share flow** — `IncomingShareScreen` detects scannable file types and routes to the import sheet

## Scannable File Types
Determined by `_isScannable(String ext)` in the import sheet: `.pdf`, `.png`, `.jpg`, `.jpeg`, `.heic`, `.webp`, `.tif`, `.tiff`.

## OCR Service (`lib/core/ocr/ocr_service.dart`)
- Uses `google_mlkit_text_recognition` for on-device OCR
- Two-pass strategy: first pass at original resolution, second pass with enhanced contrast if the first pass yields < 100 characters
- Returns raw text for the parser

## PDF Reader (`lib/core/ocr/pdf_reader.dart`)
- Uses `syncfusion_flutter_pdf` to extract text directly from PDF text layers
- Falls back to OCR if the PDF has no selectable text (scanned documents)

## Itinerary Parser (`lib/core/ocr/itinerary_scanner.dart`)
- Two parsing modes:
  - **Local regex** — pattern-matches dates, times, flight codes, hotel names, activity descriptions from raw OCR text
  - **Gemini AI** — sends text to `gemini-1.5-flash` with a structured prompt; returns JSON array of plan items
- Gemini is used when the document is multi-column or when local regex yields < 3 items
- Model: `gemini-1.5-flash` via REST API with `application/json` MIME type
- Handles 2-column Gmail booking format (common for flight/hotel confirmation emails)

## Parse Result
Each parsed item maps to a `ParsedItineraryItem` with:
- `date`, `time`, `type` (flight/hotel/activity/transport)
- `title`, `description`, `location`
- `confidence` score

## UI: `ParsedItineraryScreen`
- Shows parsed items as editable cards before committing to the trip plan
- Displays mode badge: "AI" (Gemini) or "OCR" (local) 
- User can edit, reorder, and deselect items before saving

## Supabase requirements
None for parsing — items are written to the existing `plan_items` table on confirm.
