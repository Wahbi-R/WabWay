# Document Linking

## Description

Any `TripDocument` can be linked to one or more entities — receipts, cash withdrawals, travel items, plan items, days, spots, or the trip itself. Links are stored in the `document_links` join table.

## Key Files

- `lib/core/supabase/doc_service.dart` — `addLink()`, `deleteLink()`, `loadLinkedDocuments()`
- `lib/data/docs_data.dart` — `DocumentLink`, `DocLinkedType` enum
- `lib/screens/docs/doc_detail.dart` — "Link to…" action sheet with all entity pickers
- `supabase/migrations/001_initial_schema.sql` — `document_links` table and `doc_linked_type` enum

## How It Works

`document_links` columns: `document_id`, `linked_type` (`doc_linked_type` enum), `linked_id`, `created_by`.

- **From doc detail**: a bottom sheet lets the user pick any link target (e.g. a receipt or travel item). `DocService.addLink()` inserts the row.
- **From plan / travel / money**: when creating or editing an item the picker shows available documents and inserts `document_links` rows after the parent row is created.
- `DocService.loadLinkedDocuments()` reverses the lookup — given a `linked_type` + `linked_id`, it returns all linked `TripDocument`s.
- Deleting a link calls `DocService.deleteLink()` (matched on all three columns).

## Setup

No extra migration needed beyond `001_initial_schema.sql`. RLS on `document_links` mirrors the trip-member policy.
