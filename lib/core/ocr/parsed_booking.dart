import '../../data/accommodation_data.dart';
import '../../data/plan_data.dart';
import '../../data/travel_data.dart';

/// A booking found in a shared file, email or link, already shaped as the
/// item it becomes: travel (flight/train/bus/ferry/car), stay, or plan item
/// (tickets, restaurant reservations). Produced by [BookingParseService]
/// (server AI) or the on-device OCR fallback; saved by the review screen.
sealed class ParsedBooking {
  const ParsedBooking({required this.parsedBy});

  /// 'ai' or 'ocr'.
  final String parsedBy;
  bool get isAi => parsedBy == 'ai';

  String get title;

  /// The day it belongs to in the plan (departure, check-in, or the event).
  DateTime? get date;
}

final class ParsedTravel extends ParsedBooking {
  const ParsedTravel(this.item, {required super.parsedBy});

  /// Draft with a temporary id; every field the booking showed is filled.
  final TravelItem item;

  @override
  String get title => item.title;
  @override
  DateTime? get date => item.date;
}

final class ParsedStay extends ParsedBooking {
  const ParsedStay(this.stay, {required super.parsedBy});

  /// Draft with a temporary id, trip and creator.
  final Accommodation stay;

  @override
  String get title => stay.name;
  @override
  DateTime? get date => stay.checkIn;
}

final class ParsedPlan extends ParsedBooking {
  const ParsedPlan(this.item, {required this.day, required super.parsedBy});

  /// Draft with a temporary id and no day yet ([day] picks it at save time).
  final ItineraryItem item;
  final DateTime? day;

  @override
  String get title => item.title;
  @override
  DateTime? get date => day;
}
