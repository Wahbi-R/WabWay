# Link Editing (Build 86)

## What

Saved links can now be edited after creation. Each link card shows a three-dot kebab menu with three actions: **Open**, **Edit**, and **Delete**. Tapping Edit opens the existing add-link sheet pre-filled with the link's current title, URL, category, and notes.

## Why

Users previously had to delete a link and re-add it to fix a typo in the title or change the category after auto-detection got it wrong. There was no recovery path short of deleting and re-creating.

## How it works

### `LinksService.updateLink` (new)

```dart
static Future<TripLink> updateLink(
  String linkId, {
  required String title,
  required String url,
  required LinkCategory category,
  String? notes,
}) async {
  final row = await supabase
      .from('trip_links')
      .update({ ... })
      .eq('id', linkId)
      .select()
      .single();
  return _fromRow(row);
}
```

Sets `notes` to `null` in the DB when the field is empty (clearing a previously-set note is supported).

### `showAddLinkSheet` — edit mode

Added an optional `TripLink? existing` parameter. When set:

- Sheet title: "Edit link"
- Submit button: "Save changes" with a check icon
- All fields pre-filled from the existing link (`url`, `title`, `category`, `notes`)
- URL listener still fires (auto-detect category on change) but title auto-fill only fires when title is empty, so pre-filled title is preserved
- Submit calls `LinksService.updateLink` instead of `createLink`
- Return type is still `TripLink?` — the same function returns both new and updated links

### `_LinkCard` — popup menu

Replaced the column of static icons (open + delete) with a `PopupMenuButton<_LinkAction>` kebab menu:

```
• Open
• Edit
• Delete  (red)
```

`onEdit` and `onDelete` callbacks passed from `_LinksScreenState`.

### `_LinksScreenState._editLink`

```dart
Future<void> _editLink(TripLink link) async {
  final updated = await showAddLinkSheet(
    context,
    tripId: _activeTripId!,
    userId: userId,
    existing: link,
  );
  if (updated != null && mounted) {
    setState(() {
      final idx = _links.indexWhere((l) => l.id == updated.id);
      if (idx >= 0) _links[idx] = updated;
    });
  }
}
```

Optimistic-style: the updated link replaces the old one in `_links` on success. The realtime channel will also fire and reload, but the optimistic update means no flicker.

## Files changed

- `lib/core/supabase/links_service.dart` — `updateLink` method
- `lib/screens/links/add_link_sheet.dart` — `existing` param, edit mode labels, `_submit` branching
- `lib/screens/links_screen.dart` — `_editLink`, `_LinkCard.onEdit`, kebab menu
