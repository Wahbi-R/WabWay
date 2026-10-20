import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wabway/core/auth/app_profile.dart';
import 'package:wabway/core/booking_parse_service.dart';
import 'package:wabway/core/booking_receipt.dart';
import 'package:wabway/core/ocr/parsed_booking.dart';
import 'package:wabway/core/providers/profile_provider.dart';
import 'package:wabway/core/providers/trip_provider.dart';
import 'package:wabway/core/trip/app_trip.dart';
import 'package:wabway/core/trip/app_trip_member.dart';
import 'package:wabway/data/money_data.dart';
import 'package:wabway/data/travel_data.dart';
import 'package:wabway/screens/share/booking_review_screen.dart';

// The Shinkansen thread from the trip: three smart EX confirmations in one
// Gmail PDF (two non-reserved legs on Nov 14, one reserved Hikari on Nov 18),
// as /booking/parse returns them.
const _thread = [
  {
    'kind': 'travel', 'title': 'Shinkansen Hakata → Hiroshima', 'travel_type': 'train',
    'date': '2026-11-14', 'from': 'Hakata', 'to': 'Hiroshima', 'confirmation_number': '2005',
    'cabin_class': 'Non-reserved', 'travellers': [], 'price_total': 34280, 'currency': 'JPY',
    'currency_guessed': false, 'price_lines': [], 'paid_status': 'paid', 'passenger_count': 4,
    'source_pages': [1],
  },
  {
    'kind': 'travel', 'title': 'Shinkansen Higashi-Hiroshima → Shin-Osaka', 'travel_type': 'train',
    'date': '2026-11-14', 'from': 'Higashi-Hiroshima', 'to': 'Shin-Osaka',
    'confirmation_number': '2006', 'travellers': [], 'price_total': 38680, 'currency': 'JPY',
    'paid_status': 'paid', 'passenger_count': 4, 'source_pages': [2],
  },
  {
    'kind': 'travel', 'title': 'Hikari 704 Shin-Osaka → Atami', 'travel_type': 'train',
    'date': '2026-11-18', 'time': '10:48', 'end_time': '13:04', 'from': 'Shin-Osaka',
    'to': 'Atami', 'confirmation_number': '2007',
    'travellers': [
      {'member_id': null, 'seat': 'Car 14 20-D'}, {'member_id': null, 'seat': 'Car 14 20-E'},
      {'member_id': null, 'seat': 'Car 14 19-D'}, {'member_id': null, 'seat': 'Car 14 19-E'},
    ],
    'price_total': 49720, 'currency': 'JPY', 'paid_status': 'paid', 'passenger_count': 4,
    'price_lines': [{'label': 'Adult fare', 'quantity': 4, 'amount': 49720}],
    'source_pages': [2],
  },
];

List<ParsedBooking> _parsed({String tripCurrency = 'JPY'}) => BookingParseService.fromServer(
    _thread, tripId: 't1', userId: 'me', tripCurrency: tripCurrency);

