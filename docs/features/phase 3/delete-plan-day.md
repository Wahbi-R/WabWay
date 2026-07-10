# Delete Plan Day

**Build 97 · 2026-07-10**

## Problem

`PlanService.deleteDay()` existed in the service layer but was never surfaced in the UI. There was no way to remove a day from the itinerary except by going directly to the database.

## Solution

The pencil icon on each day card header is replaced with a `⋮` (`PopupMenuButton`) that offers two actions:

- **Edit day** — existing sheet (city, date, notes)
- **Delete day** — shows a confirmation dialog identifying the day by number and city, warns that all itinerary items will be deleted, and requires an explicit "Delete" press

On confirm, the day is removed optimistically from `_days` state and `PlanService.deleteDay(id)` is called in the background. On error, `_loadAll(silent: true)` restores the server state.

## Files changed

- `lib/screens/plan/day_card.dart`
  - Added `_DayMenuAction` enum (`edit`, `delete`)
  - `_DayHeader` — added `onDelete` callback; replaced `GestureDetector` pencil with `PopupMenuButton<_DayMenuAction>`
  - `TripDayCard` already had `onDeleteDay` parameter added in the prior session; it was wired to `_DayHeader`

- `lib/screens/plan_screen.dart`
  - Added `_deleteDay(TripDay day)` — shows `AlertDialog`, on confirm removes from `_days` and calls `PlanService.deleteDay`
  - Both desktop and mobile `TripDayCard` calls now pass `onDeleteDay: () => _deleteDay(_days[di])`

## No DB changes

`PlanService.deleteDay()` was already implemented and CASCADE-deletes itinerary items via the existing FK constraint.
