# Web Build Fix (W1)

## What changed

Flutter web build was blocked by two Android-only imports. Fixed using Dart's conditional export pattern so each platform compiles only the code it needs.

## Changes

### `lib/core/share/share_handler.dart`
Now a conditional export:
- Native (Android/iOS): `share_handler_native.dart` — full `receive_sharing_intent` implementation
- Web: `share_handler_web.dart` — stub with `pending = null`, no-op `init()`/`consume()`

### `lib/core/platform/platform_file.dart`
New conditional export for reading file bytes:
- Native: `platform_file_io.dart` — uses `dart:io` `File(path).readAsBytes()`
- Web: `platform_file_web.dart` — returns `Uint8List(0)` (unreachable on web)

### `lib/screens/share/incoming_share_screen.dart`
Replaced `import 'dart:io'` + `File(path).readAsBytes()` with `readFileAsBytes(path)` from the platform helper.

## Result

`flutter build web --dart-define-from-file=.env` compiles cleanly. Output at `build/web/`.
