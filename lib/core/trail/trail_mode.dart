import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../trip/app_trip_member.dart';

/// Trail mode: find the crew with no signal. Each phone sends its GPS position
/// over Bluetooth (encrypted with the trip), hears the others and passes on
/// what it heard, so positions hop between phones. Phones with "Let the crew
/// wake me" on switch it on by themselves when they hear someone using it.
///
/// Android only — the native side is `TrailService` / `TrailWake` in
/// `android/app/src/main/kotlin/ca/wabble/wabway/`.
class TrailMode {
  TrailMode._();
  static final instance = TrailMode._();

  static const _methods = MethodChannel('ca.wabble.wabway/trail');
  static const _events = EventChannel('ca.wabble.wabway/trail_events');
  static const _compass = EventChannel('ca.wabble.wabway/compass');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Bumped when a Trail mode notification is tapped — AppShell opens the screen.
  final openRequests = ValueNotifier<int>(0);

  bool _initialised = false;
  String _configuredFor = '';

  /// Call once at startup (after the first frame) on Android.
  Future<void> init() async {
    if (!supported || _initialised) return;
    _initialised = true;
    _methods.setMethodCallHandler((call) async {
      if (call.method == 'openTrail') openRequests.value++;
    });
    try {
      if (await _methods.invokeMethod<bool>('takeLaunchAction') == true) openRequests.value++;
      // A reboot or app update drops the background scan; re-arm it.
      await _methods.invokeMethod('refreshWake');
    } catch (_) {}
  }

  /// Tell the native side who's on the trip. Member numbers are positions in
  /// the list sorted by user id, so every phone numbers the crew the same way.
  /// Names are saved on the phone so it works with no signal.
  Future<void> configure({
    required String tripId,
    required List<AppTripMember> members,
    required String myUserId,
  }) async {
    if (!supported || tripId.isEmpty) return;
    final sorted = sortedCrew(members);
    final myIndex = sorted.indexWhere((m) => m.userId == myUserId);
    await _methods.invokeMethod('configure', {
      'tripId': tripId,
      'names': [for (final m in sorted) m.profile.displayName],
      'myIndex': myIndex,
    });
  }

  /// Keep the phone's crew list current without opening the Trail screen, so
  /// "Let the crew wake me" works on every phone by default. Called by AppShell
  /// whenever the active trip or its members change; skips repeats.
  Future<void> autoConfigure({
    required String tripId,
    required List<AppTripMember> members,
    required String? myUserId,
  }) async {
    if (!supported || tripId.isEmpty || myUserId == null || members.isEmpty) return;
    final key = '$tripId|$myUserId|${[for (final m in sortedCrew(members)) '${m.userId}:${m.profile.displayName}'].join(',')}';
    if (key == _configuredFor) return;
    _configuredFor = key;
    try {
      await configure(tripId: tripId, members: members, myUserId: myUserId);
    } catch (_) {
      _configuredFor = '';
    }
  }

  static const _kPrefWakeAsked = 'trail_wake_permission_asked';

  /// Waking needs the Bluetooth ("Nearby devices") permission, which Android
  /// only grants when asked. Ask once (from Crew); the Trail screen's checklist
  /// covers the rest.
  Future<void> askWakePermissionOnce(Future<bool> Function() confirm) async {
    if (!supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kPrefWakeAsked) == true) return;
      final s = await setup();
      if (!s.supported || (s.bluetoothPermission && s.locationPermission)) return;
      await prefs.setBool(_kPrefWakeAsked, true);
      if (!await confirm()) return;
      await requestPermissions();
      await _methods.invokeMethod('refreshWake');
    } catch (_) {}
  }

  static List<AppTripMember> sortedCrew(List<AppTripMember> members) =>
      [...members]..sort((a, b) => a.userId.compareTo(b.userId));

  Stream<TrailState> get states =>
      _events.receiveBroadcastStream().map((e) => TrailState.fromJson(jsonDecode(e as String) as Map<String, dynamic>));

  /// Phone heading in degrees (0 = north), or an empty stream without a compass.
  Stream<double> get heading => _compass.receiveBroadcastStream().map((e) => (e as num).toDouble());

  Future<TrailSetup> setup() async {
    final m = await _methods.invokeMapMethod<String, dynamic>('setup') ?? const {};
    return TrailSetup.fromMap(m);
  }

  Future<bool> requestPermissions() async => await _methods.invokeMethod<bool>('requestPermissions') ?? false;
  Future<bool> requestBackgroundLocation() async =>
      await _methods.invokeMethod<bool>('requestBackgroundLocation') ?? false;
  Future<void> requestBatteryUnrestricted() => _methods.invokeMethod('requestBatteryUnrestricted');
  Future<void> enableBluetooth() => _methods.invokeMethod('enableBluetooth');
  Future<void> openLocationSettings() => _methods.invokeMethod('openLocationSettings');
  Future<void> openAppSettings() => _methods.invokeMethod('openAppSettings');
  Future<void> start() => _methods.invokeMethod('start');
  Future<void> stop() => _methods.invokeMethod('stop');
  Future<void> setWake(bool enabled) => _methods.invokeMethod('setWake', {'enabled': enabled});
  Future<void> clearPeers() => _methods.invokeMethod('clearPeers');
}

