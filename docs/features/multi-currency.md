# Multi-Currency Settle-Up

## Description

When a trip has receipts or withdrawals in more than one currency, balances and settlement suggestions are grouped per currency rather than summed across currencies (which would produce meaningless mixed-unit totals).

## Key Files

- `lib/data/money_data.dart` — `calculateBalancesGrouped()`, `SettlementSuggestion` (carries `currency` field)
- `lib/screens/money_screen.dart` — `SettleUpPanel` renders per-currency sections

## How It Works

`calculateBalancesGrouped(receipts, withdrawals)` returns `Map<String, List<MemberBalance>>` — one entry per currency found in the data. Each currency's balances are computed independently using only the receipts/withdrawals denominated in that currency.

`SettleUpPanel` iterates the map. If the map has exactly one currency it renders identically to the single-currency layout. With two or more currencies it renders a separate balance card per currency, each with a currency badge (e.g. "JPY") and its own suggested-payments list.

`SettlementSuggestion` stores a `currency` field so that when the user marks a suggestion as paid, `SettlementService.createSettlement()` records the correct currency on the `settlements` row.

## Notes

The `fmtAmount(amount, currency)` helper in `money_data.dart` formats amounts with the appropriate symbol (¥, $, €) or falls back to `CURRENCY amount`.
