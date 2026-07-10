# Settings Screen — Trip Section Fix

**Build 55**

## Problem

The TRIP section of the Settings screen showed a "Coming soon" placeholder despite trip settings, invite codes, and member management all being fully implemented.

## Solution

Replaced the placeholder with two tappable tiles:
- **Trip settings** → opens `showTripSettingsSheet` (name, dates, home currency, etc.)
- **Invite members** → opens `showInviteSheet` (generates invite codes, shows member list)

Also removed the dead `PlaceholderScreen` class from `placeholder_screen.dart` — it was never instantiated anywhere in the app.

## Files changed

- `lib/screens/placeholder_screen.dart` — removed `PlaceholderScreen` class; added trip tiles to `SettingsScreen`
