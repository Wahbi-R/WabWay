# App Icon

## Overview
WabWay uses a custom icon generated from the WabWay logo assets via `flutter_launcher_icons`.

## Assets (`assets/icon/`)
| File | Purpose |
|---|---|
| `wabway_app_icon_1024.png` | Main launcher icon (1024×1024) |
| `wabway_adaptive_foreground_432.png` | Android adaptive icon foreground layer (432×432) |
| `wabway_logo_emblem_transparent.png` | Transparent emblem for in-app use |

## Configuration (`pubspec.yaml`)
```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/wabway_app_icon_1024.png"
  adaptive_icon_background: "#F8F3EA"   # kColorCream
  adaptive_icon_foreground: "assets/icon/wabway_adaptive_foreground_432.png"
  min_sdk_android: 23
  web:
    generate: true
    image_path: "assets/icon/wabway_app_icon_1024.png"
    background_color: "#F8F3EA"
    theme_color: "#C96F4A"
```

## Regeneration
```bash
flutter pub run flutter_launcher_icons
flutter build apk --debug --dart-define-from-file=.env
```

## Web icons
`web/favicon.png`, `web/icons/Icon-192.png`, and `web/icons/Icon-512.png` are also updated from the same source assets.
