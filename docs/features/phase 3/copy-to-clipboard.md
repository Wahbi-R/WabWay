# Copy to Clipboard — Spot Address & Confirmation Number

**Build 60**

## What it does

Two on-the-go copy shortcuts were added for when you need to hand info off to another app quickly:

### Spot address
In the spot detail sheet, tapping the address row copies the full address to clipboard and shows a "Copied" snackbar. A small copy icon is shown alongside the address text to signal it's tappable.

### Travel confirmation number & address
In the travel item detail screen, the Confirmation row and Address row show a small copy icon and copy the value on tap. These are the fields most likely to be pasted into airline check-in apps, maps, or emails while travelling.

## How it connects

- `lib/screens/spots/spot_detail.dart` — address `Text` wrapped in `GestureDetector`; copy icon shown inline
- `lib/screens/travel/travel_item_detail.dart` — `_MetaRow` now accepts `copyable: bool`; when true, wraps the row in a `GestureDetector` and shows a `Icons.copy_rounded` icon trailing the value; set to `true` for `'Confirmation'` and `'Address'` labels
- Uses `package:flutter/services.dart` `Clipboard.setData` — no new package dependencies
- `context.mounted` guard before showing `ScaffoldMessenger` (async-safe)

## Files changed

- `lib/screens/spots/spot_detail.dart` — address row copy action
- `lib/screens/travel/travel_item_detail.dart` — `_MetaRow.copyable` + `services.dart` import
