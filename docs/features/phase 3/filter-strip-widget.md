# WabwayFilterStrip Generic Widget

**Build 56**

## Problem

Three screens (Accommodations, Receipts/Money, Links) each had their own private `_FilterStrip` / `_ReceiptFilterStrip` / `_LinkFilterStrip` class, all implementing the same `SizedBox(height:52) + horizontal ListView + WabwayTag` pattern with identical logic for:
- An "All (N)" chip
- Per-value chips with counts
- Auto-hiding when fewer than 2 options are present
- Toggle-off when tapping the already-selected chip

## Solution

Created `lib/widgets/wabway_filter_strip.dart` with a generic `WabwayFilterStrip<T>` widget.

### API

```dart
WabwayFilterStrip<AccommodationStatus>(
  selected: _filterStatus,
  options: AccommodationStatus.values.map((s) => (
    value: s,
    label: s.label,
    count: _count(s),
  )).toList(),
  allCount: _count(null),
  autoHide: false,              // default true — hides when < 2 options
  onChanged: (s) => setState(() => _filterStatus = s),
)
```

Each entry in `options` is a named record `({T value, String label, int count})`.

## Files changed

- `lib/widgets/wabway_filter_strip.dart` — new widget
- `lib/widgets/widgets.dart` — re-exports the widget
- `lib/screens/accommodations/accommodations_screen.dart` — removed `_FilterStrip`
- `lib/screens/money_screen.dart` — removed `_ReceiptFilterStrip`, added `_receiptFilterStrip()` method
- `lib/screens/links_screen.dart` — removed `_LinkFilterStrip`

## What's NOT migrated

- `travel_screen.dart`'s `_FilterChips` — uses custom colored chips with icons, not `WabwayTag`; semantically different
- `docs_screen.dart`'s `_FilterStrip` — desktop panel with border, scroll controller, no counts; different design context
- `spots_screen.dart`'s `_CategoryFilterStrip` — stateful with a full filter sheet
