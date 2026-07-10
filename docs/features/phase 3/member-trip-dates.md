# Member Trip Dates (Build 75)

## Summary

Members can now set personal arrival and departure dates for a trip — useful when not everyone travels together the whole time. Dates are visible on every member's card so the whole group knows when each person is joining and leaving.

## What changed

### Database
- **Migration 017** — `arrival_date date` and `departure_date date` columns added to `trip_members` with `ADD COLUMN IF NOT EXISTS`.

### Data layer
- **`AppTripMember`** — new `arrivalDate`, `departureDate` (nullable `DateTime`) fields; `hasDates` convenience getter; `fromMap` parses both new columns.
- **`TripService.loadTripMembers`** — select now includes `arrival_date, departure_date`.
- **`TripService.updateMemberDates`** — new method; handles `null` (clear) vs value update for each date independently.

### UI — Members screen
- Each **member card** shows arrival/departure icons and formatted dates below the email line when at least one date is set.
- The **current user's card** shows an "Edit" link (when dates are set) or an "Add dates" prompt (when not).
- Tapping either opens **`_MemberDatesSheet`** — a bottom sheet with two `_DateRow` pickers for arrival and departure. Departure is clamped to never precede arrival.
- On save, `TripState.refresh(context)` reloads all members.

## Files modified

- `supabase/migrations/017_member_trip_dates.sql` (new)
- `lib/core/trip/app_trip_member.dart`
- `lib/core/supabase/trip_service.dart`
- `lib/screens/members_screen.dart`
