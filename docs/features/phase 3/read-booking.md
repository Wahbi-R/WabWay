# Read booking

**Build:** 427  
**Area:** Share / Import, Travel, Stays, Plan, wabway-server

## What it does

Share any booking to WabWay and it works out the rest. That covers an e-ticket
PDF, a screenshot, a forwarded confirmation email, or a confirmation page link.
**Read booking** finds every booking in it: flight, train (Shinkansen
included), bus, ferry, car hire, hotel or Airbnb, ticket or restaurant
reservation. It fills in everything the booking shows and puts each one where
it belongs:

| Found | Goes to |
|---|---|
| Flight / train / bus / ferry / car hire / rail pass | **Travel**, and optionally its **Plan** day |
| Hotel / Airbnb / hostel / ryokan | **Stays**, with check-in/out dates *and times* (build 426) |
| Museum or show ticket, tour, restaurant reservation | That day in the **Plan**, with time, place and cost |

It also works out **who's travelling**. Passenger names on the ticket
("RAIHAN/WAHBI MR") are matched to trip members, and each person gets their
seat. When seats are printed without names (the Shinkansen e-ticket lists four
seats), each seat becomes an unassigned traveller you can assign with one tap.

## How it's used

1. Share the PDF / screenshot / email / link to WabWay, or use Import (pick a
   file, take a photo, or paste a link *or a whole email*).
2. Tap **Read booking**. It's the first option for anything that could be a
   booking, so you don't need to choose a destination first.
3. **Review bookings** lists what was found. Each card shows the date and
   times, the route, who's travelling and their seats, and the reference.
   For each card you can:
   - **Add**, or **Skip** it.
   - If it's **already in your trip** (same reference, or same type, day and
     time), it says so and defaults to **Update existing**. Empty fields are
     filled in and the file is attached; nothing the group entered is
     overwritten. **Add anyway** is there if it really is a second booking.
   - Travel: **Also add to the plan for <day>** (on by default). This creates
     the plan day if it doesn't exist.
   - **Edit details** opens the normal Add sheet (travel / stay / plan item),
     pre-filled.
4. **Save N bookings**. The shared file is uploaded to Docs once and attached
   to everything saved or updated.

No signal: files also show **"No signal? Read flights on this phone"**. That's
the on-device text reader, which only recognises flights.

## Who's travelling

- Travel items now have a **travellers** list (trip member and/or name as
  printed, plus seat).
- **Add / Edit travel** has a **Who's travelling** section. Each row has a
  person picker ("On ticket: BOB" as the hint for unmatched names), a seat
  field and remove. There are **Everyone** and **Add person** buttons.
- The travel detail page shows **Who's travelling** with avatars and seats.
  Cards show a one-line summary: `You · Car 14 20-D`, `You, Sam +2`,
  `4 seats`.
- AI access (MCP): `get_bookings` returns travellers (with member names),
  `add_travel` / `update_item` take `travellers: [{name, seat}]`, and names
  are matched to members.

## Implementation

| Layer | Change |
|---|---|
| wabway-server | `POST /booking/parse` (`main.py`): files (PDF as a Claude `document`, images), `text`, `url` (fetched with the SSRF guard; JSON-LD + page text). It requires the app's Supabase access token (checked against `/auth/v1/user`) and trip membership, and is limited to 30 per user per hour. The trip's members and dates go into the prompt so it can match passengers and pick the year. Structured output schema with plain types only, normalised server-side (`_normalize_bookings`). `_receipt_call` generalised to `_claude_structured`. MCP: travellers on `get_bookings` / `add_travel` / `update_item` |
| Supabase | `052_travel_travellers.sql`: `travel_items.travellers jsonb not null default '[]'` |
| `lib/core/booking_parse_service.dart` | Calls the server and maps its JSON to drafts (`fromServer`) |
| `lib/core/ocr/parsed_booking.dart` | Sealed `ParsedBooking`: `ParsedTravel(TravelItem)`, `ParsedStay(Accommodation)`, `ParsedPlan(ItineraryItem, day)`. Replaces the flight-shaped model that dropped arrival time, stations, seats and reference on save |
| `lib/core/booking_merge.dart` | `findExistingBooking`, `mergeTravel`, `mergeStay` (dedupe + fill-empty-fields) |
| `lib/screens/share/booking_review_screen.dart` | Replaces `parsed_itinerary_screen.dart` |
| `lib/screens/travel/travellers_section.dart` | `TravellersEditor`, `TravellersList`, `travellersSummary` |
| Add sheets | `showAddTravelSheet(prefillItem:)`, `showAddItemSheet(prefillItem:)`, `showAddStaySheet(draft:)`: a full new item to start from, still in Add mode. The stay sheet now keeps the address on create. `AccommodationService.createFromDraft`, and `TravelService.createFromDraft` now keeps `url` |
| `TravelItem` | `travellers`; `withPlanLink` / `withTravellers` share one `_copy`, which fixes "Add to plan" dropping terminals, gate, seat and boarding time from the item on screen |
| Share | `ShareContentType.text` for shared emails/notes (checked before link detection, so an email mentioning booking.com isn't treated as a listing). Import's link field accepts pasted email text |
| Removed | `GeminiParser`, `ParseCounter`, and the Gemini "Parse with AI" path (the boarding-pass scanner in Add travel still uses its own Gemini call) |

Tests: `test/read_booking_test.dart` (server → drafts, dedupe/merge, text
detection, traveller summary, review screen, travel sheet with scanned
travellers).
