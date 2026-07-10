# Receipt Date Range Filter

**Build 93 · 2026-07-10**

## Problem

The receipts list had a category filter and search but no way to view expenses for a specific date range — e.g., "what did we spend on day 2 of the trip" or "just show me expenses from this weekend."

## Solution

A date range chip sits to the right of the category filter strip (both desktop and mobile). Tapping it opens Flutter's built-in `showDateRangePicker`, bounded to the earliest/latest receipt dates. When a range is active:

- The chip shows `"Jan 5 – Jan 12"` in primary color with a clear `×` button
- `_filteredReceipts` gates each receipt: `day.isBefore(start) || day.isAfter(end)` → excluded
- The empty state message is updated: "No receipts in that date range / Try a wider date range or clear the filter."
- The `×` on the chip clears the range without reopening the picker

The date range filter composes with the existing category filter and search — all three apply simultaneously via `_filteredReceipts`.

## Files changed

- `lib/screens/money_screen.dart`
  - Added `DateTimeRange? _dateRange` state field
  - Added `_pickDateRange()` — opens `showDateRangePicker` themed with `kColorPrimary`
  - Added `_dateRangeChip()` — animated chip widget; renders inline clear button when active
  - Updated `_filteredReceipts` — date range check added alongside category + search
  - Desktop: chip inserted in the filter row (between category strip and sort button)
  - Mobile: chip inserted in a new `Row` wrapping the filter strip

## No DB changes
All filtering is client-side on the already-loaded `_receipts` list.
