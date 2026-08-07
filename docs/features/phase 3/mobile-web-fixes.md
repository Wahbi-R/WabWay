# Mobile Web Fixes (Build 107)

Three issues affected wabway.wabble.ca on Android Chrome.

## Loading screen (grey screen while Flutter initialises)

**Problem:** The page was blank grey for 3–5 seconds before Flutter rendered.

**Fix:** `web/index.html` — added `#flutter-loading` div with the app icon and a CSS spinner. The `flutter-first-frame` DOM event removes it with a 0.4s fade once Flutter has rendered. Background is cream (`#FFFDF8`) so nothing grey shows through.

## Viewport meta tag

**Problem:** Mobile Chrome defaulted to a 980px desktop layout and scaled it down, causing CanvasKit canvas sizing issues.

**Fix:** Added `<meta name="viewport" content="width=device-width, initial-scale=1.0">` to `web/index.html`.

## CanvasKit background + engine error handling

**Problem:** The WebGL canvas and surrounding Flutter DOM elements had no background colour, so any rendering gap showed the browser's default grey.

**Fix:** Custom `web/flutter_bootstrap.js` injects CSS `flutter-view, flt-glass-pane { background: #F8F3EA }` before the engine loads, so the cream colour shows even if CanvasKit takes a moment. If the engine throws during init, a human-readable error card is shown with a Refresh button instead of a silent grey screen.

## Keyboard Search key race condition

**Problem:** On mobile, pressing Search on the keyboard closed the keyboard (triggering a focus-loss event) before the search results were ready. `_onFocusChange` hid the results dropdown immediately, making it look like search did nothing.

**Fix:** `lib/widgets/place_search_field.dart` — added `bool _suppressHide = false;` set **synchronously** at the top of `_search()`, before the first `await`. Since Dart is single-threaded, the flag is guaranteed to be `true` when the focus-loss event fires, so `_onFocusChange` skips hiding the results. The flag is cleared just before the final `setState` that shows results.
