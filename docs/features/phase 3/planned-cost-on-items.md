# Planned Cost on Itinerary Items

**Build 99 · 2026-07-11**

## Problem

There was no way to record how much an activity, transport, or meal was expected to cost. Users were keeping this in notes or a separate spreadsheet. Day budget totals were impossible to see in-app.

## Solution

Every itinerary item can now have an optional **estimated cost** (amount + currency). The currency defaults to the trip's `defaultCurrency` (the in-destination currency, e.g. JPY) but can be changed per item from a common list (JPY, USD, EUR, CAD, GBP, AUD, KRW, THB, SGD, HKD, CNY).

- **Item tile** — cost shown as a compact `JPY 1500` chip next to link badges, hidden when done
- **Day card footer** — `Est. JPY 8,200` running total appears below the item list when any item has a cost; costs are grouped by currency (mixed-currency days show `JPY 3000 + USD 40`)
- **Add/edit sheet** — new "Estimated cost" row with a numeric field and tappable currency selector

## Files changed

- `supabase/migrations/019_itinerary_planned_cost.sql` — adds `planned_cost NUMERIC` and `currency TEXT` to `itinerary_items`
- `lib/data/plan_data.dart` — `ItineraryItem` gains `plannedCost` and `currency` fields; `copyWith` updated
- `lib/core/supabase/plan_service.dart` — `_itemFromRow`, `createItem`, `updateItem` all handle the new fields
- `lib/screens/plan/add_item_sheet.dart` — `_CostField` widget; `defaultCurrency` passed from `showAddItemSheet` via `TripState.tripOf(context).defaultCurrency`
- `lib/screens/plan/item_tile.dart` — `_CostChip` widget shown in title row
- `lib/screens/plan/day_card.dart` — `_DayCostFooter` widget shown in both reorderable and non-reorderable item lists

## DB migration

```sql
ALTER TABLE itinerary_items
  ADD COLUMN IF NOT EXISTS planned_cost NUMERIC,
  ADD COLUMN IF NOT EXISTS currency     TEXT;
```

Applied via `supabase db push`.
