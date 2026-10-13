# Attached documents (build 418)

## What it does
Every item that can carry paperwork has the same **Documents** section:
travel items, stays (edit sheet), plan items, spots, receipts and cash
withdrawals.

**Attach** opens a menu:

| Option | What happens |
|---|---|
| Take photo (phones only) | Camera → the Add document form with the photo already in it |
| Upload file | The Add document form, prefilled with the item's name as title, a matching type (flight/train/reservation/hotel/ticket/receipt) and an "Attaching to …" note. Saving creates the document and attaches it. |
| Choose from Library | Checklist of the trip's documents; checking/unchecking attaches/detaches |
| Paste link | The Add link form; the saved link (a link document since build 417) is attached |

Tapping an attached document opens its detail page (preview, Open link,
Download, Share). The × removes it from that item only; the document stays in
the Library.

## Where the data lives
- One table: `trip_connections` (`entity_a_type = 'doc'`, `entity_b_type` = the item's type).
- `DocService.attach / detach / loadAttached / attachedDocIds` are the only
  entry points. `attach` skips ids that are already attached (unique
  `(entity_a_id, entity_b_id)` + an existence check across both tables).
- Legacy `document_links` rows are **read** (merged, de-duplicated) and
  **removed on detach**, never written. Migration 047 already copied all of
  them into `trip_connections`; older installed builds may still write there,
  which is why reads keep merging.
- `ConnectionService.remove` deletes a pair from both tables. Deleting only the
  `trip_connections` copy would let the `document_links` copy reappear.
- `DocService.deleteDocument` also deletes the document's `trip_connections`
  rows (polymorphic table, no FK cascade).

## Create forms
New travel items, plan items and receipts can still pick existing documents in
the form (`DocMultiPicker`). The service attaches them after the item is
created. Edit forms no longer show the checklist; that's done on the item's page.

## Connected vs Documents
`ConnectionsSection` hides documents (chips and picker tab) on every screen
except a document's own page. There it lists everything the document is
attached to.

## Older app versions
Attachments made with this build are only in `trip_connections`. Older
installed APKs read travel/plan/receipt attachments from `document_links`, so
they won't show new attachments until updated.
