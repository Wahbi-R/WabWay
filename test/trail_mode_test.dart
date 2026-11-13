import 'package:flutter_test/flutter_test.dart';
import 'package:wabway/core/auth/app_profile.dart';
import 'package:wabway/core/trail/trail_mode.dart';
import 'package:wabway/core/trip/app_trip_member.dart';

// Trail mode (offline crew finder): what the native side reports, and the
// numbering every phone must agree on.
void main() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final json = <String, dynamic>{
    'running': true,
    'startedAt': now - 60000,
    'wokenBy': 'Ana',
    'wake': true,
    'me': {'lat': 46.2, 'lng': 7.5, 'acc': 6, 'time': now},
    'peers': [
      {'index': 0, 'name': 'Ana', 'lat': 46.2009, 'lng': 7.5, 'acc': 8, 'fixTime': now - 5000, 'heardAt': now - 2000, 'via': -1, 'rssi': -71},
      {'index': 2, 'name': 'Sam', 'lat': 46.2, 'lng': 7.51, 'acc': 12, 'fixTime': now - 300000, 'heardAt': now - 300000, 'via': 0, 'viaName': 'Ana'},
      {'index': 3, 'name': 'Lee', 'heardAt': now - 1000, 'via': -1, 'rssi': -55},
    ],
  };

  test('parses the native state', () {
    final s = TrailState.fromJson(json);
    expect(s.running, isTrue);
    expect(s.wokenBy, 'Ana');
    expect(s.me!.accuracyM, 6);
    final ana = s.peer(0)!;
    expect(ana.relayed, isFalse);
    expect(ana.rssi, -71);
    final sam = s.peer(2)!;
    expect(sam.relayed, isTrue);
    expect(sam.viaName, 'Ana');
    expect(s.peer(3)!.fix, isNull);
    expect(s.peer(1), isNull);
  });

  test('distance and direction to the crew', () {
    final s = TrailState.fromJson(json);
    final north = trailVector(s.me, s.peer(0)!.fix)!;
    expect(north.metres, closeTo(100, 2)); // 0.0009° of latitude ≈ 100 m
    expect(compassPoint(north.bearing), 'N');
    final east = trailVector(s.me, s.peer(2)!.fix)!;
    expect(compassPoint(east.bearing), 'E');
    expect(trailVector(s.me, null), isNull);
    expect(combinedAccuracy(s.me!, s.peer(0)!.fix!), 10);
  });

  test('labels', () {
    expect(compassPoint(350), 'N');
    expect(compassPoint(225), 'SW');
    expect(signalLabel(-50), 'Very close');
    expect(signalLabel(-80), 'Nearby');
    expect(signalLabel(-95), 'Just in range');
  });

  test('every phone numbers the crew the same way (sorted by user id)', () {
    AppTripMember m(String id, String name) => AppTripMember(
          userId: id,
          role: 'member',
          profile: AppProfile(id: id, displayName: name, email: '$name@x.ca', displayNameIsSet: true),
        );
    final a = TrailMode.sortedCrew([m('c', 'Cy'), m('a', 'Ana'), m('b', 'Bo')]);
    final b = TrailMode.sortedCrew([m('b', 'Bo'), m('c', 'Cy'), m('a', 'Ana')]);
    expect(a.map((x) => x.userId), ['a', 'b', 'c']);
    expect(b.map((x) => x.userId), ['a', 'b', 'c']);
  });

  test('setup: what start and wake need', () {
    const ready = TrailSetup(supported: true, bluetoothOn: true, bluetoothPermission: true, locationPermission: true);
    expect(ready.canStart, isTrue);
    expect(ready.canWake, isFalse);
    expect(const TrailSetup(supported: true, bluetoothOn: true, bluetoothPermission: true, locationPermission: true,
            backgroundLocation: true, batteryUnrestricted: true).canWake, isTrue);
  });
}
