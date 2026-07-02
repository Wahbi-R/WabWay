# Wabway Pre-Backend Review

> **Scope:** Full read-only audit of `lib/` after Spots, Money, Documents, Plan, and placeholder Travel/Links/Map/Settings screens are implemented.  
> **Goal:** Identify everything that should be cleaned up before Supabase integration begins.

---

## Summary

The UI is well-structured and the design system is consistent. The main risks before backend integration are:

1. **Member identity is split** — Money uses lowercase IDs (`'alex'`, `'you'`), while Spots and Docs use display-name strings (`'Alex'`, `'You'`). There is no single source of truth for "who is this person."
2. **Several nested list structures** (`SpotVotes`, `ReceiptSplit[]`, `CashDistribution[]`) have no natural Supabase mapping — they need junction tables, but the data shape doesn't yet make the FK structure obvious.
3. **Multiple private widgets are duplicated** across feature detail screens, especially `_NotesSection`, `_TypeBadge`, `_MetaRow`, and action-sheet list tiles.

---

## 1. Duplicate Models

### 1.1 `TripMember` lives inside `money_data.dart`

`TripMember`, `kYouId`, `kMockMembers`, and `memberById()` are defined in `lib/data/money_data.dart` but are a **trip-level concept** used across every feature. Spots, Docs, Plan, and Money all deal with members but must import the money file to get the type.

**Impact:** Any feature that needs member lookups couples itself to Money's data file.

### 1.2 Date formatting defined 4× in 3 different files

| Function | File | Access |
|---|---|---|
| `fmtDate(DateTime)` | `money_data.dart:251` | public |
| `fmtDayDate(DateTime)` | `plan_data.dart:637` | public |
| `_fmtDate(DateTime)` | `doc_card.dart:246` | private |
| `_fmtDateFull(DateTime)` | `doc_detail.dart:602` | private |

All four implement the same `const months = [...]` lookup. The only difference is whether year is included and the separator style.

### 1.3 `SpotComment` has no `id` field

Every other entity has an `id: String`. `SpotComment` (defined at `spot_data.dart:123`) is missing one entirely. This will block any attempt to store or reference comments in Supabase.

### 1.4 `SettlementSuggestion` is mutable while everything else is `const`

All other model classes use `const` constructors and `final` fields. `SettlementSuggestion` (`money_data.dart:203`) uses `var isSettled` — a mutable field on a data model — and the UI directly mutates it (`s.isSettled = true` in `settle_up_panel.dart:37`). This pattern will not survive any state management layer.

### 1.5 `DocType.receipt` and `Receipt` model conceptual overlap

`docs_data.dart` defines `DocType.receipt` for a document type, while `money_data.dart` defines a full `Receipt` model. A `TripDocument` of type `DocType.receipt` (e.g. `d10 — Ramen Ichiran Receipt Photo`) represents the same real-world object as a `Receipt`. The `DocumentLink` system bridges them, but the distinction is implicit and may confuse the schema design.

### 1.6 Color hex literals duplicated across data files

The same semantic colors appear hardcoded in `spot_data.dart` (`VoteType.color`, `VoteType.softColor`) and `money_data.dart` (`ReceiptCategory.color`, `ReceiptCategory.softColor`):

```dart
// spot_data.dart — VoteType.mustDo
const Color(0xFFC96F4A)
// money_data.dart — ReceiptCategory.food
const Color(0xFFC96F4A)  // identical
```

These should reference `app_colors.dart` constants (`kColorPrimary`, `kColorSecondary`, etc.), not raw hex literals.

---

## 2. Duplicate Widgets

### 2.1 `_NotesSection` — exact duplicate in 2 files

The widget is defined identically at `doc_detail.dart:291` and `item_detail.dart:409`:

```dart
// identical in both files
class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.notes});
  final String notes;
  // same build method: labeled box with kColorSurfaceSunken background
}
```

### 2.2 `_TypeBadge` — near-identical duplicate in 2 files

`doc_detail.dart:569` defines `_TypeBadge({required DocType type})` and `item_detail.dart:614` defines `_TypeBadge({required ItineraryItemType type})`. Both render a colored pill with icon + label. The only structural difference is the type parameter. Because both enums expose `.color`, `.icon`, `.label`, a single shared widget parameterized on those three fields would replace both.

