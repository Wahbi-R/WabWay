# Loading Widgets — WabwayLoadingScaffold & WabwayLoadingIndicator

**Build 54**

## What it does

Replaces 8 copy-pasted 12-line loading blocks (one per data screen) with two shared widgets:

- **`WabwayLoadingScaffold`** — full-screen Scaffold with centered spinner; used via `if (_loading) return const WabwayLoadingScaffold();` as an early return
- **`WabwayLoadingIndicator`** — bare centered spinner with no Scaffold wrapping; used inline as a body expression when the screen keeps its AppBar visible during load

## Screens updated

| Screen | Pattern |
|---|---|
| `money_screen.dart` | early return |
| `spots_screen.dart` | early return |
| `accommodations_screen.dart` | early return |
| `docs_screen.dart` | early return |
| `travel_screen.dart` | early return |
| `links_screen.dart` | inline body |
| `photos_screen.dart` | inline body |
| `plan_screen.dart` | inline body |

## Files

- `lib/widgets/wabway_loading_scaffold.dart` — both widgets defined here
- `lib/widgets/widgets.dart` — both re-exported

## Why two widgets

Some screens keep their AppBar visible during loading (body-expression pattern); others hide everything behind a full Scaffold. Using `WabwayLoadingScaffold` as a body expression would cause a nested-Scaffold layout warning, so the bare `WabwayLoadingIndicator` handles the inline case.
