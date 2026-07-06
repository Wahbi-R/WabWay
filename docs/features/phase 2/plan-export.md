# Plan Export

## Description

The Plan screen offers two export options accessible from the AppBar (mobile) and desktop top bar:

1. **Text export** — generates a plain-text itinerary and shares it via `share_plus`.
2. **Calendar export** — generates a `.ics` (iCalendar) file and shares it so users can import into any calendar app.

## Key Files

- `lib/screens/plan_screen.dart` — `_exportAsText()`, `_exportToCalendar()` methods; export icons in AppBar
- `pubspec.yaml` — `share_plus` dependency

## How It Works

**Text export** (`_exportAsText()`):
- Iterates `_days` in order. For each day: prints a header (`Day N — City — Date`), then timed items sorted by time, then untimed items. Notes are included if present.
- Calls `Share.share(text)` to open the OS share sheet.

**Calendar export** (`_exportToCalendar()`):
- Generates a VCALENDAR string with one VEVENT per `ItineraryItem`. Date-only items become all-day events; items with a time get a datetime `DTSTART`. Location and notes are mapped to `LOCATION` and `DESCRIPTION`.
- Written to `Directory.systemTemp` as `wabway_itinerary.ics` and shared via `Share.shareXFiles([XFile(path)], mimeType: 'text/calendar')`.
- Web guard: shows a snackbar ("Calendar export not supported on web") if `kIsWeb`.

## Setup

No additional setup. `share_plus` and `dart:io` are already available.
