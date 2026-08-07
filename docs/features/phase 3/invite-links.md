# Invite Links (Build 116)

## What it does

Invite codes can now be shared as a full URL (`https://wabway.wabble.ca/?invite=CODE`). Anyone who taps the link is taken directly into the join flow with the code pre-filled — no manual typing required.

Works for both existing app users and new users who need to sign up first.

## Share link button

The Invite Codes sheet (`invite_sheet.dart`) now shows two buttons on each active code card:

- **Copy code** — copies the raw code (unchanged)
- **Share link** — opens the native share sheet with a pre-composed message containing the full link and the fallback code

## Flow for new users (web → sign up → join)

1. User receives the link and opens it in a browser (or taps it on a device without the app).
2. The Flutter web app boots and `InviteLinkHandler.init()` reads `?invite=CODE` from `Uri.base.queryParameters`.
3. The code is saved to SharedPreferences as `pending_invite_code`.
4. After the user signs up and is authenticated, `TripGate._load()` calls `_maybeShowPendingInvite()`.
5. `JoinWithCodeSheet` opens with `initialCode` pre-filled. Submitting clears the persisted code.

## Flow for existing app users (Android deep link)

1. User taps the link on Android. The intent filter in `AndroidManifest.xml` (already registered for `wabway.wabble.ca`) matches.
2. `MainActivity` passes `intent.dataString` to Dart via the `ca.wabble.wabway/links` MethodChannel.
3. `InviteLinkHandler` parses the URL, extracts the `invite` query param, and stores it in `pendingCode`.
4. `TripGate` detects the pending code and shows `JoinWithCodeSheet` pre-filled.

> Note: without `.well-known/assetlinks.json` deployed on the domain, Android shows a disambiguation dialog before opening the app. The flow still works — Android App Links verified auto-open requires the JSON file.

## Android download banner

`AndroidDownloadBanner` (`lib/widgets/android_download_banner.dart`) is a thin dark bar shown at the bottom of the screen on web pages when the user-agent indicates Android (not iPhone, not desktop Windows/Mac).

- Shown on: `sign_in_screen.dart` and `home_screen.dart`
- Detected via `lib/core/platform/browser_detect.dart` (conditional export: web uses `dart:html` user-agent check; non-web stub always returns false)
- Dismissed state persisted in SharedPreferences (`android_banner_dismissed` key)
- Links to `https://github.com/Wahbi-R/WabWay/releases/latest`

## New files

| File | Purpose |
|------|---------|
| `lib/core/invite/invite_link_handler.dart` | Singleton; reads invite from URL/intent, persists, notifies |
| `lib/core/platform/browser_detect.dart` | Conditional export for `isAndroidBrowser` |
| `lib/core/platform/browser_detect_web.dart` | Web impl using `dart:html` user-agent |
| `lib/core/platform/browser_detect_stub.dart` | Non-web stub (always false) |
| `lib/widgets/android_download_banner.dart` | Android-browser download banner widget |

## Modified files

| File | Change |
|------|--------|
| `android/app/src/main/kotlin/.../MainActivity.kt` | Added `ca.wabble.wabway/links` MethodChannel; `getInitialLink` + `onNewIntent` handler |
| `lib/main.dart` | `await InviteLinkHandler.instance.init()` on startup |
| `lib/screens/members/invite_sheet.dart` | "Share link" button on active code cards |
| `lib/screens/trips/trip_gate.dart` | `_maybeShowPendingInvite()`, `JoinWithCodeSheet(initialCode:)` |
| `lib/screens/auth/sign_in_screen.dart` | `AndroidDownloadBanner` in bottomNavigationBar |
| `lib/screens/home_screen.dart` | `AndroidDownloadBanner` in bottomNavigationBar |
