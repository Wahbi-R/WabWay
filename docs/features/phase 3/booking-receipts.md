# Booking receipts, prices and languages

**Build:** 428  
**Area:** Read booking review, Money, receipts.wabble.ca links, wabway-server

Builds on [Read booking](read-booking.md) (427).

## What it does

When you share a booking, its price now ends up somewhere useful. A booking
that's paid becomes a **receipt in Money** (paid by you, split between the
people on it), and that receipt is published to **receipts.wabble.ca** like any
other receipt, with the booking's own PDF page(s) as its pictures.

Example: the Shinkansen thread PDF holds **three** smart EX confirmations, so it
becomes three trains and three receipts:

| Ref | Train | Receipt |
|---|---|---|
| 2005 | Nov 14 Hakata → Hiroshima (non-reserved) | ¥34,280 · split 4 ways · page 1 |
| 2006 | Nov 14 Higashi-Hiroshima → Shin-Osaka (non-reserved) | ¥38,680 · split 4 ways · page 2 |
| 2007 | Nov 18 Hikari 704 Shin-Osaka 10:48 → Atami 13:04, Car 14 | ¥49,720 · split 4 ways · itemised · page 2 |

## On the review screen

Each card now shows:

- **Price**: "Paid ¥49,720 · ¥12,430 each", with the printed price lines under
  it (fares, bags, nights, taxes). It also shows what's still due, a deposit
  ("Paid ¥10,000 of ¥30,000"), or points ("35,000 Aeroplan points").
- **Warnings**:
  - "Check the currency" when the booking didn't say clearly (a lone `$`, or
    none at all). The trip's currency is used, never a silent USD.
  - "The price lines don't add up to the total" when the AI misread a line.
    This is the same check the receipt scanner does.
- **Translated from Japanese** when the booking wasn't in English. Titles and
  notes are in English, names keep the original in brackets
  ("Shin-Osaka (新大阪)"), and addresses keep the original script for drivers.
- **Add receipt to Money**: on by default for paid bookings. The subtitle shows
  "¥49,720 · paid by you · split 4 ways · itemised · Receipts link".
  - **Change payer or split** opens the normal Add receipt sheet, pre-filled.
    That sheet saves the receipt, and the booking is linked to it on Save.
  - If Money already has the same payment (same amount and currency, and the
    same name or reference), the card says **"Already in Money: …"**. The
    switch starts off and the booking is linked to that receipt instead.
- No receipt is made when nothing's paid yet ("¥30,000 to pay"), the booking is
  free, or no price is shown. A deposit records only what was paid.

## The receipt

- **Paid by** the person sharing. **Split** between the booking's travellers
  when every seat is assigned to a member and the count matches; otherwise
  between everyone in the trip.
- **Category** comes from the booking: transport / stay / food / activity.
- **Items**: if the printed lines add up, they become receipt items shared by
  the travellers (so a bag can later be moved to the one person it's for).
  Otherwise it's one amount.
- **Notes**: "From booking · Ref 2007" (plus anything still due).
- **Exchange rate**: today's rate (Frankfurter), no card fee. If the rate can't
  be fetched, that receipt is skipped and the toast says so.
- **Linked both ways**: the receipt and the travel item / stay / plan item
  appear in each other's Connections.
- **The source file** is attached to the receipt as a document.
- **Receipts link**: follows the "Share as a Receipts link" choice from Add
  receipt (`ReceiptsLinkService.defaultCreateLink`, shared by both). Its
  pictures are the booking's own PDF pages (`source_pages` from the reader),
  or the shared screenshot.

## PDFs on Receipts links (all receipts)

The Receipts site shows pictures, so PDFs are now turned into page images
(`lib/core/pdf_pages.dart`, `printing` raster). `ReceiptsLinkService.attachedPhotos`
includes attached PDFs, which covers **Create link** on any receipt with an
attached PDF. `runReceiptFollowups` uses attached documents when a new receipt
has no photos, and takes `linkPhotos` for pictures that are only for the link.

## Server (`/booking/parse`, wabway-server build 433)

New fields per booking:

- `price_lines` (label, quantity, amount)
- `paid_status` (paid / due / part_paid / unknown) and `amount_due`
- `points` and `currency_guessed`
- `passenger_count`
- `source_pages` (1-based PDF pages)
- `original_language`

The prompt asks for English output with originals in brackets, matches names
across scripts (katakana/hanzi/hangul read phonetically), lists each booking of
an email thread once, and receives the trip's currency.

## Also

- `fmtAmount` now groups thousands (`¥49,720`, `C$1,234.50`) everywhere.
- `pubspec.yaml`: `printing`, plus `image >=4.5.0 <4.11.0`. image 4.11.0 calls
  an archive 4.1 API while `pdf` (via printing) caps archive below 4.1. printing
  5.15 would fix it but needs xml 7, which Syncfusion blocks.

## Not done yet

- A due amount is in the stay's notes, but there's no "mark paid → make
  receipt" button on the stay itself.
- Deleting a booking doesn't offer to delete its receipt.
- Receipts doesn't link entries to user accounts yet. Booking receipts will
  pick that up when Receipts adds it.

Tests: `test/booking_receipts_test.dart`. It uses the real three-confirmation
thread, and covers receipts per booking, splits, deposit/due/free, the
currency fallback, matching receipts already in Money, thousands separators,
and the review screen.
