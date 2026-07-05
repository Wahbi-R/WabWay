# Document Share

## Description

Documents can be shared directly from the doc detail screen using `share_plus`. File documents get a short-lived signed URL from Supabase Storage; link documents use their stored URL. Sharing is disabled on web (shows a snackbar instead).

## Key Files

- `lib/screens/docs/doc_detail.dart` — "Share" action button and `_shareDoc()` method
- `lib/core/supabase/doc_service.dart` — `getSignedUrl(path, expiresIn: 3600)`
- `pubspec.yaml` — `share_plus` dependency

## How It Works

1. User taps the Share icon in the doc detail AppBar or actions menu.
2. If `kIsWeb`, a snackbar is shown ("Sharing not supported on web").
3. For file docs (`storagePath != null`): `DocService.getSignedUrl()` requests a 1-hour signed URL from the `trip-documents` bucket. The URL is passed to `Share.shareUri()`.
4. For link docs (`ext == 'url'` and `notes` contains the URL): the notes URL is shared directly via `Share.share()`.
5. `share_plus` triggers the OS share sheet (Android share dialog, iOS share sheet).
