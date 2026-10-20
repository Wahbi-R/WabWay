import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wabway/core/auth/app_profile.dart';
import 'package:wabway/core/booking_merge.dart';
import 'package:wabway/core/booking_parse_service.dart';
import 'package:wabway/core/ocr/parsed_booking.dart';
import 'package:wabway/core/providers/profile_provider.dart';
import 'package:wabway/core/providers/trip_provider.dart';
import 'package:wabway/core/trip/app_trip.dart';
import 'package:wabway/core/trip/app_trip_member.dart';
import 'package:wabway/data/accommodation_data.dart';
import 'package:wabway/data/plan_data.dart';
import 'package:wabway/data/share_data.dart';
import 'package:wabway/data/travel_data.dart';
import 'package:wabway/screens/share/booking_review_screen.dart';
import 'package:wabway/screens/travel/add_travel_sheet.dart';
import 'package:wabway/screens/travel/travellers_section.dart';

const _me = AppProfile(id: 'me', displayName: 'Wahbi Raihan', email: 'w@example.com');
const _sam = AppProfile(id: 'sam', displayName: 'Sam Lee', email: 's@example.com');
const _trip = AppTrip(id: 't1', name: 'Japan', defaultCurrency: 'JPY', homeCurrency: 'CAD');
const _members = [
  AppTripMember(userId: 'me', role: 'owner', profile: _me),
  AppTripMember(userId: 'sam', role: 'member', profile: _sam),
];

// What wabway-server's /booking/parse returns for the Shinkansen e-ticket,
// a hotel confirmation and a restaurant booking.
final _serverReply = [
  {
    'kind': 'travel', 'title': 'Hikari 704 Shin-Osaka → Atami', 'travel_type': 'train',
    'date': '2026-11-18', 'end_date': '2026-11-18', 'time': '10:48', 'end_time': '13:04',
    'from': 'Shin-Osaka', 'to': 'Atami', 'carrier_number': 'HIKARI 704', 'operator': 'JR Central',
    'cabin_class': 'Ordinary', 'confirmation_number': '2007',
    'travellers': [
      {'name': null, 'member_id': 'me', 'seat': 'Car 14 20-D'},
      {'name': 'BOB', 'member_id': null, 'seat': 'Car 14 20-E'},
      {'name': null, 'member_id': null, 'seat': 'Car 14 19-D'},
    ],
    'price_total': 49720, 'currency': 'JPY', 'notes': 'Board with QR-Ticket',
  },
  {
    'kind': 'stay', 'title': 'Hotel Atami Bay', 'date': '2026-11-18', 'end_date': '2026-11-20',
    'check_in_time': '15:00', 'check_out_time': '11:00', 'city': 'Atami',
    'address': '1-1 Higashikaigan', 'confirmation_number': 'HX-77', 'price_total': 30000,
    'currency': 'JPY', 'travellers': [],
  },
  {
    'kind': 'plan', 'title': 'Sushi Dai', 'plan_type': 'food', 'date': '2026-11-19', 'time': '19:00',
    'address': 'Tsukiji', 'confirmation_number': 'R123', 'price_total': 8000, 'currency': 'JPY',
    'travellers': [],
  },
  {'kind': 'mystery', 'title': 'ignored'},
];

