import 'dart:typed_data';
import '../../data/travel_data.dart';
import 'gemini_parser.dart';
import 'itinerary_parser.dart';
import 'ocr_service.dart';
import 'parsed_booking.dart';

/// Unified entry point: tries Gemini AI first, falls back to on-device OCR+regex.
abstract final class ItineraryScanner {
  static Future<({List<ParsedBooking> bookings, String source})> scan(
    Uint8List bytes,
    String ext,
  ) async {
    // ── Try Gemini AI ────────────────────────────────────────────────────────
    if (GeminiParser.isAvailable) {
      try {
        final results = await GeminiParser.parse(bytes, ext);
        if (results.isNotEmpty) return (bookings: results, source: 'gemini');
        // Gemini returned 0 → fall through to OCR
      } on GeminiApiException {
        // Quota / auth / model error → fall through to OCR
      } catch (_) {
        // Network / parse error → fall through to OCR
      }
    }

    // ── Fallback: on-device OCR + regex ──────────────────────────────────────
    final text = await OcrService.extractTextFromBytes(bytes, ext);
    if (text == null || text.trim().isEmpty) {
      return (bookings: <ParsedBooking>[], source: 'ocr');
    }
    final flights = ItineraryParser.parse(text);
    final bookings = flights.map((f) => ParsedBooking(
          itemType:      TravelItemType.flight,
          title:         f.title,
          date:          f.date,
          notes:         f.notes,
          parsedBy:      'ocr',
          flightNumber:  f.flightNumber,
          airline:       f.airline,
          departureCity: f.departureCity,
          arrivalCity:   f.arrivalCity,
          departureTime: f.departureTime,
          arrivalTime:   f.arrivalTime,
          nextDay:       f.nextDay,
          cabinClass:    f.cabinClass,
        )).toList();
    return (bookings: bookings, source: 'ocr');
  }
}