### 2.3 `_MetaRow` — structurally duplicated in 2 files

`item_detail.dart:255` and `doc_detail.dart:182` both define `_MetaRow(icon, label, value)`. The doc version adds an optional `valueStyle` parameter, which makes it a superset. The item version could simply use the doc version.

### 2.4 `_ActionTile` / `_SheetTile` — same pattern, different names

`doc_detail.dart:543` defines `_ActionTile` and `item_detail.dart:589` defines `_SheetTile`. Both are `ListTile` wrappers with `icon`, `label`, `onTap`, optional `color`. Functionally identical.

### 2.5 Attach placeholder duplicated across Money screens

`receipt_detail.dart:244` defines `_AttachPlaceholder` as a proper class. `cash_detail.dart:177` inlines the same visual (dashed container, attach icon, caption text) without extracting it. They should share one widget.

### 2.6 Horizontal filter chip strips — two separate implementations

`spots_screen.dart:445` defines `_CategoryFilterStrip` (uses `WabwayTag`). `docs_screen.dart:281` defines `_FilterStrip` (uses its own `_FilterChip` with icon support). Both are horizontal scrolling chip rows for filtering a list. They could share a generic scrollable filter bar.

### 2.7 Desktop tab chip — a third filter pill implementation

`money_screen.dart:365` defines `_DesktopTabChip`, yet another pill-shaped selectable chip for switching tabs. This is conceptually the same as `WabwayTag` but styled differently. The design system's `WabwayTag` should absorb this if tab-level styling is needed.

### 2.8 Drag handle — repeated inline 4+ times

The 40×4 rounded drag handle widget is copy-pasted in `add_spot_sheet.dart:132`, `add_item_sheet.dart:163`, `item_detail.dart`'s action sheet, and `doc_detail.dart`'s action sheet. A `_DragHandle` shared widget would be two lines.

---

## 3. Inconsistent Naming

### 3.1 Member references: IDs vs. display names

| Model | Field | Value type | Example |
|---|---|---|---|
| `Receipt` | `paidById` | ID string | `'alex'` |
| `CashWithdrawal` | `withdrawnById` | ID string | `'you'` |
| `ReceiptSplit` | `memberId` | ID string | `'jordan'` |
| `Spot` | `addedBy` | Display name | `'Alex'` |
| `SpotComment` | `author` | Display name | `'Jordan'` |
| `SpotVotes` | `mustDo: [...]` | Display names | `['Alex', 'Sam']` |
| `TripDocument` | `uploadedBy` | Display name | `'You'` |

Money uses IDs; Spots and Docs use display names. This is the most critical naming inconsistency before backend integration.

### 3.2 Timestamp types: relative string vs. `DateTime`

`SpotComment.time` is stored as `String` (`'2d ago'`, `'1d ago'`). All other time fields (`Receipt.date`, `CashWithdrawal.date`, `TripDocument.uploadedAt`) use `DateTime`. `SpotComment.time` needs to become a `DateTime`.

### 3.3 ID format inconsistency across mock data

| Entity | Format | Example |
|---|---|---|
| Spot | bare integer string | `'1'`, `'9'` |
| Receipt | prefixed | `'r1'`, `'r8'` |
| CashWithdrawal | prefixed | `'w1'`, `'w3'` |
| TripDocument | prefixed | `'d1'`, `'d12'` |
| TripDay | prefixed | `'day1'`, `'day10'` |
| ItineraryItem | day-scoped | `'i1_1'`, `'i10_3'` |

Newly created items use `DateTime.now().millisecondsSinceEpoch.toString()`. None of this will survive a migration to UUIDs without an explicit remapping layer.

### 3.4 Asymmetric cardinality naming on `ItineraryItem`

```dart
final String? linkedSpotId;      // singular — one spot
final List<String> linkedDocIds; // plural  — many docs
```

The singular/plural pattern is correct logically, but the field name suffix (`...Id` vs `...Ids`) hides the cardinality from a reader scanning the model. Both should be consistently suffixed: `linkedSpotId` and `linkedDocumentIds` (or both shortened consistently).

