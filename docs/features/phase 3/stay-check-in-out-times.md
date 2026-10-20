# Stay check-in / check-out times

**Build:** 426  
**Area:** Stays (Add/Edit Stay, Stays list), Spots, Map, connections, AI access

## What it does

Stays already had check-in and check-out **dates**. They now also hold the
hotel's **policy times**: the earliest you can check in and the latest you can
check out ("check-in from 15:00, check-out by 11:00"). Before this, the only
place to put them was the notes.

Transport already had times (Departs / Arrives, Pick-up / Return, Boarding),
so nothing changed there.

## How it looks and is used

- **Add / Edit Stay**: there's a second row under the Check-in / Check-out
  dates with two time fields, **Check-in from** and **Check-out by**. Both are
  optional and can be cleared with the ✕. They use the shared `WabwayTimeField`
  (24h picker). The picker opens at a typical hotel time, 15:00 for check-in
  and 11:00 for check-out, so most people only need to tap OK.
- **Stays list card**: the date line becomes
  `Nov 11, 15:00 → Nov 14, 11:00 (3 nights)`. When no time is set it stays
  `Nov 11 → Nov 14`.
- **Countdown line on the card**:
  - `Check-in tomorrow from 15:00` / `Check-in today from 15:00`
  - new: `Check-out today by 11:00` on the check-out day (this used to say
    "Staying now")
  - `Staying now` / `Check-in in N days` otherwise
- **Stay sheet on Spots**: under each date there's a small `from 15:00` /
  `by 11:00` caption. The dates now use the app's standard `Nov 11` format
  instead of `11/11/2026`.
- **Map stay sheet, linked-stay card on a spot, connection rows**: show
  `Nov 11, 15:00 – Nov 14, 11:00`.
- **CSV export**: new `Check-in time` and `Check-out time` columns.
- **AI access** (wabway-server): `add_stay` takes `check_in_time` /
  `check_out_time`, `update_item` can set or clear them, and `get_bookings`
  returns them.

## Design notes

- The times are kept **separate from the dates** (not merged into a
  timestamp), so nights, sorting by check-in and the date-range picker work
  exactly as before. A stay can have dates without times, or times without
  dates.
- The labels say "from" / "by" because these are the hotel's window, not an
  appointment. Your actual arrival time belongs in a plan item or the travel
  booking.

## Implementation

| Layer | Change |
|---|---|
| Supabase | Migration `051_stay_check_in_out_times.sql`: `accommodations.check_in_time`, `check_out_time` (`time`, nullable, same type as `travel_items.time`) |
| `lib/data/accommodation_data.dart` | `checkInTime` / `checkOutTime` ("HH:MM"), `checkInLabel` / `checkOutLabel`; `copyWith` can clear them (shared `_keep` sentinel, previously only for `spotId`) |
| `lib/core/supabase/accommodation_service.dart` | read/write the new columns |
| `lib/data/date_utils.dart` | new shared `fmtDateTime`, `parseTimeOfDay`, `hhmmFromDb`. These replace three private `_parseTime` copies (travel sheet, travel detail, plan item sheet) and the inline `substring(0, 5)` trims in the travel/plan services |
| `lib/widgets/wabway_date_field.dart` | `WabwayTimeField.initialPickerTime` (same idea as `WabwayDateField.initialPickerDate`) |
| Screens | add/edit stay sheet, stays list card + CSV, spots stay sheet, map stay sheet, spot linked-stay card, connections row; removed the local `_fmt` / `_fmtDate` date formatters in those files |
| wabway-server | `wabway_mcp.py`: `_STAY_COLS`, `add_stay`, `_UPDATABLE["stay"]`, `_CLEARABLE` |

Test: `test/stay_times_test.dart` (helpers, labels, copyWith clearing, and the
edit form rendering both times).
