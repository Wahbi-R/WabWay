# Receipt Search (Build 81)

## Summary

A search bar now appears in the Receipts tab above the category filter strip, on both mobile and desktop. Typing searches receipt titles, categories, and notes in real time. The search composes with the category filter and sort order — e.g., you can search "taxi" while the "Transport" category filter is active and sorted by highest amount.

The empty state adapts: a search with no results shows "No results for 'X'" with a distinct icon, while a category filter with no results shows the existing "No X receipts" message.

## What changed

- **`lib/screens/money_screen.dart`**
  - Added `_receiptSearch = ''` string state and `_searchCtrl` TextEditingController
  - Added `_searchCtrl.dispose()` in `dispose()`
  - Updated `_filteredReceipts` to apply the search query (title, category label, notes) before sorting
  - Added `WabwaySearchBar` widget above `_receiptFilterStrip()` in both the mobile tab and desktop list panel
  - Empty-state messages and icons are now context-aware (search vs. category filter)
