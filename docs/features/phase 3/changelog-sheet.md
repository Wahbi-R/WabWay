# Changelog Sheet

## Overview
A "What's new" bottom sheet that auto-shows once when the user upgrades to a new build, and is accessible at any time from More → What's new. Shows the last ~10 releases with bullet-point summaries.

## Entry Points
- **Auto-show on upgrade** — triggered in `AppShell.initState` via a `postFrameCallback`; shows 600ms after the shell finishes building, but only if the build number increased since last launch
- **More screen** — "What's new" row (with `Icons.new_releases_rounded`) always opens the sheet regardless of upgrade status

## Logic: `ChangelogService` (`lib/core/changelog.dart`)

### `checkIfUpgraded()`
- Reads `PackageInfo.buildNumber` via `package_info_plus`
- Compares to `SharedPreferences` key `last_seen_build` (int)
- If current build > stored build: writes new build number, returns `true`
- Returns `false` if build hasn't changed (prevents re-showing on same build)

### `maybeShowOnLaunch(BuildContext context)`
- Called from `AppShell.initState` postFrameCallback
- Awaits `checkIfUpgraded()`; if `true`, waits 600ms then calls `show()`

### `show(BuildContext context, {bool forceShow})`
- `showModalBottomSheet` with `isScrollControlled: true`
- `forceShow: true` skips the upgrade check (used by the More screen row)

## UI: `_ChangelogSheet`
- `DraggableScrollableSheet` — `initialChildSize: 0.75`, `maxChildSize: 0.95`
- Header: icon, "What's new" title, close button
- `ListView.separated` of `_ReleaseBlock` widgets (max 10 entries)

## `_ReleaseBlock`
Each release shows:
- Version + build number in overline style, with an orange "Latest" badge on the first entry
- Bold release label (e.g. "Google Maps import & spot photos")
- Bullet list — small colored circle dot + body text per change

## Changelog data (`_kChangelog`)
Const list of `_Release` objects at the top of `changelog.dart`. Add newest entry at the top. Each `_Release` has:
- `version` — semver string
- `build` — int matching `pubspec.yaml` build number
- `label` — one-line title for the release
- `changes` — `List<String>` bullet points

## Build number convention
The changelog triggers on `build` number increase. Every release that deserves a changelog entry should bump the build number in `pubspec.yaml` (the `+N` suffix). Bumping only the semver without incrementing build number will not show the sheet.

## Dependencies
- `package_info_plus` — already in `pubspec.yaml`
- `shared_preferences` — already in `pubspec.yaml`

## Supabase requirements
None.
