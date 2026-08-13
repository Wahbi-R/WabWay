# Receipt scan & item-level split (Build 197)

## What it does

After attaching a photo to a receipt in the Add Receipt sheet, a **"Scan receipt & split items"** button appears below the photo zone. Tapping it:

1. Sends the photo to the existing AI OCR endpoint (`POST https://audio.wabble.ca/receipt/scan`) — the same one used by the standalone Receipts website.
2. Shows an **item split sheet** listing every line item on the receipt.
3. For each item, you tap avatar chips to toggle who had it (all members selected by default).
4. Tapping **Apply splits** closes the sheet and pre-fills:
   - The **amount** field with the scan total (in the selected local currency)
   - The **custom split** amounts with each person's proportional share (tax/tip distributed proportionally; stored in home currency)
5. The split mode switches to Custom automatically — amounts are still fully editable.

## Fallback

If the scan endpoint is unavailable (server down, travelling with no signal, timeout after 35 s), a snackbar shows "Scan unavailable — fill in manually" and the form stays exactly as before. Nothing breaks.

## Currency handling

The scan returns raw amounts in whatever currency is on the receipt. The user picks the currency in the form as usual. If conversion is needed, the existing exchange rate flow applies the rate/fee to produce home-currency split amounts — the scan just supplies the proportions.

## Files changed

| File | Change |
|---|---|
| `lib/core/receipt_scan_service.dart` | New — calls `/receipt/scan`, returns `ReceiptScanResult` or null |
| `lib/screens/money/add_receipt_sheet.dart` | `_ScanItemsButton`, `_ItemSplitSheet` widgets; `_scanAndSplit()` method; `_scanning`/`_scanResult` state |
