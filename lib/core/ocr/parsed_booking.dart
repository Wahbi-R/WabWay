import '../../data/accommodation_data.dart';
import '../../data/plan_data.dart';
import '../../data/travel_data.dart';

/// A booking found in a shared file, email or link, already shaped as the
/// item it becomes: travel (flight/train/bus/ferry/car), stay, or plan item
/// (tickets, restaurant reservations). Produced by [BookingParseService]
/// (server AI) or the on-device OCR fallback; saved by the review screen.
sealed class ParsedBooking {
  const ParsedBooking({
    required this.parsedBy,
    this.price,
    this.pages = const [],
    this.originalLanguage,
    this.passengerCount,
  });

  /// 'ai' or 'ocr'.
  final String parsedBy;
  bool get isAi => parsedBy == 'ai';

  /// What it cost, when the booking shows a price.
  final BookingPrice? price;

  /// 1-based PDF pages this booking is on (for the Receipts link pictures).
  final List<int> pages;

  /// "Japanese" when it was translated; null for English.
  final String? originalLanguage;

  /// People the booking is for ("Adult(s): 4"), when printed.
  final int? passengerCount;

  String get title;

  /// The day it belongs to in the plan (departure, check-in, or the event).
  DateTime? get date;
}

final class ParsedTravel extends ParsedBooking {
  const ParsedTravel(this.item,
      {required super.parsedBy, super.price, super.pages, super.originalLanguage, super.passengerCount});

  /// Draft with a temporary id; every field the booking showed is filled.
  final TravelItem item;

  /// Same booking after an edit in the Add sheet.
  ParsedTravel withItem(TravelItem i) => ParsedTravel(i,
      parsedBy: parsedBy, price: price, pages: pages,
      originalLanguage: originalLanguage, passengerCount: passengerCount);

  @override
  String get title => item.title;
  @override
  DateTime? get date => item.date;
}

final class ParsedStay extends ParsedBooking {
  const ParsedStay(this.stay,
      {required super.parsedBy,
      this.guests = const [],
      super.price,
      super.pages,
      super.originalLanguage,
      super.passengerCount});

  /// Draft with a temporary id, trip and creator.
  final Accommodation stay;

  /// Guests named on the booking, matched to trip members where possible.
  /// Not stored on the stay — they decide who shares its receipt.
  final List<TravelTraveller> guests;

  ParsedStay withStay(Accommodation s) => ParsedStay(s,
      parsedBy: parsedBy, guests: guests, price: price, pages: pages,
      originalLanguage: originalLanguage, passengerCount: passengerCount);

  @override
  String get title => stay.name;
  @override
  DateTime? get date => stay.checkIn;
}

final class ParsedPlan extends ParsedBooking {
  const ParsedPlan(this.item,
      {required this.day,
      required super.parsedBy,
      super.price,
      super.pages,
      super.originalLanguage,
      super.passengerCount});

  /// Draft with a temporary id and no day yet ([day] picks it at save time).
  final ItineraryItem item;
  final DateTime? day;

  ParsedPlan withItem(ItineraryItem i, {required DateTime? day}) => ParsedPlan(i,
      day: day, parsedBy: parsedBy, price: price, pages: pages,
      originalLanguage: originalLanguage, passengerCount: passengerCount);

  @override
  String get title => item.title;
  @override
  DateTime? get date => day;
}

// ─── Price ────────────────────────────────────────────────────────────────────

enum PaidStatus { paid, due, partPaid, unknown }

/// A booking's price as printed: the cash total, its breakdown, and whether
/// it's paid. Becomes a receipt in Money when paid.
class BookingPrice {
  const BookingPrice({
    required this.total,
    required this.currency,
    this.currencyGuessed = false,
    this.lines = const [],
    this.status = PaidStatus.unknown,
    this.amountDue,
    this.points,
  });

  /// Cash total (for points bookings, just the taxes/fees).
  final double total;
  final String currency;

  /// The booking's currency wasn't clear ("\$", none shown) — check it.
  final bool currencyGuessed;

  /// The printed breakdown (fares, bags, nights, taxes); empty for a bare total.
  final List<({String label, double quantity, double amount})> lines;
  final PaidStatus status;

  /// Still to pay (at the hotel, on arrival).
  final double? amountDue;

  /// e.g. "35,000 Aeroplan points".
  final String? points;

  /// The lines are there but don't add up to the total — a misread.
  bool get linesMismatch =>
      lines.isNotEmpty && (lines.fold(0.0, (a, l) => a + l.amount) - total).abs() > 0.5;

  /// Paid (or a deposit) — something to put in Money now.
  bool get isPaid => status == PaidStatus.paid || status == PaidStatus.partPaid;

  /// What has actually been paid: the total minus anything still due.
  double get paidAmount =>
      status == PaidStatus.partPaid && amountDue != null ? total - amountDue! : total;
}
