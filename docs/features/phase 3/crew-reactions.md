# Crew Chat: Emoji Reactions (Build 121)

## What it does

Users can react to any text message in the crew chat with an emoji. Long-pressing a bubble opens a compact picker with six emoji choices. Tapping a reaction pill toggles your own reaction. Counts update in real time across all devices.

## Emoji options

❤️  👍  😂  😮  😢  🔥

## Interaction

- **Long-press** a message bubble → emoji picker sheet slides up
- **Tap an emoji** in the picker → adds your reaction and closes the picker
- **Tap an existing reaction pill** below the bubble → toggles (adds if absent, removes if present)
- **Highlighted** pills (primary soft background + border) show which emojis you've already reacted with

## Architecture

- **DB**: new `message_reactions` table (`id`, `message_id`, `user_id`, `emoji`, `created_at`) with a unique constraint on `(message_id, user_id, emoji)`; RLS policies restrict read/write to trip members and delete to the reaction's own user
- **Migration**: `023_message_reactions.sql` applied via `supabase db push`
- **Service**: `CrewService.addReaction / removeReaction`; `fetchMessages` now selects `*, message_reactions(*)` so reactions arrive bundled with each message
- **Realtime**: existing `subscribeMessages` channel extended with an `onPostgresChanges` listener on `message_reactions` so counts refresh without polling
- **Data model**: `TripMessage.reactions: Map<String, List<String>>` (emoji → list of userIds); populated in `fromMap` from the embedded join

## Files changed
- `supabase/migrations/023_message_reactions.sql`
- `lib/data/crew_data.dart`
- `lib/core/supabase/crew_service.dart`
- `lib/screens/crew_screen.dart` — `_MessageBubble`, `_ReactionRow`, `_EmojiPickerSheet`
