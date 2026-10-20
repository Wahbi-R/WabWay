# Receipts in WabWay — split by item, Receipts links, paying back (Build 420)

receipts.wabble.ca ("Receipts") is its own product: a split-the-bill site where
anyone with a link claims items and marks themselves paid. WabWay now does
everything Receipts does, works offline, and can publish any receipt as a
Receipts link. **WabWay's receipt is the source of truth**; the link is a copy
whose changes are only applied when someone taps *Apply*.

## Splitting

| Mode | Shares |
|---|---|
| Equal | total ÷ people ticked |
| Custom | typed per person; shows "X not assigned — the payer covers it" |
| By item | `ReceiptItemization.toSplits()` — items + proportional tax/tip/discount |

All shares are in the **receipt's currency** (like `receipts.amount`). The home
currency only appears in `home_amount` (totals). Before 420 the form saved shares
in home currency while balances and the detail screen read them as the receipt
currency.

### Item model — `lib/data/receipt_items.dart`
Port of `useSplitStore.ts` (`toggleAssignment`, `portionDivisor`,
`unaccountedItems`, `calcPersonTotals`). Weights are portions of the item's
quantity (1 of a 2× item = half). Unclaimed parts are covered by the payer;
over-claimed items are shared proportionally. **Keep the two in step** — the
unit test's dinner fixture matches the site's output exactly.

Stored in `receipts.items` (jsonb): `{title, items[{id,name,quantity,unit_price,total_price}], subtotal, discount, tax, tip, total, assignments{itemId:{memberId:weight}}}`.
`subtotal`/`total` are what was printed (to warn about misread lines); the
receipt amount is always items + tax + tip − discount.

### Editor — `lib/screens/money/receipt_items_editor.dart`
`showReceiptItemsEditor(initial:, members:, currency:)`. Opens from the "By item"
chip, after a scan, or "Edit items & who had what". Tap a person on an item;
"Portions" for multi-quantity items; "Everyone shares all"; "Split leftovers
equally"; tap an item to rename / change quantity / price / remove; tap the
totals card for tax, tip and discount. Fully offline.

### Scanning — `lib/core/receipt_scan_service.dart`
Several photos (top to bottom) go to `/receipt/scan` in one call (`images[]`).
95 s timeout (server may take ~85 s + retry, under Cloudflare's 100 s). Returns
`ReceiptScanOutcome` with a specific message (offline, timeout, HEIC, too long,
scanner off…). The scanned business name fills an empty title.

## Paying back

Shares are the one record of who owes whom (`receipt_splits.is_settled`,
`cash_distributions.is_settled`). Balances (`calculateBalancesGrouped`) count
open shares only.

- **Per receipt:** detail screen → *Mark paid* / *Paid* on each share. Allowed
  for that person, the payer and the organiser (RLS). Offline → queued
  (`SyncQueue.enqueueSettleShare`) and shown as paid immediately
  (`withPendingSettles`).
- **Settle Up:** *Mark settled* writes one `settlements` row and marks every open
  share between the two people in that currency (both directions, receipts and
  cash) with its `settlement_id` (`SettlementService.settleAll`). *Payments*
  lists them; *Undo* reopens those shares and deletes the row.
- Editing a receipt keeps a paid share paid if its amount didn't change.

## Receipts links — `lib/core/receipts_link_service.dart`

- **Create:** "Share as a Receipts link" switch on new receipts (remembered),
  or *Create link* on the detail screen later. Publishes through wabway-server
  `/receipt/save` (same as the site), uploads photos to the Receipts project's
  `receipt-images` bucket, and stores `split_link_id`, `split_link_members`
  (member ids in person-id order) and `split_link_hash` via the
  `set_receipt_split_link` RPC (any trip member). Receipts split by amount are
  published as one line with weights that reproduce the shares exactly.
- **Offline (build 423):** receipts saved offline show in the Money list as "Waiting to sync" (tap → Discard) and count in balances. Every trip's queue uploads whenever trips load online (app start or reconnect), each receipt sends the normal "New receipt added" push, and leaves the queue as soon as it's uploaded.
- **Offline:** link creation is queued (`SyncQueue.enqueueLink`), and receipts
  saved offline keep `createLink`, items, photos (written to app files) and
  picked docs. The queue drains on reconnect and after the Money screen's next
  successful load.
- **Reading back:** the detail screen fetches the link (Receipts anon key,
  read-only) and compares `hashOf(remote)` with `split_link_hash`. If they differ,
  it shows what changed per person (amounts, "marked paid", people not in the
  trip). *Apply to WabWay* (payer / creator / organiser) saves the link's items
  and claims and marks paid shares; *Keep WabWay's* overwrites the link
  (keeping its approvals/history and people added on the site).
- **WabWay edits:** after an edit (or a share marked paid) WabWay pushes to the
  link, but only if the link hasn't changed since the last sync; otherwise
  nobody's claims are overwritten and the detail screen offers Apply.
- People added on the site are matched to trip members by name; anyone else's
  claims stay with the payer.

## DB — `049_receipt_items_links_and_share_settling.sql`
New columns above + `receipts.created_by`; backfilled old settlements onto the
shares they covered; converted home-currency shares (none existed); new DELETE
policies for `receipt_splits` (editing failed without it) and
`cash_distributions`; receipts can be inserted with any trip member as payer and
edited by payer, creator or organiser.

## Not done / known limits
- `/receipt/scan` and `/receipt/save` are unauthenticated — logged in TODO.md.
- Web can't queue photos offline (no file storage); the receipt and its items
  still queue.
- Partial payments ("paid 30 of 50") aren't modelled; a share is paid or not.
