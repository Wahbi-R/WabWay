# Receipt / Document Workflow

## Description

Improvements to the relationship between receipts and documents: create a receipt directly from a doc detail screen, open linked URL docs from within a receipt's linked-doc list, and a visual split proportion bar with percentage labels on the receipt detail.

## Key Files

- `lib/screens/docs/doc_detail.dart` — "Create receipt from this doc" action
- `lib/screens/money/receipt_detail.dart` — linked docs list with URL-doc open, split proportion bar
- `lib/screens/money/cash_detail.dart` — ATM slip photo attach via document_links
- `lib/core/supabase/money_service.dart` — `createReceipt()`
- `lib/core/supabase/doc_service.dart` — `addLink()`, `loadLinkedDocuments()`

## How It Works

**Doc → Receipt**: The doc detail action sheet exposes "Create receipt". Pre-fills the add-receipt sheet with amount/currency if present on the document, then links the new receipt back to the document via `document_links` (`linked_type: 'receipt'`).

**URL doc in receipt**: When a linked document has `ext == 'url'` (a link doc, not a file), the receipt linked-docs row shows an "Open" button that calls `url_launcher`.

**Split bar**: Below the receipt amount, a horizontal bar shows each member's proportion of the split as a coloured segment. Percentage labels appear on hover or in sufficient space.

**ATM slip**: `cash_detail.dart` replaced the placeholder attach button with `image_picker` + `DocService.uploadAndCreate()`, then links the resulting doc to the withdrawal via `document_links` (`linked_type: 'cash_withdrawal'`).
