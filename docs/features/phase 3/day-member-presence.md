# Day Member Presence Indicator (Build 76)

## Summary

Each itinerary day card now shows which members are present on that day, based on the arrival/departure dates set in the Members screen (build 75). This lets the group instantly see when someone is joining late or leaving early — and avoids planning activities for the full group on days when part of the crew isn't there yet.

## Behaviour

- **Hidden by default** — the row only appears when at least one member has travel dates configured. If everyone leaves arrival/departure blank, plan screen is unchanged.
- **All present** — if everyone with dates is present on this day, the row is also hidden (no noise when the whole group is together).
- **Partial group** — when one or more members aren't there, a compact avatar row appears below the day header with present members in accent colour and absent members greyed out, followed by text like "Alex not here" or "2 members not here".
- Avatars are 18px initials circles, sized to not compete with the item count badge.

## What changed

- **`lib/screens/plan/day_card.dart`** — added imports for `TripState` and `AppTripMember`; inserted `_MemberPresenceRow` widget into `_DayHeader`; added `_TinyAvatar` helper widget.

## No migration required

All data (arrival_date, departure_date) comes from migration 017 / build 75.
