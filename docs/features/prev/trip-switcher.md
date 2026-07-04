# Multi-trip Switcher

## What it does

Users can belong to multiple trips. Previously `trip_gate.dart` always loaded `trips.first`. Now the full trip list is loaded and the user can switch between trips without logging out.

## Entry points

- **Desktop (sidebar):** The sidebar header showing the trip name is now tappable. A `unfold_more` chevron appears when there's more than one trip.
- **Mobile (More tab):** A "Tap to switch trip" row at the top of the More screen opens the switcher.

## Switcher sheet

- Lists all trips the user is a member of with trip name, destination, and an active-trip checkmark
- Tapping an inactive trip loads that trip's members and re-renders the full app under the new `TripState`
- "Create trip" button → `CreateTripScreen`
- "Join trip" button → `JoinWithCodeSheet`

## Implementation

`TripState` gained:
- `allTrips: List<AppTrip>` — full list from `TripService.loadUserTrips()`
- `onSwitchTrip: void Function(AppTrip)?` — callback up to `TripGate`
- `TripState.allTripsOf(context)` and `TripState.switchTrip(context, trip)` static helpers

`_TripGateState` tracks `_selectedIndex`. `_switchTrip(AppTrip)` calls `TripService.loadTripMembers` for the new trip and rebuilds. Selection index is preserved after `_load()` refreshes the trip list.

`JoinWithCodeSheet` was made public (renamed from `_JoinWithCodeSheet`) so the switcher can instantiate it without duplicating the form.

## Files

| File | Change |
|---|---|
| `lib/core/trip/trip_state.dart` | `allTrips`, `onSwitchTrip`, `allTripsOf`, `switchTrip` added |
| `lib/screens/trips/trip_gate.dart` | `_selectedIndex`, `_switchTrip`; `JoinWithCodeSheet` made public; `TripState` passes `allTrips` and `onSwitchTrip` |
| `lib/screens/trips/trip_switcher_sheet.dart` | New — `showTripSwitcherSheet`, `_TripSwitcherSheet` widget |
| `lib/shell/app_shell.dart` | `_SidebarHeader` tappable; shows `unfold_more` icon when multi-trip |
| `lib/screens/more_screen.dart` | Trip-switcher row added at top of More screen |
