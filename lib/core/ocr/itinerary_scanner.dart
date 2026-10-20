import 'dart:typed_data';
import '../../data/travel_data.dart';
import 'itinerary_parser.dart';
import 'ocr_service.dart';
import 'parsed_booking.dart';

/// On-device fallback for "Read booking" when the server can't be reached:
/// ML Kit (images) / Syncfusion (PDFs) text, then flight-number patterns.
/// Only finds flights; everything else needs the server reader
/// ([BookingParseService]).
abstract final class ItineraryScanner {
  static Future<List<ParsedBooking>> scanWithOcr(Uint8List bytes, String ext) async {
    final text = await OcrService.extractTextFromBytes(bytes, ext);
    if (text == null || text.trim().isEmpty) return const [];
    return [
      for (final (i, f) in ItineraryParser.parse(text).indexed)
        ParsedTravel(
          TravelItem(
            id: 'ocr_$i',
            title: f.title,
            type: TravelItemType.flight,
            date: f.date,
            endDate: f.nextDay ? f.date.add(const Duration(days: 1)) : null,
            time: f.departureTime,
            endTime: f.arrivalTime,
            location: f.departureCity,
            destination: f.arrivalCity,
            notes: f.notes,
          ),
          parsedBy: 'ocr',
        ),
    ];
  }
}
