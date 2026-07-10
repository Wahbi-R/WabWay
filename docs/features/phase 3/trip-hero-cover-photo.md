# Trip Hero — Cover Photo Banner

**Build 67**

## What it does

When a trip has a cover photo set (via Trip Settings), the home screen's trip hero card now shows it as a full-width 120px banner at the top of the card. The cover photo was already uploadable and stored, but was only shown in the trip switcher sheet — now it's prominently displayed on the home screen.

- Smooth 300ms fade-in as the image loads from CDN
- A gradient overlay on the bottom of the image ensures readability
- The edit (pen) icon moves into the top-right of the cover photo area when a cover exists
- Falls back gracefully if the image URL fails to load

## How it connects

- `lib/screens/home_screen.dart` — `_TripHero` now reads `trip.coverImageUrl`; wraps the card in a `ClipRRect` for clean corners; adds a `SizedBox(height: 120)` image section with `Image.network`, gradient overlay, and the edit icon repositioned into the image

## Files changed

- `lib/screens/home_screen.dart` — `_TripHero` cover photo section
