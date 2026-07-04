# WabWay QA Checklist

Smoke tests to run before each release. Use a dedicated test trip so you don't pollute real trip data.

---

## Setup: Create a safe test trip

1. Sign in on two separate devices / browser sessions (use two real email addresses — e.g. `test-a@…` and `test-b@…`).
2. Create a new trip on device A: "QA Test Trip".
3. Generate an invite link and join on device B.
4. Run all tests, then delete or archive the test trip when done.

---

## 1. Auth flow

- [ ] Magic link email arrives within ~30 seconds.
- [ ] Clicking magic link on Android opens the app directly (App Links), not the browser.
- [ ] Clicking magic link on the web signs in to the web app.
- [ ] Sign out and sign back in with password (if set).
- [ ] "Forgot password" sends a reset email.

## 2. Invite & trip switcher

- [ ] Invite code displayed in More → Invite Friends.
- [ ] Device B joins using the invite link.
- [ ] Device A sees B in the Members list immediately (Realtime).
- [ ] Owner can remove a member; removed member's session ends or loses access on next reload.
- [ ] Generate new invite code → old code stops working.
- [ ] Multi-trip: create a second trip, switch between trips in More → Switch Trip.

## 3. Spots (two-device test)

- [ ] Add a spot on device A → appears on device B within 5 seconds (Realtime).
- [ ] Search: type a place name → Photon API results appear within 1 second.
- [ ] Vote Must-do on device A → vote count updates on device B.
- [ ] Edit spot → changes reflected on both devices.
- [ ] Confirm a spot (status = Confirmed) → green badge + green map pin.
- [ ] Map screen shows spots with correct status colours.
- [ ] Filter by status → only matching spots shown; badge shows count.
- [ ] Unplanned Spots section in Plan screen shows confirmed/planned spots not yet on a day.

## 4. Plan (two-device test)

- [ ] Add a day on device A → appears on device B.
- [ ] Add an item from the Unplanned Spots section → spot disappears from unplanned list.
- [ ] Drag item to reorder within a day → order persists after reload.
- [ ] Move item to another day → item moves, no duplicate.
- [ ] Export plan → system share sheet appears with text itinerary.
- [ ] Edit a day → city/date/notes update reflected.

## 5. Money (two-device test)

- [ ] Add receipt (payer = device A user, split 50/50) on device A → appears on device B.
- [ ] Settle Up: balance correct for single currency.
- [ ] Add a receipt in a second currency → Settle Up shows two separate currency sections.
- [ ] Mark a settlement as paid → suggestion shows as settled.
- [ ] Add cash withdrawal and verify balance change.

## 6. Documents

- [ ] Upload a PDF → appears in Documents list.
- [ ] Open document → viewer opens.
- [ ] Share document → system share sheet opens with a signed URL.
- [ ] Upload via Android share intent (share a PDF from Files app to WabWay).
- [ ] Offline: disable Wi-Fi, open Docs → last-loaded list still visible with offline banner.

## 7. Travel

- [ ] Add a flight booking → appears in Travel list.
- [ ] Edit booking → status badge updates.
- [ ] Link a document to a travel item.

## 8. Links

- [ ] Add a URL link → appears in Links list with correct favicon/category.
- [ ] Open link → browser launches.
- [ ] Add a Google Maps link → coordinates extracted, map link opens correctly.

## 9. Global search

- [ ] Type a spot name in Home search → result appears under Spots category.
- [ ] Type a document title → result appears under Documents.

## 10. Onboarding

- [ ] Delete app data or use a fresh account → onboarding slides appear on first launch.
- [ ] Tapping Skip closes onboarding; onboarding does not reappear on next launch.
- [ ] Tapping Get Started closes onboarding.

## 11. Notifications

- [ ] More → Notifications → toggle settings appear and persist.

## 12. Diagnostics

- [ ] More → Debug → Diagnostics → Supabase connection shows "Connected ✓".
- [ ] App version displayed matches `pubspec.yaml` version.

## 13. Web build

- [ ] `flutter build web` completes without errors.
- [ ] Web app loads at `https://wabway.wabble.ca`.
- [ ] Sign in via web → home screen loads with trip data.
- [ ] File upload works from web browser.

---

## How to reset test data

Run in Supabase SQL Editor (replace `'QA Test Trip'` with your test trip name):

```sql
DELETE FROM trips WHERE name = 'QA Test Trip';
```

Cascading deletes on `trip_id` foreign keys will clean up related rows.
