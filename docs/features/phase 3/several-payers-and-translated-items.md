# Several payers, inline portions, translated item names (build 440)

## Several people paid one receipt

Example: a ¥14,795 yakiniku bill for four, where Ber put in ¥10,000, you ¥4,000
and Shams ¥795 in cash.

- **Add/Edit receipt** → under *Paid by*, **Several people paid** shows an
  amount field per member (the same rows as the Custom split). The amounts
  must add up to the receipt total (or the items total when split by item).
  **One person paid** goes back to the single picker.
- Whoever put in the most becomes the **main payer** (`receipts.paid_by`).
  Everyone else settles with them:
  `what they still owe = their share − what they put in`.
  A negative result means the main payer owes them (they put in more than
  their share). Someone can chip in without sharing the cost (a 0 share).
- **Storage:** `receipt_splits.contributed` (migration `054`). Shares may be 0
  as long as the person contributed. Single-payer receipts keep every
  `contributed` at 0, so nothing changes for them.
- **Model:** `ReceiptSplit.contributed`, `Receipt.hasSeveralPayers`, `payers`,
  `contributionOf`, `owes(split)`. Balances, `myNetFor`, `openDebts`,
  `openSharesBetween` and Settle Up all use `owes`. Helpers:
  `withContributions(shares, contributions)` and `mainPayerOf`.
- **Kept on every re-split:** edits, applying Receipts-link changes, and
  saving translations (`MoneyService.updateItemsAndSplits` re-applies the
  receipt's payers).
- **Shown:** receipt page (*Paid by* lists everyone with their amount; each
  row reads "put in ¥X · owes ¥Y / is owed ¥Y / all square"), Money list
  ("Ber + 2 others paid"), payer filter, spending-by-payer card (each payer
  gets their part) and the CSV export.
- Stay ↔ receipt price sync skips receipts with several payers
  (`rescaleBlocker`).
- Settling between two non-main payers goes through the main payer. That is
  correct overall, though it isn't always the fewest payments.

## Item split like the Receipts site

- Portions are inline under each item once 2+ people share it, or one person
  has part of a multi-unit item. There's a − / + per person, "3 of 9 ·
  ¥650 each", and a **Split equally** button. The separate Portions sheet is
  gone.
- When an item is split unevenly or only partly claimed, a line shows what
  each person pays for it ("Ber ¥1,463 · You ¥731").

## Translated item names

- `/receipt/scan` (wabway-server) now returns `name_en` per item and
  `title_en` when the receipt isn't in English. The receipt title becomes
  "Yakiniku Rengaya (焼肉れんが屋)".
- `ReceiptItem.nameEn` is stored in `receipts.items` as `name_en`. Renaming an
  item drops its translation.
- **Translate to English** (in the item editor, or *Who had what* on the
  receipt page) calls the new `POST /receipt/translate` (Supabase sign-in,
  60/user/hour) for items scanned before this build or typed in by hand.
  On the receipt page the result is saved for editors only.
- **Show original / Show English** switches all item names, per device
  (`ReceiptScanService.showEnglish`). With English on, the printed name
  shows small underneath so it still matches the paper.

## Receipts site (receipts.wabble.ca)

- The link payload carries `receipt.payers` (person index → amount) when
  several people paid. Summary shows a *Who paid* card and "Put in ¥X ·
  owes ¥Y / gets back ¥Y" on each person. People who put in exactly their
  share are marked paid.
- Items carry `name_en`. Assign and Summary show English names, with a
  per-device *Show original names* toggle. The site's own scans keep the
  translation too.
- The link hash ignores `name_en` and `payers`, so they never show up as edits
  made on the link.

Tests: `test/several_payers_test.dart`.
