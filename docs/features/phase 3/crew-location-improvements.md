# Crew Location Improvements (Build 108)

## Background location sharing

**Problem:** Location sharing used `Timer.periodic(10s)` which is paused by the OS the moment the app moves to the background.

**Fix:** Replaced with `Geolocator.getPositionStream()` with `AndroidSettings(foregroundNotificationConfig: ...)`. This starts an Android foreground service that keeps the location subscription alive even when the user switches apps or locks the screen. A persistent notification ("WabWay location sharing — Sharing your location with your crew") is shown while active, which is required by Android for foreground services.

**AndroidManifest changes:**
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<service
    android:name="com.baseflow.geolocator.GeolocatorForegroundService"
    android:foregroundServiceType="location"
    android:exported="false"/>
```

**Platform handling (`_buildLocationSettings`):**
- Web: base `LocationSettings`
- Android: `AndroidSettings` with `intervalDuration: 10s` and `foregroundNotificationConfig`
- iOS/macOS: `AppleSettings` with `pauseLocationUpdatesAutomatically: false` (foreground-only for now)

## Navigate to crew member

Tapping a crew member's marker on the Live Map tab now opens a bottom sheet showing the member's name, last-updated time, and a "Navigate to [name]" button. Tapping the button launches the device's native maps app via a `geo:{lat},{lng}?q={lat},{lng}({name})` URI. If `geo:` is not available (e.g. emulators without Google Maps), falls back to `maps.google.com/?q=...`.

Your own marker has no tap target (no point navigating to yourself).

## Notes

- Location pings in chat (📍 button → "Linked up" card with "Navigate" button) were already implemented; unchanged.
- iOS background location (`allowBackgroundLocationUpdates: true`) requires `NSLocationAlwaysUsageDescription` in Info.plist and an explicit `always` permission request — deferred for a future build.
