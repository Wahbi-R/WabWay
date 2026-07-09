# Multi-currency receipts

**Status:** Shipped (build 24, 2026-07-09)  
**Migration:** `supabase/migrations/007_multi_currency_receipts.sql`

---

## Problem

When travelling abroad (e.g. Japan) the group pays in JPY but everyone ultimately settles in their home currency (CAD). If exchange rates shift between the time of purchase and settlement, the "who owes what" calculation becomes ambiguous. We needed a way to lock in the conversion at purchase time.

---

## Solution

- A `home_currency` column is added to `trips` (default `CAD`, user-configurable in Trip Settings → Settlement currency).
- When adding a receipt in a foreign currency, the app auto-fetches the exchange rate for that date from the [Frankfurter API](https://api.frankfurter.app) (free, ECB-backed, no API key, historical rates).
- `home_amount = amount × exchange_rate × (1 + transaction_fee_pct / 100)` is computed once and stored. It is never recalculated.
- An optional **transaction fee** field (default 0%) captures card surcharges.
- Existing receipts are backfilled with `home_amount = amount` and `exchange_rate = 1` — they show a nudge in the UI until manually updated.

---

## New DB columns

| Table | Column | Type | Notes |
|---|---|---|---|
| `trips` | `home_currency` | `text NOT NULL DEFAULT 'CAD'` | 3-letter ISO code; constrained by `CHECK (home_currency ~ '^[A-Z]{3}$')` |
| `receipts` | `home_amount` | `numeric(12,2) NOT NULL` | Locked at creation time |
| `receipts` | `exchange_rate` | `numeric(16,8) NOT NULL` | Rate used to compute `home_amount` |
| `receipts` | `transaction_fee_pct` | `numeric(5,2) NOT NULL DEFAULT 0` | e.g. 2.5 for 2.5% fee |

---

## Files changed

| File | Change |
|---|---|
| `supabase/migrations/007_multi_currency_receipts.sql` | Migration adding columns |
| `lib/core/supabase/exchange_rate_service.dart` | New — Frankfurter API client (5s timeout, null on error) |
| `lib/core/trip/app_trip.dart` | Added `homeCurrency` field |
| `lib/data/money_data.dart` | Added `homeAmount`, `exchangeRate`, `transactionFeePct` to `Receipt`; `isForeignCurrency` getter; `fmtAmount` handles CAD, GBP, AUD, JPY, KRW, IDR, VND |
| `lib/core/supabase/money_service.dart` | Reads/writes new fields in `createReceipt`, `updateReceipt`, `_receiptFromRow` |
| `lib/core/supabase/trip_service.dart` | `updateTrip` accepts `homeCurrency` |
| `lib/screens/trips/trip_settings_sheet.dart` | Settlement currency dropdown (shares `_CurrencyDropdown` with default currency picker) |
| `lib/screens/money/add_receipt_sheet.dart` | `_ConversionSection` — rate field + refresh button + fee toggle + home amount display/override |
| `lib/screens/money/receipt_list_tile.dart` | Shows `≈ C$89.43` when `receipt.isForeignCurrency` |
| `lib/screens/money_screen.dart` | Passes `homeCurrency` to tile and add-receipt sheet |
| `lib/core/sync_queue.dart` | Offline receipt drain supplies default `homeAmount`/`exchangeRate`/`transactionFeePct` |
| `lib/screens/share/incoming_share_screen.dart` | Receipt creation from share flow supplies defaults |
| `lib/widgets/wabway_text_field.dart` | Added `inputFormatters` parameter (used by rate/fee fields) |

---

## Key design decisions

- **Lock rate at purchase time.** `home_amount` is written once and treated as immutable. If the user's bank charged a slightly different rate, they can tap "Override" to set the actual amount.
- **Two currency concepts on a trip:** `default_currency` (local trip currency, pre-fills the receipt form) vs `home_currency` (settlement currency, what the balance is shown in).
- **Frankfurter API** — free, ECB-backed, historical rates, no API key required. Falls back to `null` on any error; user can type the rate manually.
- **Old receipts** — backfilled with `exchange_rate = 1`, so `home_amount = amount`. The app recognises these (`exchangeRate == 1.0` with a different currency code) and nudges users to update.
