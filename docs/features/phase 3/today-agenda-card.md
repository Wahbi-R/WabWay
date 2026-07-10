# Today's Agenda Card

**Build 59**

## What it does

When today's date matches a plan day, the home screen shows a "Today" card instead of the "Coming up" single-item card. The Today card displays:

- Day number, city, and date header
- All plan items for today in order, each with:
  - Type icon (colored, same as plan screen)
  - Title with strikethrough when done
  - Time and city subtitle if available
  - Green checkmark icon when the item is done
- A "X/Y done" counter in the header (turns green when all items are done)

If today has no plan day (or no items), the card is omitted and the next upcoming day falls through to the existing "Coming up" card.

## How it connects

- Reads `data.todayDay` (new getter on `_HomeData`) — returns the plan day whose date exactly matches today
- Items show `isDone` state but tapping them doesn't toggle here; that stays on the Plan screen (single responsibility)
- No backend calls — data already loaded in the home screen's 7-source `Future.wait`

## Files changed

- `lib/screens/home_screen.dart` — `todayDay` getter on `_HomeData`, `_TodayAgendaCard` widget, updated `build()` routing
