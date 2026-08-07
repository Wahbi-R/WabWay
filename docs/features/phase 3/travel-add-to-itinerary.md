# Travel: Add to Itinerary (Build 131)

## What it does

Tapping **"Add to itinerary"** on any travel item detail screen opens the day picker sheet. The user selects a trip day and an optional time, and the travel item is added to that day's plan as a new itinerary item.

## Type mapping

| Travel item type | Itinerary item type |
|---|---|
| Flight | Travel |
| Train | Transport |
| Ticket | Activity |
| Hotel / Reservation / Other | Other |

## Implementation

- `_ActionsSection` in `lib/screens/travel/travel_item_detail.dart` was converted from `StatelessWidget` to `StatefulWidget` to manage `_itineraryLoading` state.
- `days` is now threaded from `TravelItemDetailContent` → `_ActionsSection`.
- `_addToItinerary()` calls `showDayPickerSheet(context, days: widget.days)`, then `PlanService.createItem(...)` with the travel item's title, mapped type, time, and location.
- The button label switches to "Adding…" while the request is in flight to prevent double-taps.
- Success: green snackbar naming the day (e.g. "Added to Day 3 · Kyoto").
- Error: red snackbar with the exception message.
- If `days` is empty, shows "Add trip days in Plan first." without opening the picker.

## Files changed

- `lib/screens/travel/travel_item_detail.dart` — `_ActionsSection` refactored to StatefulWidget; new imports for `plan_service`, `trip_state`, `client`, `day_picker_sheet`
