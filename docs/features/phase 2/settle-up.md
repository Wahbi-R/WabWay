# Settle Up

## Description

A settlements panel in the Money screen that suggests the minimum number of transfers to balance the group, lets members mark suggestions as paid (persisting to Supabase), and shows settlement history with Realtime updates.

## Key Files

- `lib/core/supabase/settlement_service.dart` — `loadSettlements()`, `createSettlement()`, `deleteSettlement()`
- `lib/data/money_data.dart` — `Settlement`, `SettlementSuggestion`, `suggestSettlements()`, `calculateBalancesGrouped()`
- `lib/screens/money_screen.dart` — `SettleUpPanel` widget
- `supabase/migrations/003_rls_fixes_and_settlements.sql` — `settlements` table + RLS

## How It Works

1. `calculateBalancesGrouped()` groups balances by currency, computing net amounts each member owes or is owed.
2. `suggestSettlements(balances, currency)` converts balances into concrete payment suggestions (who pays whom how much). Suggestions with `amount < 0.50` are filtered out.
3. Tapping "Mark as paid" on a suggestion calls `SettlementService.createSettlement()`, inserting a row into `settlements`. The suggestion is then marked `isSettled = true` in local state and crossed out.
4. Settlement history is loaded via `loadSettlements()` ordered newest-first.
5. In multi-currency trips, the `SettleUpPanel` renders separate balance cards per currency (see `multi-currency.md`).

## Setup

Migration `003_rls_fixes_and_settlements.sql` creates the `settlements` table with RLS. Members can read all settlements for their trip; only the `settled_by` user can delete their own.