### 3.5 `uploadedBy` vs `paidById` suffix convention

`TripDocument.uploadedBy` stores a display name String. `Receipt.paidById` stores an ID string. The `By` vs `ById` suffix convention implies the former is a name and the latter is an FK, but this should be uniform: all should use `...ById` (or `...UserId`) referring to an ID.

---

## 4. Document/Entity Linking

### 4.1 `DocumentLink.label` is denormalized

```dart
class DocumentLink {
  final DocLinkedType type;
  final String linkedId;
  final String label; // ← duplicates the linked entity's own title/name
}
```

The `label` field copies data that already exists on the linked entity (`Receipt.title`, `Spot.name`, `TripDocument.title`, etc.). In Supabase, this label would be resolved via a JOIN and should not be stored. Keeping it requires manual synchronization if the linked entity's name changes.

### 4.2 Hardcoded global mock lookups in UI screens

The following UI files import and query mock data constants directly:

| File | Hardcoded lookup |
|---|---|
| `item_detail.dart:63` | `kMockSpots.where((s) => s.id == item.linkedSpotId)` |
| `item_detail.dart:66` | `kMockDocuments.where((d) => d.id == id)` |
| `item_tile.dart:246` | `spotName()` → `kMockSpots.where(...)` |
| `item_tile.dart:252` | `docById()` → `kMockDocuments.where(...)` |
| `add_item_sheet.dart:261` | `kMockSpots` for spot picker dropdown |
| `add_item_sheet.dart:433` | `kMockDocuments` for document multi-picker |

Every one of these will need to become an API call. They should be isolated behind a data-access layer, not scattered through UI widgets.

### 4.3 `DocLinkedType.trip` references a non-existent model

`docs_data.dart` links several documents to `linkedId: 'trip1'` with type `DocLinkedType.trip`. There is no `Trip` model anywhere in `lib/data/`. This dangling reference will need a `Trip` entity before the docs feature can fully migrate to Supabase.

### 4.4 No reverse links on `Spot`

`ItineraryItem` knows about its `linkedSpotId`. `TripDocument` knows about its linked spots via `DocumentLink`. But `Spot` has no awareness of which itinerary items or documents reference it. In Supabase this is resolved via JOIN, but the mock data's uni-directional structure means the UI currently has no way to show "documents attached to this spot" or "this spot appears in day 2 of the plan" without a full scan.

---

## 5. Mock Data → Supabase Mapping Issues

### 5.1 `SpotVotes` uses parallel lists of display names

```dart
class SpotVotes {
  final List<String> mustDo; // ['Alex', 'Jordan']
  final List<String> want;   // ['Sam']
  ...
}
```

**Supabase equivalent:** `spot_votes(id, spot_id, user_id, vote_type)` — a junction table. The parallel list structure doesn't hint at this and will require a significant reshape. The voter strings are currently display names, not IDs.

### 5.2 `Receipt.splits` is a nested list

```dart
final List<ReceiptSplit> splits;
```

**Supabase equivalent:** `receipt_splits(id, receipt_id, user_id, amount, is_settled)`. Each `ReceiptSplit` maps to one row. The `isSettled` boolean is already per-row, which is correct, but settlement tracking may need its own event log table.

### 5.3 `CashWithdrawal.distributions` is a nested list

```dart
final List<CashDistribution> distributions;
```

**Supabase equivalent:** `cash_distributions(id, withdrawal_id, user_id, amount)`. Same pattern as splits.

### 5.4 `const _currency = 'JPY'` is a magic string in the UI

`money_screen.dart:32` hardcodes the currency. This should come from a `Trip` model field (`trip.currency`), not a UI constant.

### 5.5 `Spot.addedBy` / `TripDocument.uploadedBy` are display-name strings, not FKs

Both will become `UUID` foreign keys (`added_by_user_id`, `uploaded_by_user_id`) pointing to a `users` table. The current String type gives no indication of this FK relationship.

### 5.6 `SettlementSuggestion.isSettled` is in-memory only

Settlement state is tracked on a transient, locally-mutable object. In production, settled payments would be stored in a `settlements` or `payments` table. There is no model for "a recorded settlement event."

