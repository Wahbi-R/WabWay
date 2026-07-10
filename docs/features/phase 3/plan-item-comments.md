# Plan Item Comments

**Build:** 70  
**Area:** Plan

## What it does

Trip members can leave short notes on any itinerary item — useful for updates
like "restaurant is closed Mondays", "parking at the east entrance", or "bring
an umbrella". Comments appear at the bottom of every plan item detail view.

## User-facing changes

- **Comments section** at the bottom of every plan item detail screen (mobile
  and desktop).
- Avatar + name + timestamp shown per comment (same style as spot comments).
- "Add a note for the group…" input with a send button.
- Comment count badge next to the "Comments" heading.
- Empty state: "No comments yet. Leave a note for the group."

## Implementation

| Layer | Change |
|---|---|
| Supabase | Migration `015_itinerary_item_comments.sql` — new `itinerary_item_comments` table with `id`, `item_id`, `author_id`, `body`, `created_at`; RLS: members can read/insert, authors can delete own |
| `lib/data/plan_data.dart` | Added `ItineraryItemComment` model with `fromMap` factory |
| `lib/core/supabase/plan_service.dart` | Added `fetchComments(itemId)`, `addComment(itemId, authorId, body)`, `deleteComment(commentId)` |
| `lib/screens/plan/item_detail.dart` | Converted `ItemDetailContent` from `StatelessWidget` to `StatefulWidget`; loads comments on init; `_submitComment()` optimistically adds to list; `_ItemCommentRow` + `_ItemCommentInput` widgets added at bottom of file |

## Notes

- Comments load on item open (no realtime subscription — low-frequency usage).
- `fmtCommentTime` reused from `spot_data.dart` for consistent relative timestamps.
- Delete is service-only for now; UI delete option is a follow-up.
