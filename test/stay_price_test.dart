import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wabway/data/accommodation_data.dart';
import 'package:wabway/screens/accommodations/add_accommodation_sheet.dart';

void main() {
  final nico = Accommodation(
    id: 's1', tripId: 't', name: 'NICO Hotel Osaka Nippombashi', city: 'Osaka',
    pricePerNight: 88509 / 4, currency: 'JPY',
    checkIn: DateTime(2026, 11, 14), checkOut: DateTime(2026, 11, 18),
    status: AccommodationStatus.booked, createdBy: 'me', createdAt: DateTime(2026, 10, 20),
  );

  test('the total comes back exactly from a total ÷ nights price', () {
    expect(nico.totalPrice, closeTo(88509, 0.0001));
  });

  testWidgets('editing a stay with dates shows its total, and can switch to per night', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: Scaffold(body: AddAccommodationSheet(tripId: 't', userId: 'me', editing: nico))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Total for 4 nights'), findsOneWidget);
    expect(find.widgetWithText(TextField, '88509'), findsOneWidget);
    expect(find.text('¥22,127 / night'), findsOneWidget);

    await tester.tap(find.text('Per night'));
    await tester.pumpAndSettle();
    expect(find.text('Price per night'), findsOneWidget);
    expect(find.widgetWithText(TextField, '22127.25'), findsOneWidget);
    expect(find.text('¥88,509 total'), findsOneWidget);
  });
}
