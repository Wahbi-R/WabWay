# Receipt/Document Workflow Improvements

## What it does

Three improvements to the Money ↔ Docs workflow.

## 1. Create receipt from doc detail (already wired in prior session)

The **"Create Receipt"** button in `doc_detail.dart` opens the Add Receipt sheet and automatically links the doc to the new receipt via `document_links`. A success snackbar confirms.

## 2. URL docs openable in receipt detail

`_LinkedDocsSection._open` now supports URL documents (where `doc.ext == 'url'` and the URL is stored in `doc.notes`). Previously only storage-backed files could be opened.

The open icon is now shown whenever the doc can be opened (storage file or URL), not just for storage-backed docs.

## 3. Improved split UX

- **Proportion bar**: a segmented, color-coded horizontal bar above the split list shows each person's share at a glance. Only shown when there are ≥2 splits.
- **Percentage labels**: each split row now shows the percentage next to the amount (e.g. `¥3,500 · 25%`).

## Files

| File | Change |
|---|---|
| `lib/screens/money/receipt_detail.dart` | `_SplitBar` widget; `_SplitRow` gained `total` param + percentage; `_LinkedDocsSection._open` supports URL docs; `_DocRow.canOpen` covers URL docs |
