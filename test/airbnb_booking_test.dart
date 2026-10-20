// The Sumida City Airbnb itinerary PDF, shared after the stay was already in
// the trip (added by an assistant, without times or the host's phone).

import 'package:flutter_test/flutter_test.dart';
import 'package:wabway/core/booking_merge.dart';
import 'package:wabway/core/booking_parse_service.dart';
import 'package:wabway/core/booking_receipt.dart';
import 'package:wabway/core/ocr/parsed_booking.dart';
import 'package:wabway/data/accommodation_data.dart';
import 'package:wabway/data/money_data.dart';

const _crew = ['me', 'shams', 'ber', 'anojan', 'kai'];

Map<String, dynamic> _airbnb({String paid = 'unknown'}) => {
      'kind': 'stay', 'title': '2BR | Direct train Asakusa & Skytree | 2-story house',
      'date': '2026-11-19', 'end_date': '2026-11-23',
      'check_in_time': '16:00', 'check_out_time': '10:00', 'city': 'Tokyo',
      'address': '5-chōme-6-2 Sumida, Sumida City, Tokyo 131-0031, Japan',
      'confirmation_number': 'HMYPCB4JZP',
      'travellers': [
        {'name': 'Wahbi Raihan', 'member_id': 'me'},
        {'name': 'Shamil Refai', 'member_id': 'shams'},
        {'name': 'Bereket Mesfin', 'member_id': 'ber'},
        {'name': 'Anojan Balendra', 'member_id': 'anojan'},
      ],
      'passenger_count': 4, 'price_total': 919.37, 'currency': 'CAD', 'paid_status': paid,
      'notes': 'Host Junko: +81 70-4722-2544\n4 guests',
    };

ParsedStay _parsed({String paid = 'unknown'}) => BookingParseService.fromServer(
    [_airbnb(paid: paid)], tripId: 't1', userId: 'me', tripCurrency: 'JPY').single as ParsedStay;

void main() {
  test("a booking that only says 'Total cost' still offers its receipt", () {
    final stay = _parsed();
    expect(stay.price!.isPaid, isFalse, reason: 'the review card starts with the switch off');
    final r = receiptForBooking(stay, payerId: 'me', memberIds: _crew)!;
    expect(r.amount, 919.37);
    expect(r.category, ReceiptCategory.accommodation);
  });

  test('a stay is split between the guests named on it, not the whole trip', () {
    final r = receiptForBooking(_parsed(paid: 'paid'), payerId: 'me', memberIds: _crew)!;
    expect(r.splitWith, ['me', 'shams', 'ber', 'anojan']);
    expect(r.splits.map((s) => s.amount), [229.84, 229.84, 229.84, 229.84]);
  });

  test('a guest who is not in the trip means everyone shares it', () {
    final stay = BookingParseService.fromServer([
      {..._airbnb(paid: 'paid'), 'travellers': [
        {'name': 'Wahbi Raihan', 'member_id': 'me'}, {'name': 'A Friend', 'member_id': null}],
       'passenger_count': 2},
    ], tripId: 't1', userId: 'me').single;
    expect(receiptForBooking(stay, payerId: 'me', memberIds: _crew)!.splitWith, _crew);
  });

  test("updating the stay adds the times and the host's phone, keeping your notes", () {
    final existing = Accommodation(
      id: 's', tripId: 't1', name: 'Home in Sumida City (Junko)', city: 'Tokyo',
      confirmationNumber: 'HMYPCB4JZP', pricePerNight: 229.84, currency: 'CAD',
      checkIn: DateTime(2026, 11, 19), checkOut: DateTime(2026, 11, 23),
      status: AccommodationStatus.booked, createdBy: 'me', createdAt: DateTime(2026, 10, 20),
      notes: 'Airbnb, hosted by Junko. 4 guests. Check-in: contact host for instructions.',
    );
    final stay = _parsed();
    expect(findExistingBooking(stay, travel: const [], stays: [existing], days: const []), same(existing));
    final merged = mergeStay(existing, stay.stay);
    expect((merged.checkInTime, merged.checkOutTime), ('16:00', '10:00'));
    expect(merged.name, 'Home in Sumida City (Junko)');
    expect(merged.notes, startsWith('Airbnb, hosted by Junko.'));
    expect(merged.notes, contains('Host Junko: +81 70-4722-2544'));
    expect(merged.notes, isNot(contains('\n4 guests')), reason: 'already in the notes');
  });

  test('mergeNotes only adds what is new', () {
    expect(mergeNotes(null, 'a'), 'a');
    expect(mergeNotes('a', null), 'a');
    expect(mergeNotes('Gate code 1234', 'gate code 1234\nWifi: wabway'), 'Gate code 1234\nWifi: wabway');
    expect(mergeNotes('x', 'x'), 'x');
  });
}
