import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'location_sharing_manager.dart';

/// Makes sure the app may read the location, asking for permission (and
/// opening the OS settings when it's off or denied forever). [onError] gets a
/// user-facing message. Shared by Crew (Link Up, Find Me, live sharing) and
/// Nearby.
Future<bool> ensureLocationPermission({void Function(String message)? onError}) async {
  try {
    if (kIsWeb) {
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      return true;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      onError?.call('Location services are off — enable them in Settings');
      await Geolocator.openLocationSettings();
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  } catch (_) {
    onError?.call('Could not access location');
    return false;
  }
}

/// Current position with layered fallbacks (fastest first):
/// 1. The live-sharing stream's last fix (instant)
/// 2. The OS's last-known position, unless older than [maxAge]
/// 3. A one-shot medium-accuracy request (15 s — works on Wi-Fi/network)
Future<Position> currentPosition({Duration? maxAge}) async {
  final cached = LocationSharingManager.instance.lastPosition;
  if (cached != null && _fresh(cached, maxAge)) return cached;

  final last = await Geolocator.getLastKnownPosition();
  if (last != null && _fresh(last, maxAge)) return last;

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: Duration(seconds: 15),
    ),
  );
}

bool _fresh(Position p, Duration? maxAge) =>
    maxAge == null || DateTime.now().difference(p.timestamp) <= maxAge;