### 5.7 All entity IDs will become UUIDs

Current IDs (`'1'`, `'r1'`, `'day_1234567890'`) are human-readable for mock data but incompatible with Supabase's `uuid` primary keys. Any view or link that serializes IDs (navigation, deep links) will need a migration path.

### 5.8 `TripDay.items` is a mutable list mutated directly from the UI

```dart
// plan_screen.dart:37
day.items.removeWhere((i) => i.id == itemId);
// plan_screen.dart:49
day?.items.add(item);
```

`TripDay` is not `const` specifically because `items` needs to be mutable. In a real app, the screen state and the data model should be separated. Direct mutation of the model will conflict with any state management solution and will need to be refactored before or alongside backend integration.

---

## 6. Folder Organization

### 6.1 `TripMember` is in the wrong file

`lib/data/money_data.dart` should not own the core member type. This should be `lib/data/member_data.dart` (or `trip_data.dart`).

### 6.2 No `lib/utils/` directory

Utility functions are scattered across data files:
- `fmtAmount` — `money_data.dart`
- `fmtDate` — `money_data.dart`
- `fmtDayDate` — `plan_data.dart`
- `memberById` — `money_data.dart`
- `itemById`, `dayForItem` — `plan_data.dart`
- `spotName`, `docById` — `item_tile.dart` (in a UI file!)

`spotName()` and `docById()` in `item_tile.dart` are particularly out of place — lookup helpers should not live in a widget file.

### 6.3 Feature screen organization is inconsistent

Spots, Money, Docs, and Plan all have `screens/<feature>/` sub-folders. But:
- `home_screen.dart`, `members_screen.dart`, `more_screen.dart` sit directly in `screens/` without sub-folders.
- When Home, Members, and More grow to have sub-widgets, they'll either clutter `screens/` or need retroactive reorganization.

### 6.4 `placeholder_screen.dart` bundles 4 different screens in one file

`LinksScreen`, `MapScreen`, `TravelScreen`, and `SettingsScreen` are all in `lib/screens/placeholder_screen.dart`. When any of these is implemented, it will need its own file/folder and the placeholder file will become partially stale. It would be cleaner to stub them individually now.

### 6.5 No `travel_data.dart`

The Travel feature is a placeholder but is listed as a nav destination. When implemented, it will need a data model (flights, hotels, train bookings). Spotting this now allows a data schema to be designed alongside Spots/Money/Docs.

---

## 7. Other Issues

### 7.1 `dayNumber` assignment is fragile

```dart
// plan_screen.dart:61
dayNumber: _days.length + 1,
```

This is wrong as soon as any day is deleted. Day 1 of 10 deleted → new day added → it becomes "day 10" not "day 10." Day numbers should be derived from sorted date, not from list length.

### 7.2 `ItineraryItem.time` stored as `'HH:MM'` String

The time field uses a 24h String format (`'09:00'`). This is a reasonable display format but needs explicit parsing for any time-based sorting, comparison, or storage. Consider using `int minutes_since_midnight` or `TimeOfDay` (for UI) backed by a `time` column in Postgres.

### 7.3 `SpotComment.time` is a relative-time fiction

All mock comments have times like `'2d ago'`, `'1d ago'`. This implies they were recently added, but the dates are all relative to an unspecified "now." This needs to be a real `DateTime` so the UI can display relative time dynamically.

### 7.4 `_openLink` is a free function in `spot_detail.dart`

```dart
// spot_detail.dart:276
Future<void> _openLink(BuildContext context, String url) async { ... }
```

A URL-launching utility should be in `lib/utils/url_utils.dart`, not embedded in a specific feature's detail screen. It's already generic.

### 7.5 `add_item_sheet.dart` imports both `docs_data.dart` and `spot_data.dart`

The sheet imports global mock data to populate its linked-spot picker and document multi-picker. These will need to become network-fetched suggestion lists, scoped to the current trip. The coupling to global constants will need to be replaced with injected data or a repository call.

### 7.6 `DocLinkedType.travelItem` has no corresponding model

`DocLinkedType.travelItem` is defined in `docs_data.dart` but no `TravelItem` model exists anywhere. Linking a document to a travel item is currently impossible. This enum case is dead code.

