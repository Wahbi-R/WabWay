import 'dart:async';
import 'package:flutter/foundation.dart'
    show ValueNotifier, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../supabase/crew_service.dart';

/// Singleton that owns the GPS position stream so it outlives any widget.
/// The crew screen starts/stops sharing via this class; the stream keeps
/// running if the user navigates away from crew.
class LocationSharingManager {
  LocationSharingManager._();
  static final instance = LocationSharingManager._();

  static const _channel = MethodChannel('ca.wabble.wabway/location_sharing');

  final isSharing = ValueNotifier<bool>(false);

  StreamSubscription<Position>? _sub;
  String? _tripId;
  String? _userId;
  bool _stopActionAdded = false;

  /// Call once from main() on non-web platforms to register the native handler.
  void init() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onStopRequested') await stop();
      });
    }
  }

  Future<void> start({
    required String tripId,
    required String userId,
    required LocationSettings settings,
  }) async {
    _tripId = tripId;
    _userId = userId;
    isSharing.value = true;

    _sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) async {
      if (!isSharing.value) return;
      // First position means the foreground service is live — add stop button.
      if (!_stopActionAdded &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        _stopActionAdded = true;
        try {
          await _channel.invokeMethod('addStopAction');
        } catch (_) {}
      }
      try {
        await CrewService.upsertLocationShare(
          tripId: _tripId!,
          userId: _userId!,
          lat: pos.latitude,
          lng: pos.longitude,
        );
      } catch (_) {}
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _stopActionAdded = false;
    if (_tripId != null && _userId != null) {
      try {
        await CrewService.deactivateLocationShare(
            tripId: _tripId!, userId: _userId!);
      } catch (_) {}
    }
    _tripId = null;
    _userId = null;
    isSharing.value = false;
  }
}
