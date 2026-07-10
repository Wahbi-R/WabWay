# Quick Expense FAB

**Build 61**

## What it does

A floating action button (FAB) on the home screen opens the Add Receipt sheet directly. This cuts the tap count from 4 (More → Money → Receipts → +) down to 1, which is especially useful while actively spending during travel.

- FAB shows in the bottom-right corner on the home screen only
- Opens the full `AddReceiptSheet` pre-wired with the current trip, user, and members
- After dismissing the sheet, the home screen refreshes to reflect the new expense

## How it connects

- `lib/screens/home_screen.dart` — `floatingActionButton` added to the main Scaffold; imports `add_receipt_sheet.dart`
- `showAddReceiptSheet` called with `tripId`, `userId`, members from `TripState`, and `homeCurrency` from `_HomeData`
- Members are mapped from `AppTripMember` → `TripMember` inline (same conversion already done in `_load`)
- `_refresh()` called after the sheet closes to update the balance card immediately

## Files changed

- `lib/screens/home_screen.dart` — import + `floatingActionButton`
