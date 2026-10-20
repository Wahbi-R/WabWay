import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wabway/data/accommodation_data.dart';
import 'package:wabway/data/date_utils.dart';
import 'package:wabway/screens/accommodations/add_accommodation_sheet.dart';

Accommodation _stay({String? inTime, String? outTime}) => Accommodation(
      id: 's1',
      tripId: 't1',
      name: 'Hotel Shinjuku',
      city: 'Tokyo',
      checkIn: DateTime(2026, 11, 11),
      checkOut: DateTime(2026, 11, 14),
      checkInTime: inTime,
      checkOutTime: outTime,
      createdBy: 'u1',
      createdAt: DateTime(2026, 10, 20),
    );

void main() {
  test('parseTimeOfDay reads HH:MM and Postgres HH:MM:SS', () {
    expect(parseTimeOfDay('15:00'), const TimeOfDay(hour: 15, minute: 0));
    expect(parseTimeOfDay('09:30:00'), const TimeOfDay(hour: 9, minute: 30));
    expect(parseTimeOfDay(null), isNull);
    expect(parseTimeOfDay('noon'), isNull);
    expect(parseTimeOfDay('25:00'), isNull);
  });

  test('hhmmFromDb trims seconds', () {
    expect(hhmmFromDb('11:00:00'), '11:00');
    expect(hhmmFromDb('11:00'), '11:00');
    expect(hhmmFromDb(null), isNull);
  });

  test('stay labels include times only when set', () {
    final withTimes = _stay(inTime: '15:00', outTime: '11:00');
    expect(withTimes.checkInLabel, 'Nov 11, 15:00');
    expect(withTimes.checkOutLabel, 'Nov 14, 11:00');
    expect(withTimes.nights, 3);

    final noTimes = _stay();
    expect(noTimes.checkInLabel, 'Nov 11');
    expect(noTimes.checkOutLabel, 'Nov 14');
  });

  test('copyWith keeps times unless given, and can clear them', () {
    final s = _stay(inTime: '15:00', outTime: '11:00');
    expect(s.copyWith(name: 'x').checkInTime, '15:00');
    final cleared = s.copyWith(checkInTime: null, checkOutTime: '10:00');
    expect(cleared.checkInTime, isNull);
    expect(cleared.checkOutTime, '10:00');
  });

  testWidgets('edit stay form shows the check-in / check-out times', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddAccommodationSheet(
          tripId: 't1',
          userId: 'u1',
          editing: _stay(inTime: '15:00', outTime: '11:00'),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('Check-in from'), findsOneWidget);
    expect(find.text('Check-out by'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('11:00'), findsOneWidget);
  });
}
