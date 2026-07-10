# Currency Converter

**Build 62**

## What it does

A quick offline currency converter accessible from the Money screen's app bar (exchange icon). Tap it to open a bottom sheet where you can:

- Select from any currency already seen in your logged receipts
- Type an amount in that currency
- See the equivalent in the trip's home currency instantly
- View the exact rate used ("1 JPY = 0.0091 CAD")

No network call is needed — all rates come from the `exchange_rate` values stored on existing receipts at the time they were logged. This makes it fully offline-capable while travelling.

When no foreign receipts exist yet, the sheet shows an informational note explaining how rates appear automatically once you log a receipt in a foreign currency.

## How it connects

- `lib/screens/money/currency_converter_sheet.dart` — new stateful bottom sheet; builds a rate map from `Receipt.exchangeRate` values; converts via `input × rate`
- `lib/screens/money_screen.dart` — `currency_exchange_rounded` icon button added to app bar actions; passes `_homeCurrency` and `_receipts` to the sheet
- Uses `kColorWarning` for the empty-state hint (consistent with other info banners)
- No new tables, no new packages, no migrations

## Files changed

- `lib/screens/money/currency_converter_sheet.dart` (new)
- `lib/screens/money_screen.dart` — import + app bar icon button