List<ParsedBooking> _parsed() =>
    BookingParseService.fromServer(_serverReply, tripId: 't1', userId: 'me');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('server bookings become travel, stay and plan drafts', () {
    final b = _parsed();
    expect(b, hasLength(3));

    final train = (b[0] as ParsedTravel).item;
    expect(train.type, TravelItemType.train);
    expect((train.time, train.endTime), ('10:48', '13:04'));
    expect((train.location, train.destination), ('Shin-Osaka', 'Atami'));
    expect(train.endDate, isNull, reason: 'same-day arrival is not a multi-day item');
    expect(train.confirmationNumber, '2007');
    expect(train.travellers.map((t) => (t.userId, t.name, t.seat)), [
      ('me', null, 'Car 14 20-D'),
      (null, 'BOB', 'Car 14 20-E'),
      (null, null, 'Car 14 19-D'),
    ]);
    expect(train.notes, contains('JR Central · Ordinary'));
    expect(train.notes, contains('Total ¥49720'));

    final stay = (b[1] as ParsedStay).stay;
    expect((stay.checkInTime, stay.checkOutTime), ('15:00', '11:00'));
    expect(stay.pricePerNight, 15000, reason: 'total ÷ nights when no nightly rate is printed');
    expect(stay.status, AccommodationStatus.booked);
    expect(stay.address, '1-1 Higashikaigan');

    final dinner = b[2] as ParsedPlan;
    expect(dinner.item.type, ItineraryItemType.food);
    expect(dinner.day, DateTime(2026, 11, 19));
    expect(dinner.item.plannedCost, 8000);
    expect(dinner.item.notes, contains('Confirmation: R123'));
  });

  test('a booking already in the trip is found and filled in, not duplicated', () {
    final train = _parsed()[0];
    final existing = TravelItem(
      id: 'x', title: 'Hikari 704 Shin-Osaka → Atami', type: TravelItemType.train,
      date: DateTime(2026, 11, 18), time: '10:48', confirmationNumber: '2007',
      notes: 'Added by Claude',
    );
    final match = findExistingBooking(train, travel: [existing], stays: const [], days: const []);
    expect(match, same(existing));

    final merged = mergeTravel(existing, (train as ParsedTravel).item);
    expect(merged.id, 'x');
    expect(merged.endTime, '13:04', reason: 'missing fields are filled');
    expect(merged.notes, 'Added by Claude', reason: "the group's own fields are kept");
    expect(merged.travellers, hasLength(3));

    final other = TravelItem(id: 'y', title: 'Nozomi 1', type: TravelItemType.train, date: DateTime(2026, 11, 18), time: '06:00');
    expect(findExistingBooking(train, travel: [other], stays: const [], days: const []), isNull);
  });

  test('stays match by confirmation and keep what was already entered', () {
    final stay = _parsed()[1] as ParsedStay;
    final existing = Accommodation(
      id: 's', tripId: 't1', name: 'Atami Bay Hotel', city: '', confirmationNumber: 'hx-77',
      status: AccommodationStatus.shortlisted, createdBy: 'sam', createdAt: DateTime(2026),
      notes: 'Sam found this',
    );
    expect(findExistingBooking(stay, travel: const [], stays: [existing], days: const []), same(existing));
    final merged = mergeStay(existing, stay.stay);
    expect(merged.status, AccommodationStatus.booked);
    expect(merged.city, 'Atami');
    expect(merged.checkInTime, '15:00');
    expect(merged.notes, 'Sam found this');
  });

  test('a shared email is text, a shared link is still a link', () {
    expect(detectContentType('Fwd: [Shinkansen Reservation Service]\nReservation number: 2007'),
        ShareContentType.text);
    expect(detectContentType('Your booking.com confirmation for Hotel X is below'),
        ShareContentType.text);
    expect(detectContentType('https://www.booking.com/hotel/jp/x.html'),
        ShareContentType.accommodationLink);
    expect(detectContentType('https://example.com/post'), ShareContentType.blogArticle);
  });

  test('traveller summary reads naturally', () {
    const t = [
      TravelTraveller(userId: 'me', seat: '32A'),
      TravelTraveller(userId: 'sam', seat: '32B'),
      TravelTraveller(seat: '32C'),
    ];
    expect(travellersSummary(t, _members, 'me'), 'You, Sam Lee +1');
    expect(travellersSummary(const [TravelTraveller(userId: 'me', seat: '32A')], _members, 'me'),
        'You · 32A');
    expect(travellersSummary(const [TravelTraveller(seat: '1A'), TravelTraveller(seat: '1B')], _members, 'me'),
        '2 seats');
  });

  Widget app(Widget home) => ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) => ProfileNotifier()..set(_me)),
          activeTripProvider.overrideWithValue(_trip),
          tripMembersProvider.overrideWithValue(_members),
        ],
        child: MaterialApp(home: home),
      );

  testWidgets('review screen shows every booking with what it will do', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(BookingReviewScreen(bookings: _parsed(), tripId: 't1', userId: 'me')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Hikari 704 Shin-Osaka → Atami'), findsOneWidget);
    expect(find.text('Hotel Atami Bay'), findsOneWidget);
    expect(find.text('Sushi Dai'), findsOneWidget);
    expect(find.text('Nov 18 · 10:48 → 13:04'), findsOneWidget);
    expect(find.text('Shin-Osaka → Atami'), findsOneWidget);
    expect(find.text('You, BOB +1'), findsOneWidget);
    expect(find.text('Car 14 20-D, Car 14 20-E, Car 14 19-D'), findsOneWidget);
    expect(find.text('Nov 18, 15:00 → Nov 20, 11:00 · 2 nights'), findsOneWidget);
    expect(find.text('Also add to the plan for Nov 18'), findsOneWidget);
    expect(find.text('Save 3 bookings'), findsOneWidget);

    await tester.tap(find.text('Skip').first);
    await tester.pump();
    expect(find.text('Save 2 bookings'), findsOneWidget);
  });

  testWidgets('travel sheet opens a scanned booking with its travellers to assign', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final train = (_parsed()[0] as ParsedTravel).item;
    TravelItem? result;
    await tester.pumpWidget(app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => result = await showAddTravelSheet(context, prefillItem: train),
            child: const Text('open'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Add travel item'), findsWidgets, reason: 'a prefill stays in Add mode');
    expect(find.text("Who's travelling (optional)"), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('On ticket: BOB'), findsOneWidget);
    expect(find.text('Car 14 19-D'), findsOneWidget);

    await tester.ensureVisible(find.text('Add travel item').last);
    await tester.tap(find.text('Add travel item').last);
    await tester.pumpAndSettle();
    expect(result?.travellers, hasLength(3));
    expect(result?.endTime, '13:04');
  });
}
