# WabWay — Claude instructions

## After every commit (features AND bug fixes)

1. **Update `docs/TODO.md`** — add a checked `[x]` item with date and build number.
2. **Update `lib/core/changelog.dart`** — add a new `_Release(...)` entry at the **very top** of `_kChangelog` (newest first). Match the label and build number to the TODO entry. Write the bullet points from a user's perspective (what they can now do), not an implementation perspective. This applies to every commit — bug fixes, UX improvements, and refactors all get an entry.
3. **Write a feature doc** in `docs/features/phase 3/<slug>.md` for non-trivial features.
4. **Run `supabase db push`** (or apply via SQL Editor) for any new migrations.

## Build numbering

Build numbers in TODO.md, changelog.dart, and commit messages are sequential human-assigned labels (100, 101, 102 …), **not** the pubspec `version` build number or the GitHub run number. Always check the highest existing build in TODO.md and increment by 1.

## Migration rule

Use `supabase db push` for migrations. If there is a duplicate migration prefix conflict, apply via the Supabase SQL Editor and rename the file to avoid the duplicate.

## Git

- **Never push to remote** after committing — only push when the user explicitly asks.
- **Push to wabway-server** immediately after every commit to the `wabway-server/` sub-repo, no need to ask.
- Build command: `flutter build apk --debug --dart-define-from-file=.env` (omitting `.env` causes a black screen on launch).

## wabway-server feature tracking

Before every commit+push to `wabway-server/`, update `wabway-server/FEATURES.md`:
- Add a dated section at the top describing what the commit adds or changes.
- Keep entries brief but endpoint-specific (what the endpoint does, what changed).
- This file is served by the `/version` endpoint so the user can check what's live on the phone vs what's on GitHub.

## Reading the active trip / profile

Use the Riverpod providers: `ref.read(activeTripProvider)`, `tripMembersProvider`, `profileProvider`, `isOrganiserProvider`. They work everywhere, including pushed `MaterialPageRoute`s. The old `TripState` / `ProfileState` InheritedWidgets were never provided in the tree (every `maybeOf` returned null and silently broke "Add all trip days" and day defaults) and were deleted in build 416 — don't reintroduce them.

## Before creating anything new — check for an existing equivalent

Before writing a new helper, widget, service method, mixin, or pattern, grep for it first. If something equivalent already exists, extend or reuse it. If it's close but not quite right, generalise the existing thing rather than duplicating it.

Concrete checks before creating:
- **New screen state pattern** → does `AsyncScreenMixin` already cover it?
- **New service call** → does `*Service` already have this method under a different name?
- **New widget** → check `lib/widgets/` and nearby screens for the same UI element.
- **New utility function** → grep the function body's core logic; it may already exist.

Duplicating something means every future bug-fix or improvement has to be applied in two places. The rule: if you would write `// same as X but with Y changed`, that's a signal to parameterise X, not copy it.

## Canonical components — use these, never re-implement

The app's main UX debt came from the same element being rebuilt per screen (6 confirm dialogs, 5 date fields, 7 initials functions, an Import flow that re-coded every Add form). **A private `_DateField` / `_snack` / `_confirmDelete` dialog body / `_EmptyState` / hand-rolled initials / `showModalBottomSheet(DraggableScrollableSheet…)` form in a screen is a bug.** Use the canonical piece below; if it doesn't fit, add a parameter to it.

