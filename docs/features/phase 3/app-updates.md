# In-app updates (Android)

**Build:** 433  
**Area:** Home / sign-in / trip picker banner, Settings → App, whole app

## Where updates download to

The APK goes to the app's **private cache**, `<cache>/updates/` (for example
`/data/user/0/ca.wabble.wabway/cache/updates/wabway-v1.1.0.190.apk`). The user
and other apps can't see it, and it never shows up in Downloads. It's
downloaded as `….apk.part` and renamed only when it's complete. Then it's
handed to Android's installer through the FileProvider (`res/xml` →
`cache-path`).

**Cleanup.** Every update check runs `ApkInstaller.cleanup(currentBuild)`. It
deletes downloaded APKs for the installed build or older (installed already,
or superseded), any unfinished `.part`, and the APKs older builds left
directly in the cache folder. An APK for a *newer* build is kept: if you back
out of the install prompt, **Download & install** reuses it instead of
downloading again. Cleanup is skipped while a download is running.

Before this build, APKs (~30–60 MB each) were saved straight into the cache
and never deleted. Android only removes cache files when storage runs low.

## When the update shows

- `UpdateChecker.check()` runs on launch **and whenever the app comes back to
  the foreground** (`UpdateGate` listens to the app lifecycle). Checks are at
  most every 30 minutes.
- **Settings → App → Check for updates** (Android release builds) shows
  "Version 1.1.0 (build 188)" and checks right away. If there's an update it
  opens the update card in a sheet; otherwise it says "You're on the latest
  version."
- The banner (Home, sign-in, trip picker) follows `UpdateChecker.latest`, so
  it appears as soon as any check finds a new build. Before, the result was
  cached for the whole process, so you had to close and reopen the app.
  Dismissing it hides that version for the session.

## Forcing an update (not every time)

Normal releases stay optional. To make everyone on an older build update:

- put **`[force update]`** in the **PR title** (the merge commit carries it)
  or a commit message pushed to `main`, **or**
- run **Build & Deploy** manually with **force_update = true**.

The workflow writes `<!-- min-build: N -->` (N = that build) into the GitHub
release notes. Later normal releases **carry the same minimum forward**, so
someone two releases behind is still caught. Anyone below N gets a
full-screen **Update required** screen over the whole app, with
Download & install and no ✕. It goes away once they're on N or newer.

## Implementation

| File | Change |
|---|---|
| `lib/core/update_checker.dart` | `UpdateInfo.fromRelease` (testable), `minBuild` / `isRequired`, `latest` notifier, 30-min throttle, `check(force:)`, `supported` |
| `lib/core/updater/apk_installer.dart` | `updates/` folder, `.part` then rename, reuse of a finished download, `cleanup` / `isStale` |
| `lib/widgets/update_checker_banner.dart` | Banner follows `latest`; shared `UpdateCard`; `UpdateGate` (lifecycle checks + blocking screen) |
| `lib/main.dart` | `MaterialApp.builder` wraps the app in `UpdateGate` |
| `lib/screens/shared/settings_sections.dart` | "Check for updates" row (`SettingsRow.subtitle` added) |
| `.github/workflows/build-and-deploy.yml` | `force_update` input, minimum-build step, `<!-- min-build -->` in the release body |

Tests: `test/update_checker_test.dart`.
