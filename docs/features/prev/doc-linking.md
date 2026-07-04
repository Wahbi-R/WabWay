# Document Linking

## What it does

The "Link to…" picker in Document Detail now loads and shows all linkable entities from the trip, organized into sections. Previously only Trip and Spots were available.

## Sections in the picker

| Section | Entity | Subtitle shown |
|---|---|---|
| Trip | The trip itself | — |
| Spots | All spots in the trip | City, Area |
| Receipts | All receipts | Amount |
| Cash withdrawals | All ATM withdrawals | Date |
| Travel | All travel items | Item type (Flight, Hotel…) |
| Plan | Each day + each itinerary item | Day number for items |

Already-linked items are hidden — the picker only shows things that aren't linked yet.

## Implementation

`_LinkPickerSheet` is now a `StatefulWidget`. On open it fires `Future.wait([loadReceipts, loadWithdrawals, loadItems, loadAll])` to fetch all entities in parallel, then renders the grouped list. A `CircularProgressIndicator` shows while loading.

The existing `_addLink` / `_removeLink` flow in `_DocDetailContentState` is unchanged — the picker just calls `onPick(type, linkedId)` which feeds into the same `DocService.addLink` path.

`WabwayActionTile` gained an optional `subtitle` parameter for the secondary text line.

## Files

| File | Change |
|---|---|
| `lib/screens/docs/doc_detail.dart` | `_LinkPickerSheet` rewritten as `StatefulWidget`; loads receipts, withdrawals, travel items, plan days; `_showLinkPicker` uses unified `alreadyLinked` set; `_fmtShortDate` helper added |
| `lib/widgets/wabway_detail_widgets.dart` | `WabwayActionTile.subtitle` optional param added |
