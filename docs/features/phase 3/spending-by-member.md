# Spending by Member Card

**Build 57**

## What it does

Adds a "Spending by member" summary card on the Receipts tab of the Money screen, immediately below the existing "Spending by category" card.

Each row shows:
- Member's initials in a small circle avatar
- Member's display name
- Total amount they paid (in home currency)
- A proportional mini bar

The card auto-hides when all receipts were paid by the same person — no noise when solo-tracking.

## Where it appears

- Mobile: Receipts tab, above the filter strip
- Desktop: Left panel receipts list, above the filter strip

## Files changed

- `lib/screens/money_screen.dart` — `_SpendingByMemberCard` class + two call sites
