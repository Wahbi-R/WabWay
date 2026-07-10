# Today's Agenda Card — Inline Done Toggle

**Build 65**

## What it does

The Today's Agenda Card on the home screen now lets you tap any item to toggle it done/undone without navigating to the Plan screen. This is the key on-the-go use case: quickly mark items as you complete them throughout the day.

- Tap the item row (anywhere, or the icon) to toggle done/undone
- Optimistic update: the UI responds instantly; the backend call happens in the background
- Rollback on error: if the network call fails, the toggle reverts
- Done counter ("2/5 done") updates immediately
- Strikethrough and dimmed text on done items, green check icon replacing the type icon

## How it connects

- `lib/screens/home_screen.dart` — `_TodayAgendaCard` converted from `StatelessWidget` to `StatefulWidget`; `_doneOverride` map holds local overrides; `_toggle()` calls `PlanService.toggleDone` with rollback on error; `_isDone()` resolves from override-first then model state

## Files changed

- `lib/screens/home_screen.dart` — `_TodayAgendaCard` → `StatefulWidget` with `_TodayAgendaCardState`
