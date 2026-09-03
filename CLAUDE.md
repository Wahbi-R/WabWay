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

## TripState / ProfileState in routes

These InheritedWidgets are not available inside a pushed `MaterialPageRoute`. Pass required data as explicit constructor parameters instead.

## Before creating anything new — check for an existing equivalent

Before writing a new helper, widget, service method, mixin, or pattern, grep for it first. If something equivalent already exists, extend or reuse it. If it's close but not quite right, generalise the existing thing rather than duplicating it.

Concrete checks before creating:
- **New screen state pattern** → does `AsyncScreenMixin` already cover it?
- **New service call** → does `*Service` already have this method under a different name?
- **New widget** → check `lib/widgets/` and nearby screens for the same UI element.
- **New utility function** → grep the function body's core logic; it may already exist.

Duplicating something means every future bug-fix or improvement has to be applied in two places. The rule: if you would write `// same as X but with Y changed`, that's a signal to parameterise X, not copy it.

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
