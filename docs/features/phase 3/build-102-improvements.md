# Build 102 — Feature improvements

## Add to Plan from Spot Detail

A new **Add to Plan** button appears on every spot detail screen. Tapping it:
1. Lazily loads the trip's itinerary days from Supabase.
2. Opens the shared day picker sheet (select day + optional time).
3. Creates a linked itinerary item directly — no extra form required.
4. Shows a green success snackbar confirming which day the spot was added to.

If no days exist yet, a friendly snackbar prompts the user to add days in Plan first.

**Files:** `lib/screens/spots/spot_detail.dart`, `lib/screens/plan/day_picker_sheet.dart`

---

## Day Picker Sheet — extracted to shared file

`_DayPickerSheet` was a private widget inside `plan_screen.dart`. It is now a public
`showDayPickerSheet()` function in `lib/screens/plan/day_picker_sheet.dart`, importable
by any screen that needs to let the user pick a trip day.

`plan_screen.dart` now imports and uses this shared widget; the private copy was removed.

---

## Plan Screen — offline banner

When a silent realtime reload fails, `plan_screen.dart` now sets `_offline = true` and
shows the same `OfflineBanner` (with Retry) that Money, Travel, and other screens already
use. Consistent with the rest of the app.

---

## Crew Chat — accessible from mobile Home and More

**Home screen:** A chat icon (`Icons.chat_rounded`) was added to the AppBar, giving quick
access to `CrewScreen` without going to More.

**More screen:** Crew Chat was moved out of the generic "Explore" list and promoted to its
own prominent card (same style as the Trip Switcher) directly below the trip header — the
first thing users see after the trip card.

---

## Travel — Hotel → Stays prompt

After successfully saving a `TravelItemType.hotel` booking, a 6-second snackbar appears:
> "Hotel added — save to Stays too? [Save]"

Tapping **Save** calls `AccommodationService.create` with the hotel name, check-in, and
check-out dates pre-filled and status `booked`. A confirmation snackbar follows.
No sheet is opened; it's a single tap.

**Files:** `lib/screens/travel_screen.dart`