---

## Proposed Cleanup Plan (Prioritized)

The following changes are ordered from smallest risk to largest. Each step can be done independently without breaking any existing UI.

---

### Step 1 — Extract date utilities (risk: zero)

**Create `lib/utils/date_utils.dart`** with:
- `fmtShortDate(DateTime d)` → `'Nov 12'` (replaces `fmtDate` + `fmtDayDate` + `_fmtDate`)
- `fmtLongDate(DateTime d)` → `'November 12, 2024'` (replaces `_fmtDateFull`)

Update imports in `money_data.dart`, `plan_data.dart`, `doc_card.dart`, `doc_detail.dart`. No behavior change.

---

### Step 2 — Move `TripMember` to its own file (risk: low)

**Create `lib/data/member_data.dart`** containing `TripMember`, `kYouId`, `kMockMembers`, `memberById()`. Remove them from `money_data.dart`. Update all import sites (money, any future features).

---

### Step 3 — Extract shared `_NotesSection` widget (risk: zero)

Add `WabwayNotesSection({required String notes})` to `lib/widgets/` (or as a shared widget in a new `lib/widgets/detail_widgets.dart`). Replace the two identical private classes in `doc_detail.dart` and `item_detail.dart`.

---

### Step 4 — Extract shared `_TypeBadge` → `WabwayEntityBadge` (risk: zero)

A single widget that takes `icon: IconData`, `label: String`, `color: Color` replaces both `_TypeBadge` implementations. No logic change.

---

### Step 5 — Extract `_DragHandle` widget (risk: zero)

One shared `_DragHandle` widget (can stay package-private) replaces 4+ copy-pasted inline drag handles.

---

### Step 6 — Normalize `SpotComment.time` to `DateTime` (risk: low)

Change `SpotComment.time` from `String` to `DateTime createdAt`. Update mock data to use `DateTime(2024, 11, 12)` etc. Update `_CommentRow` in `spot_detail.dart` to render relative time dynamically (`timeago` package or a simple helper).

---

### Step 7 — Normalize member references in Spots and Docs (risk: medium)

Change `Spot.addedBy`, `SpotComment.author`, and `SpotVotes` lists from display names to member IDs. Change `TripDocument.uploadedBy` from display name to member ID. Add display name resolution via `memberById()` at the UI layer. This is the most impactful naming change before Supabase because it aligns all features on the same identity model.

**After this change:** All member references across the app use IDs, matching the pattern already established in Money.

---

### Step 8 — Add `id: String` to `SpotComment` (risk: zero)

Add the field to the class and populate mock data with simple IDs (`'c1_1'`, `'c1_2'`, etc.). Prerequisite for any comment storage.

---

### Step 9 — Remove `DocumentLink.label` (risk: medium)

Delete the `label` field from `DocumentLink`. Update the `_LinkedSection` in `doc_detail.dart` to resolve label text from the linked entity directly (look up `Spot.name`, `Receipt.title`, etc.). This breaks the denormalization and prepares for JOIN-based resolution.

---

### Step 10 — Make `TripDay.items` immutable; lift mutation to screen state (risk: medium)

Change `TripDay` to take `List<ItineraryItem>? items` and make the resolved list immutable. Move add/remove logic in `plan_screen.dart` to operate on a local state copy of `_days` rather than directly mutating model instances. This decouples model from state and is a prerequisite for any real state management layer (Riverpod, Bloc, etc.).

---

### Step 11 — Introduce a `Trip` model stub (risk: low)

Create `lib/data/trip_data.dart` with a minimal `Trip` class (`id`, `name`, `currency`, `startDate`, `endDate`, `memberIds`). Wire `const _currency = 'JPY'` in `money_screen.dart` to come from a mock Trip instance. This unblocks `DocLinkedType.trip` links and the currency/trip context needed everywhere.

---

### Step 12 — Consolidate filter chip components (risk: low, do after feature work settles)

Evaluate `_CategoryFilterStrip`, `_FilterStrip`, and `_DesktopTabChip` for unification into a generic `WabwayFilterBar` widget in the design system. Only worth doing once the set of screens using it is stable.
