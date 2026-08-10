# Riverpod Migration — Replace TripState/ProfileState InheritedWidgets

**Build:** 189  
**Date:** 2026-08-09

## What changed

All screens that previously consumed `TripState` or `ProfileState` InheritedWidgets were converted to use Riverpod providers. The two InheritedWidget classes remain in the tree (they are provided by `TripGate`/`AppShell`) but screens no longer call `TripState.of(context)` or `ProfileState.of(context)` inside pushed routes where those widgets are not in scope.

## Files converted

| File | Change |
|---|---|
| `lib/screens/spots/spot_detail.dart` | `_AddToPlanButton` → `ConsumerStatefulWidget` |
| `lib/screens/plan_screen.dart` | → `ConsumerStatefulWidget`; `ref.listen` on trip change |
| `lib/screens/travel_screen.dart` | → `ConsumerStatefulWidget` |
| `lib/screens/accommodations/accommodations_screen.dart` | → `ConsumerStatefulWidget` |
| `lib/screens/photos_screen.dart` | → `ConsumerStatefulWidget` |
| `lib/screens/packing_screen.dart` | → `ConsumerStatefulWidget`; `_PackingTile` → `ConsumerWidget` |
| `lib/screens/crew_screen.dart` | → `ConsumerStatefulWidget` |
| `lib/screens/money_screen.dart` | → `ConsumerStatefulWidget`; extracted `_rebuildMembers()` |
| `lib/screens/spots_screen.dart` | → `ConsumerStatefulWidget` |
| `lib/screens/docs_screen.dart` | → `ConsumerStatefulWidget`; extracted `_rebuildMemberName()` |
| `lib/screens/more_screen.dart` | `MoreScreen`/`_AccountSection` → `ConsumerWidget`; deleted `_pushWithState` |
| `lib/screens/home_screen.dart` | → `ConsumerStatefulWidget`; `_ActivityFeed.trip` → nullable |
| `lib/screens/placeholder_screen.dart` | Fixed `showEditNameSheet`/`showTripSettingsSheet` call signatures |
| `lib/screens/plan/item_detail.dart` | `ItemDetailScreen` → `ConsumerWidget`; `_ActionsSection` → `ConsumerStatefulWidget` |
| `lib/shell/app_shell.dart` | Fixed `showTripSwitcherSheet(context, ref)` call |

## Providers used

| Provider | Type | Purpose |
|---|---|---|
| `profileProvider` | `AppProfile?` | Current user's display name, avatar, id |
| `activeTripProvider` | `AppTrip?` | Active trip object (nullable) |
| `activeTripIdProvider` | `String` | Active trip ID string (non-nullable, `''` when none) |
| `tripMembersProvider` | `List<AppTripMember>` | All members of the active trip |
| `tripNotifierProvider` | `TripNotifier` | Notifier; call `.load()` to force a reload |

## Patterns used

- `didChangeDependencies` with `_loaded` guard → `initState` + `WidgetsBinding.instance.addPostFrameCallback`
- `ref.listen<String>(activeTripIdProvider, ...)` in `build` to react to trip switches
- Free functions that previously called `TripState.refresh(context)` now accept `VoidCallback onRefresh` and the call site passes `() => ref.read(tripNotifierProvider.notifier).load()`
- Sheet helpers (`showTripSettingsSheet`, `showTripSwitcherSheet`, `showEditNameSheet`, `showImportScreen`) all take `WidgetRef ref` as their second positional argument
- `showAddItemSheet` requires a `defaultCurrency` named parameter sourced from `ref.read(activeTripProvider)?.homeCurrency ?? ''`
