# Budget Tracking

**Build 66**

## What it does

Organizers can set a total trip budget (in the home currency) under Trip Settings. When a budget is set, the home screen shows a live progress bar below the balance card:

- Shows "X / Y" spent vs. budget in home currency
- Progress bar fills proportionally; turns red when over budget
- "X over budget" label shown when spending exceeds the budget
- Budget field is optional — leave empty and no bar is shown

## How it connects

- `supabase/migrations/013_trip_budget.sql` — adds `budget numeric(12,2)` column to `trips` (nullable)
- `lib/core/trip/app_trip.dart` — `budget` field added to `AppTrip` model; read from DB in `fromMap`
- `lib/core/supabase/trip_service.dart` — `updateTrip` now accepts `budget` and `clearBudget` parameters
- `lib/screens/trips/trip_settings_sheet.dart` — budget text field added below settlement currency; pre-filled with existing value; clears on empty save
- `lib/screens/home_screen.dart` — `_BudgetProgressBar` widget; shown below `_QuickBalanceCard` when `trip.budget != null`; uses `data.totalSpent` (sum of all home-currency receipt amounts)

## Files changed

- `supabase/migrations/013_trip_budget.sql` (new)
- `lib/core/trip/app_trip.dart` — `budget` field
- `lib/core/supabase/trip_service.dart` — budget save support
- `lib/screens/trips/trip_settings_sheet.dart` — budget text field
- `lib/screens/home_screen.dart` — `_BudgetProgressBar` widget + render
