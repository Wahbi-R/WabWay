# WabWay — New Feature Ideas

Ideas organized by trip phase. "Quick win" = implementable in ≤1 session.

---

## Planning Phase

### Budget Planner
Set a total budget (or per-category budgets) before the trip and see live progress against actuals as receipts come in. A simple progress bar on the home screen and Money screen showing "spent / budgeted" per category. Needs a `budgets` table (trip_id, category, amount_home) and a comparison against `SUM(home_amount)` from receipts.

### Packing List
Shared checklist visible to all trip members. Each item has a name, an optional assignee ("Wahbi is bringing the portable charger"), and a done/not-done toggle per member. Could live under a new "Prep" tab or inside the Plan screen. DB: `packing_items (id, trip_id, title, assigned_to_user_id, created_by)`.

### "Who's Coming" Day Scheduler
For trips where not everyone arrives/leaves on the same day. Each member marks which days they'll be present. Itinerary items can then show who's there for that activity, and cost splits can auto-exclude absent members. DB extension to `itinerary_days` or a separate `member_availability` table.

### Plan Export to Calendar (ICS)
Generate an `.ics` file from the trip's itinerary days and items. Each item becomes a calendar event with the day's date, time (if set), and location. Share via `share_plus`. No server needed — pure Dart ICS generation. Useful for syncing to Google Calendar / Apple Calendar before the trip.

### Spot Deduplication / Merge
When importing from Takeout or Maps, the same place often comes in twice with slightly different names. A "Find duplicates" flow that compares names + coordinates within a distance threshold, shows pairs side-by-side, and lets the user merge them.

### Pre-Trip Checklist
A template-driven checklist of things to do before leaving: "book airport transfer", "set travel notifications on credit card", "download offline maps", etc. Members can check off their own items.

---

## Active Travel Phase

### Currency Converter (Offline)
A quick-tap converter on the home screen or Money screen. Set the base currency (home currency) and convert any amount to a target currency using the last-fetched exchange rate stored locally. No API call needed during the trip — rates update once on app open when online.

### Today's Agenda Card (Expanded)
The home screen already shows the next upcoming plan item. Expand this to a full "today" card: all items for today's plan day, with their times and done/not-done status. One tap marks an item done without navigating to the Plan screen.

### Emergency Info Card
A screen (under More or the home screen) with:
- Trip insurance number
- Credit card emergency line
- Local emergency number (112/911/110 etc.)
- Nearest hospital / clinic to the current hotel
- Embassy contact for each member's nationality
Members fill this in during planning; it's readable offline.

### Quick Expense Entry
A floating action button or gesture on the home screen that opens the Add Receipt sheet directly, pre-filled with today's date. Reduces the tap count from 4 (More → Money → Receipts → Add) to 1.

### Spending vs Budget Live Progress
Once Budget Planner (above) is built: a progress bar on the home screen's balance card showing how much of the total budget has been spent.

### "Share Trip Info" Read-Only Link
Generate a public, read-only URL for the trip that non-members can view: spots (as a map), itinerary, and group info. Useful for sharing plans with people who aren't joining the app. Needs a public Supabase RLS policy and a simple web view.

### Offline Snapshot
Before the trip, tap "Download for offline" to cache all trip data to local storage. When there's no connection (common in transit), the app shows cached spots, plan, stays, docs, and money. Changes made offline queue up and sync when back online. Needs a local SQLite or Hive store plus a sync queue (scaffold already exists in `lib/core/sync_queue.dart`).

### Group Spend Summary (by member)
A "per person" breakdown on the Money screen alongside the category breakdown: total paid by each member, their fair share, and net owed. Currently the balance card shows debts but not a full per-person spending picture.

---

## Group Coordination

### In-App Notifications / Push
When a member adds a new spot, marks a plan item done, or logs a receipt, other members get a push notification. Needs FCM setup + a Supabase Edge Function to trigger on DB insert. Currently only in-app realtime exists.

### Plan Item Comments
Members can leave short comments on any plan item (e.g., "I found a better time slot for this"). A `itinerary_item_comments` table + a comments thread in the item detail sheet.

### Spot Voting Overhaul
Currently spots have must-do votes. Extend to a full ranking: each member rates a spot 1–5; the average is shown on the spot card. Could replace or complement the current binary vote.

### Group Chat
A simple per-trip chat (realtime via Supabase Realtime) for quick coordination. This is the biggest scope item — consider just linking to a WhatsApp or Telegram group instead (a "Group chat" link stored on the trip).

---

## Technical Debt / Infrastructure

### Service `_fmtDate` → `isoDate` consolidation
The 4 service files (`plan_service`, `travel_service`, `money_service`, `trip_service`) each have a private `_fmtDate(DateTime) => 'yyyy-MM-dd'` method. Move to a shared `isoDate(DateTime)` in `date_utils.dart` to complement the display `fmtDate`.

### Android Home Screen Widget
A simple 2×2 widget showing today's plan items and the balance card. Requires `android/app/src/main/...` native code and the `home_widget` Flutter package.

### Takeout Import Progress Screen
When importing a large Takeout CSV (100+ places), the current flow blocks the UI. Move geocoding to a background isolate with a live progress screen.