class TrailSetup {
  const TrailSetup({
    this.supported = false,
    this.advertiseSupported = false,
    this.bluetoothOn = false,
    this.bluetoothPermission = false,
    this.locationPermission = false,
    this.backgroundLocation = false,
    this.locationOn = false,
    this.batteryUnrestricted = false,
    this.notifications = false,
  });

  final bool supported;
  final bool advertiseSupported;
  final bool bluetoothOn;
  final bool bluetoothPermission;
  final bool locationPermission;
  final bool backgroundLocation;
  final bool locationOn;
  final bool batteryUnrestricted;
  final bool notifications;

  /// What Trail mode needs to run at all.
  bool get canStart => supported && bluetoothOn && bluetoothPermission && locationPermission;

  /// What waking up by itself (screen off, app closed) needs on top.
  bool get canWake => canStart && backgroundLocation && batteryUnrestricted;

  factory TrailSetup.fromMap(Map<String, dynamic> m) {
    bool b(String k) => m[k] == true;
    return TrailSetup(
      supported: b('supported'),
      advertiseSupported: b('advertiseSupported'),
      bluetoothOn: b('bluetoothOn'),
      bluetoothPermission: b('bluetoothPermission'),
      locationPermission: b('locationPermission'),
      backgroundLocation: b('backgroundLocation'),
      locationOn: b('locationOn'),
      batteryUnrestricted: b('batteryUnrestricted'),
      notifications: b('notifications'),
    );
  }
}

class TrailFix {
  const TrailFix(this.lat, this.lng, this.accuracyM, this.time);
  final double lat;
  final double lng;
  final int accuracyM;
  final DateTime time;
}

class TrailPeer {
  const TrailPeer({
    required this.index,
    required this.name,
    required this.heardAt,
    this.fix,
    this.via,
    this.viaName,
    this.rssi,
  });

  final int index;
  final String name;
  final TrailFix? fix;

  /// Last time their own phone was heard (or the relay that told us).
  final DateTime heardAt;

  /// Index of the phone that passed it on; null when heard directly.
  final int? via;
  final String? viaName;

  /// Signal strength when heard directly (dBm, ~-40 next to you … -100 far).
  final int? rssi;

  bool get relayed => via != null;

  factory TrailPeer.fromJson(Map<String, dynamic> m) {
    final fixTime = (m['fixTime'] as num?)?.toInt();
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
    final via = (m['via'] as num?)?.toInt() ?? -1;
    return TrailPeer(
      index: (m['index'] as num).toInt(),
      name: m['name'] as String? ?? 'Someone',
      heardAt: DateTime.fromMillisecondsSinceEpoch((m['heardAt'] as num).toInt()),
      fix: lat != null && lng != null && fixTime != null
          ? TrailFix(lat, lng, (m['acc'] as num?)?.toInt() ?? 0, DateTime.fromMillisecondsSinceEpoch(fixTime))
          : null,
      via: via >= 0 ? via : null,
      viaName: via >= 0 ? m['viaName'] as String? : null,
      rssi: (m['rssi'] as num?)?.toInt(),
    );
  }
}

class TrailState {
  const TrailState({
    this.running = false,
    this.startedAt,
    this.wokenBy,
    this.wake = true,
    this.me,
    this.peers = const [],
  });

  final bool running;
  final DateTime? startedAt;
  final String? wokenBy;
  final bool wake;
  final TrailFix? me;
  final List<TrailPeer> peers;

  factory TrailState.fromJson(Map<String, dynamic> m) {
    final me = m['me'] as Map<String, dynamic>?;
    final started = (m['startedAt'] as num?)?.toInt() ?? 0;
    return TrailState(
      running: m['running'] == true,
      startedAt: started > 0 ? DateTime.fromMillisecondsSinceEpoch(started) : null,
      wokenBy: m['wokenBy'] as String?,
      wake: m['wake'] != false,
      me: me == null
          ? null
          : TrailFix(
              (me['lat'] as num).toDouble(),
              (me['lng'] as num).toDouble(),
              (me['acc'] as num?)?.toInt() ?? 0,
              DateTime.fromMillisecondsSinceEpoch((me['time'] as num).toInt()),
            ),
      peers: [
        for (final p in (m['peers'] as List?) ?? const []) TrailPeer.fromJson(p as Map<String, dynamic>),
      ],
    );
  }

  TrailPeer? peer(int index) => peers.where((p) => p.index == index).firstOrNull;
}

/// Where a crew member is from you: metres and compass bearing (0 = north).
({double metres, double bearing})? trailVector(TrailFix? me, TrailFix? them) {
  if (me == null || them == null) return null;
  final d = Geolocator.distanceBetween(me.lat, me.lng, them.lat, them.lng);
  final b = (Geolocator.bearingBetween(me.lat, me.lng, them.lat, them.lng) + 360) % 360;
  return (metres: d, bearing: b);
}

/// "N", "NE", … for a bearing in degrees.
String compassPoint(double bearing) {
  const points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return points[(((bearing % 360) + 22.5) ~/ 45) % 8];
}

/// How close the Bluetooth signal says they are, when there's no GPS to go on.
String signalLabel(int rssi) => rssi >= -60
    ? 'Very close'
    : rssi >= -75
        ? 'Close by'
        : rssi >= -88
            ? 'Nearby'
            : 'Just in range';

/// The error in "x m away": both fixes' accuracy combined, rounded.
int combinedAccuracy(TrailFix me, TrailFix them) =>
    math.sqrt(me.accuracyM * me.accuracyM + them.accuracyM * them.accuracyM).round();