| Element | Use | File |
|---|---|---|
| Buttons | `WabwayButton` — `primary` (orange CTA), `secondary`, `ghost`, `dangerOutline` (delete in panels/forms), `danger` (filled, only inside confirm dialogs) | `lib/widgets/wabway_button.dart` |
| Delete / confirm | `showWabwayDeleteConfirm(entity:, name:)`, `showWabwayConfirm(...)` | `lib/widgets/wabway_confirm_dialog.dart` |
| Single-field prompt (rename, quick add) | `showWabwayTextPrompt` | `lib/widgets/wabway_confirm_dialog.dart` |
| Toast / feedback | `showWabwaySnack(context, msg, error:)` | `lib/widgets/wabway_snack.dart` |
| Create/edit form presentation | `showWabwayFormSheet` (draggable) / `showWabwayAutoSheet` (content-sized) — dialog on desktop, sheet + drag handle on mobile | `lib/widgets/wabway_form_sheet.dart` |
| Date / time / range field | `WabwayDateField`, `WabwayTimeField`, `WabwayPickerField` (custom picker e.g. ranges) | `lib/widgets/wabway_date_field.dart` |
| Date formatting | `fmtDate`, `fmtDateLong`, `fmtDateRange`, `fmtTimeOfDay`, `isoDate` | `lib/data/date_utils.dart` |
| Short fixed choice (status/category/type) | `WabwayChoiceChips` | `lib/widgets/wabway_choice_chips.dart` |
| Long/open choice | `WabwaySelectField` | `lib/widgets/wabway_select_field.dart` |
| List filter chips with counts | `WabwayFilterStrip` | `lib/widgets/wabway_filter_strip.dart` |
| Search box | `WabwaySearchBar` + `foldForSearch` / `searchMatches` (diacritic-insensitive) | `lib/widgets/wabway_search_bar.dart`, `lib/core/text_utils.dart` |
| Avatars / initials | `WabwayAvatar(name: realName)`, `initialsFor`, `avatarColorFor` — never pass `'You'` as the name | `lib/widgets/wabway_avatar.dart` |
| Plurals | `pluralize(n, 'day')` | `lib/core/text_utils.dart` |
| Empty state | `WabwayEmptyState(action: WabwayButton(...))` | `lib/widgets/wabway_empty_state.dart` |
| Status badge | `WabwayBadge` | `lib/widgets/wabway_badge.dart` |
| Place / address input | `PlaceSearchField` (returns name, address, city, area, coords, category) | `lib/widgets/place_search_field.dart` |
| Attach docs to an item (detail screens) | `AttachedDocsSection(entityType:, entityId:, tripId:, entityName:, uploadType:)` — upload / Library / paste link / photo; stored via `DocService.attach/detach` (`trip_connections`) | `lib/screens/shared/attached_docs_section.dart` |
| Pick docs inside a create form | `DocMultiPicker`, then `DocService.attach` after save | `lib/widgets/doc_multi_picker.dart` |
| Link any two entities | `ConnectionsSection` + `ConnectionService` (`trip_connections`) | `lib/screens/shared/connections_section.dart` |
| Organiser / edit permission | `isOrganiserProvider`, `canManageItem(createdById, isOrganiser:)` | `lib/core/providers/trip_provider.dart` |
| Trip delete / leave / remove member | `confirmDeleteTrip`, `confirmLeaveTrip`, `confirmRemoveMember` | `lib/screens/trips/trip_actions.dart` |

Entity Add sheets (`showAddSpotSheet`, `showAddTravelSheet`, `showAddLinkSheet`, `showAddStaySheet`, …) are the ONLY create forms for their entity — other flows (Import, quick-add, search) must call them with prefill values, never rebuild the fields.

## Async screen state — use AsyncScreenMixin

Every `State` (or `ConsumerState`) that loads data asynchronously **must** use `AsyncScreenMixin` from `lib/core/async_screen_mixin.dart`. Never declare `_loadGen`, `_loading`, `_error`, or `_offline` fields directly on a screen — the mixin provides them.

```dart
import '../core/async_screen_mixin.dart';

class _MyScreenState extends ConsumerState<MyScreen> with AsyncScreenMixin {
  List<Item> _items = [];

  Future<void> _load({bool silent = false}) async {
    final gen = beginLoad(silent: silent);
    try {
      final items = await ItemService.load(widget.tripId);
      commitLoad(gen, () => _items = items);
    } catch (_) {
      failLoad(gen, silent: silent);
    }
  }
}
```

**Cache-first pattern** (show cached data while network refreshes):
```dart
final gen = beginLoad(silent: silent);
try {
  final cached = await Cache.read(...);
  if (!isStale(gen)) setState(() { _items = cached; _loading = false; });
  final fresh = await Service.load(...);
  commitLoad(gen, () => _items = fresh);
} catch (_) {
  failLoad(gen, silent: silent);
}
```

**Why:** Copy-pasting `_loadGen` + mounted checks across every screen was the source of 20+ bugs (stale loads overwriting fresh data, spinners stuck, error banners not clearing after success). The mixin makes the correct pattern the only pattern.
