import '../../data/travel_data.dart';

/// A travel booking extracted from an itinerary image.
/// Used by both the Gemini AI parser and the OCR+regex fallback.
class ParsedBooking {
  const ParsedBooking({
    required this.itemType,
    required this.title,
    required this.date,
    required this.notes,
    required this.parsedBy,
    this.flightNumber,
    this.departureCity,
    this.arrivalCity,
    this.departureTime,
    this.arrivalTime,
    this.airline,
    this.cabinClass,
    this.nextDay = false,
  });

  final TravelItemType itemType;
  final String title;
  final DateTime date;
  final String notes;
  final String parsedBy; // 'gemini' or 'ocr'

  // Flight / train fields (nullable for hotels/reservations)
  final String? flightNumber;
  final String? departureCity;
  final String? arrivalCity;
  final String? departureTime;
  final String? arrivalTime;
  final String? airline;
  final String? cabinClass;
  final bool nextDay;

  bool get isAi => parsedBy == 'gemini';
}
