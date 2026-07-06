import 'dart:typed_data';
import '../../data/travel_data.dart';
import 'gemini_parser.dart';
import 'itinerary_parser.dart';
import 'ocr_service.dart';
import 'parsed_booking.dart';

typedef ScanResult = ({List<ParsedBooking> bookings, String source});

/// Unified entry point for itinerary parsing.
///
/// [scanWithAi]  — Gemini only. Returns empty if key unavailable / quota hit.
/// [scanWithOcr] — On-device only: ML Kit for images, Syncfusion for PDFs.
/// [scan]        — AI first, OCR fallback (legacy / single-tap path).
abstract final class ItineraryScanner {
  // ── AI-only ───────────────────────────────────────────────────────────────

  static Future<ScanResult> scanWithAi(Uint8List bytes, String ext) async {
    if (!GeminiParser.isAvailable) {
      return (bookings: <ParsedBooking>[], source: 'no_key');
    }
    try {
      final results = await GeminiParser.parse(bytes, ext);
      return (bookings: results, source: 'gemini');
    } on GeminiApiException catch (e) {
      return (bookings: <ParsedBooking>[], source: 'gemini_error_${e.statusCode}');
    } catch (_) {
      return (bookings: <ParsedBooking>[], source: 'gemini_error');
    }
  }

  // ── OCR-only (images via ML Kit, PDFs via Syncfusion) ────────────────────

  static Future<ScanResult> scanWithOcr(Uint8List bytes, String ext) async {
    final text = await OcrService.extractTextFromBytes(bytes, ext);
    if (text == null || text.trim().isEmpty) {
      return (bookings: <ParsedBooking>[], source: 'ocr');
    }
    final flights = ItineraryParser.parse(text);
    return (
      bookings: flights.map((f) => ParsedBooking(
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
          )).toList(),
      source: 'ocr',
    );
  }

  // ── AI first, OCR fallback ────────────────────────────────────────────────

  static Future<ScanResult> scan(Uint8List bytes, String ext) async {
    if (GeminiParser.isAvailable) {
      try {
        final results = await GeminiParser.parse(bytes, ext);
        if (results.isNotEmpty) return (bookings: results, source: 'gemini');
      } on GeminiApiException {
        // fall through to OCR
      } catch (_) {
        // fall through to OCR
      }
    }
    return scanWithOcr(bytes, ext);
  }
}
