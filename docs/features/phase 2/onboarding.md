# Onboarding

## Description

A 5-page onboarding dialog shown to first-time users on the Home screen. Covers the app's core features. Completion is tracked in `SharedPreferences` so the dialog only appears once per install.

## Key Files

- `lib/screens/onboarding_screen.dart` — `_OnboardingDialog`, `showOnboardingIfNeeded()`, `hasSeenOnboarding()`, `markOnboardingSeen()`
- `lib/screens/home_screen.dart` — calls `showOnboardingIfNeeded(context)` in `initState`

## How It Works

1. On `home_screen.dart` `initState`, `showOnboardingIfNeeded(context)` checks `SharedPreferences` for the key `onboarding_v1_shown`.
2. If not set, `showDialog<void>` presents `_OnboardingDialog` with `barrierDismissible: false`.
3. The dialog is a full-width `PageView` with 5 pages, dot indicators, and Skip/Next buttons. The last page's Next becomes "Get started".
4. On dismiss (Skip or Get started), `markOnboardingSeen()` sets `onboarding_v1_shown = true`.

**Onboarding pages:**
1. Welcome to WabWay
2. Discover & vote on Spots
3. Build your itinerary
4. Split expenses fairly
5. Keep documents together

## Setup

No setup needed. To re-trigger onboarding during development, clear the app's SharedPreferences or delete the `onboarding_v1_shown` key.