const _me = AppProfile(id: 'me', displayName: 'Wahbi Raihan', email: 'w@example.com');
const _members = ['me', 'sam', 'ana', 'kai'];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('one PDF with three confirmations is three trains, each with its own price and page', () {
    final b = _parsed();
    expect(b.map((x) => (x as ParsedTravel).item.confirmationNumber), ['2005', '2006', '2007']);
    expect(b.map((x) => x.price!.total), [34280, 38680, 49720]);
    expect(b.map((x) => x.pages), [[1], [2], [2]]);
    expect((b[2] as ParsedTravel).item.notes, contains('Paid ¥49,720 · ¥12,430 each'));
  });

  test('each paid train becomes its own receipt, split between the four of you', () {
    final receipts = [
      for (final x in _parsed()) receiptForBooking(x, payerId: 'me', memberIds: _members)!,
    ];
    expect(receipts.map((r) => r.amount), [34280, 38680, 49720]);
    expect(receipts.every((r) => r.category == ReceiptCategory.transport), isTrue);
    expect(receipts.every((r) => r.paidById == 'me'), isTrue);
    // Seats aren't assigned yet, so it's split between everyone in the trip.
    expect(receipts[2].splitWith, _members);
    expect(receipts[2].splits.map((s) => s.amount), [12430, 12430, 12430, 12430]);
    // The printed fare line becomes a receipt item everyone shares.
    expect(receipts[2].items!.items.single.name, 'Adult fare');
    expect(receipts[2].items!.total, 49720);
    expect(receipts[0].items, isNull, reason: 'a bare total stays one amount');
    expect(receipts[2].notes, 'From booking · Ref 2007');
  });

  test('once seats are assigned, only those travellers share the cost', () {
    final hikari = _parsed()[2] as ParsedTravel;
    final assigned = hikari.withItem(hikari.item.withTravellers(const [
      TravelTraveller(userId: 'me', seat: 'Car 14 20-D'),
      TravelTraveller(userId: 'sam', seat: 'Car 14 20-E'),
    ]));
    // Two seats assigned but the ticket is for four people: still everyone.
    expect(receiptForBooking(assigned, payerId: 'me', memberIds: _members)!.splitWith, _members);

    final pair = BookingParseService.fromServer([
      {..._thread[2], 'passenger_count': 2, 'travellers': [
        {'member_id': 'me', 'seat': '20-D'}, {'member_id': 'sam', 'seat': '20-E'}]},
    ], tripId: 't1', userId: 'me').single;
    final r = receiptForBooking(pair, payerId: 'me', memberIds: _members)!;
    expect(r.splitWith, ['me', 'sam']);
    expect(r.splits.map((s) => s.amount), [24860, 24860]);
  });

  test('nothing paid yet, or no price, makes no receipt; a deposit records what was paid', () {
    final due = BookingParseService.fromServer([
      {'kind': 'stay', 'title': 'Ryokan', 'date': '2026-11-18', 'end_date': '2026-11-19',
       'price_total': 30000, 'currency': 'JPY', 'paid_status': 'due', 'amount_due': 30000},
    ], tripId: 't1', userId: 'me').single;
    expect(receiptForBooking(due, payerId: 'me', memberIds: _members), isNull);

    final deposit = BookingParseService.fromServer([
      {'kind': 'stay', 'title': 'Ryokan', 'price_total': 30000, 'currency': 'JPY',
       'paid_status': 'part_paid', 'amount_due': 20000},
    ], tripId: 't1', userId: 'me').single;
    final r = receiptForBooking(deposit, payerId: 'me', memberIds: _members)!;
    expect(r.amount, 10000);
    expect(r.category, ReceiptCategory.accommodation);
    expect(r.notes, contains('¥20,000 still due'));

    final free = BookingParseService.fromServer([
      {'kind': 'plan', 'title': 'Free walking tour', 'date': '2026-11-15', 'price_total': 0},
    ], tripId: 't1', userId: 'me').single;
    expect(free.price, isNull);
    expect(receiptForBooking(free, payerId: 'me', memberIds: _members), isNull);
  });

  test('no currency shown falls back to the trip currency and asks you to check', () {
    final b = BookingParseService.fromServer([
      {'kind': 'travel', 'title': 'Ferry', 'travel_type': 'ferry', 'price_total': 40},
    ], tripId: 't1', userId: 'me', tripCurrency: 'CAD').single;
    expect(b.price!.currency, 'CAD');
    expect(b.price!.currencyGuessed, isTrue);
  });

  test('a receipt already in Money for the same payment is found', () {
    final draft = receiptForBooking(_parsed()[2], payerId: 'me', memberIds: _members)!;
    final logged = Receipt(
      id: 'r1', title: 'Shinkansen 2007', amount: 49720, currency: 'JPY', homeAmount: 450,
      exchangeRate: 0.009, transactionFeePct: 0, paidById: 'sam', splits: const [],
      category: ReceiptCategory.transport, date: DateTime(2026, 10, 19),
    );
    expect(findExistingReceipt(draft, [logged]), same(logged));
    final other = Receipt(
      id: 'r2', title: 'Dinner', amount: 49720, currency: 'JPY', homeAmount: 450,
      exchangeRate: 0.009, transactionFeePct: 0, paidById: 'me', splits: const [],
      category: ReceiptCategory.food, date: DateTime(2026, 10, 19),
    );
    expect(findExistingReceipt(draft, [other]), isNull);
  });

  test('amounts have thousands separators', () {
    expect(fmtAmount(49720, 'JPY'), '¥49,720');
    expect(fmtAmount(1234.5, 'CAD'), r'C$1,234.50');
    expect(fmtAmount(999, 'USD'), r'$999.00');
    expect(fmtAmount(-1500, 'EUR'), '€-1,500.00');
  });

  testWidgets('review shows each train with its price and the receipt it will make', (tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) => ProfileNotifier()..set(_me)),
        activeTripProvider.overrideWithValue(const AppTrip(
            id: 't1', name: 'Japan', defaultCurrency: 'JPY', homeCurrency: 'CAD')),
        tripMembersProvider.overrideWithValue([
          for (final id in _members)
            AppTripMember(
                userId: id,
                role: id == 'me' ? 'owner' : 'member',
                profile: id == 'me' ? _me : AppProfile(id: id, displayName: id, email: '$id@x')),
        ]),
      ],
      child: MaterialApp(
          home: BookingReviewScreen(bookings: _parsed(), tripId: 't1', userId: 'me')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Paid ¥34,280 · ¥8,570 each'), findsOneWidget);
    expect(find.text('Paid ¥38,680 · ¥9,670 each'), findsOneWidget);
    expect(find.text('Paid ¥49,720 · ¥12,430 each'), findsOneWidget);
    expect(find.text('Add receipt to Money'), findsNWidgets(3));
    expect(find.textContaining('¥49,720 · paid by you · split 4 ways · itemised'), findsOneWidget);
    expect(find.text('Save 3 bookings'), findsOneWidget);
  });
}
