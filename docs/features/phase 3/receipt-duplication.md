# Receipt Duplication (Build 78)

## Summary

A "Duplicate" option now appears in the receipt detail screen's overflow menu. Tapping it opens the Add Receipt form pre-filled with all the existing receipt's values (title, amount, category, currency, payer, splits, notes) but with no ID — so saving creates a brand new receipt. The date defaults to today, and linked documents are not carried over.

This is useful when logging repeated expenses: daily transport, recurring restaurant visits, or any pattern where a quick duplicate + amount tweak is faster than filling in the whole form.

## What changed

- **`lib/screens/money/add_receipt_sheet.dart`** — added `isDuplicate` param to `showAddReceiptSheet`, `_AddReceiptSheet`, and `_AddReceiptContent`; `_isEditing` now returns `false` when `isDuplicate`; linked docs not loaded on duplicate; title/button label updated to "Duplicate receipt" / "Save as new".
- **`lib/screens/money/receipt_detail.dart`** — added `_duplicateReceipt()` method; overflow `PopupMenuButton` with "Duplicate" option added to AppBar.
