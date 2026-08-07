# Packing List: Progress Bar + Template Quick-Add (Build 120)

## What it does

Two quality-of-life additions to the shared packing list:

### Progress bar
A rounded `LinearProgressIndicator` sits between the search bar and the item list. It shows "X of Y packed" and turns green with an "All packed!" label when every item is checked off.

### Template quick-add
An "Add from template" entry appears in the AppBar overflow menu (⋮) and as an outlined button on the empty state. Tapping it opens a `DraggableScrollableSheet` with 6 travel categories:

| Category | Example items |
|---|---|
| Documents | Passport, Visa documents, Insurance card, Travel itinerary |
| Toiletries | Toothbrush & toothpaste, Shampoo & conditioner, Deodorant, Razor |
| Clothes | Underwear × 7, Socks × 7, T-shirts × 5, Comfortable walking shoes |
| Electronics | Phone charger, Power bank, Universal adapter, Earphones |
| Health & Meds | Prescription medications, Pain relievers, Sunscreen, Hand sanitiser |
| Comfort & Entertainment | Travel pillow, Eye mask, Earplugs, Book / e-reader |

Each category is expandable (collapsed by default). Items already on the list are filtered out so there are no duplicates. A badge on the category header counts how many items are selected. "Add N items" at the bottom adds them all and closes the sheet.

## Files changed
- `lib/screens/packing_screen.dart` — `_PackingProgress` widget, `_TemplateSheet` widget, `_addFromTemplate()` method, AppBar overflow menu restructured, `_EmptyState` gains `onTemplate` callback
