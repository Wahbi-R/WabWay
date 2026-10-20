import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../data/accommodation_data.dart';
import '../data/money_data.dart' show fmtAmount;
import '../data/plan_data.dart';
import '../data/travel_data.dart';
import 'ocr/parsed_booking.dart';
import 'supabase/client.dart';
import 'text_utils.dart';

/// What to read: files (PDF / screenshots), shared email text, and/or a
/// confirmation link. Any combination; at least one.
class BookingSource {
  const BookingSource({this.files = const [], this.text, this.url});
  final List<({Uint8List bytes, String ext})> files;
  final String? text;
  final String? url;

  bool get isEmpty =>
      files.isEmpty && (text?.trim().isEmpty ?? true) && (url?.trim().isEmpty ?? true);
}

/// The bookings found, or why there aren't any.
class BookingParseOutcome {
  const BookingParseOutcome._(this.bookings, this.error);
  const BookingParseOutcome.ok(List<ParsedBooking> b) : this._(b, null);
  const BookingParseOutcome.failed(String message) : this._(const [], message);

  final List<ParsedBooking> bookings;
  final String? error;
}

/// "Read booking": sends the shared content to wabway-server, which reads it
/// with Claude and returns every booking in it — flights, trains, buses,
/// ferries, car hire, stays, tickets and reservations — with passengers
/// matched to trip members. Signed-in trip members only (Supabase token).
abstract final class BookingParseService {
  static const _url = 'https://audio.wabble.ca/booking/parse';

  /// Under Cloudflare's ~100 s tunnel limit (long multi-leg PDFs take a while).
  static const timeout = Duration(seconds: 95);

  /// Never throws.
  static Future<BookingParseOutcome> parse(
    BookingSource source, {
    required String tripId,
    required String userId,
  }) async {
    if (source.isEmpty) {
      return const BookingParseOutcome.failed('Share a PDF, screenshot, email or link first.');
    }
    if (source.files.any((f) => _mediaType(f.ext) == null)) {
      return const BookingParseOutcome.failed(
          "That file type can't be read — share a PDF, JPEG or PNG.");
    }
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null) {
      return const BookingParseOutcome.failed('Sign in again to read bookings.');
    }
    try {
      final response = await http
          .post(
            Uri.parse(_url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'trip_id': tripId,
              'files': [
                for (final f in source.files)
                  {'data': base64Encode(f.bytes), 'media_type': _mediaType(f.ext)},
              ],
              if (source.text?.trim().isNotEmpty ?? false) 'text': source.text!.trim(),
              if (source.url?.trim().isNotEmpty ?? false) 'url': source.url!.trim(),
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        return BookingParseOutcome.failed(_messageFor(response));
      }
      final raw = (jsonDecode(response.body) as Map)['bookings'] as List? ?? const [];
      final bookings = fromServer(raw, tripId: tripId, userId: userId);
      if (bookings.isEmpty) {
        return const BookingParseOutcome.failed(
            "Couldn't find a booking in that — add it by hand instead.");
      }
      return BookingParseOutcome.ok(bookings);
    } on TimeoutException {
      return const BookingParseOutcome.failed(
          'Reading took too long — try one booking at a time.');
    } catch (_) {
      return const BookingParseOutcome.failed(
          "Can't reach WabWay's booking reader (offline?) — try again, or add it by hand.");
    }
  }

  static String? _mediaType(String ext) => switch (ext.toLowerCase()) {
        'pdf'           => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png'           => 'image/png',
        'webp'          => 'image/webp',
        'gif'           => 'image/gif',
        _               => null,
      };

  static String _messageFor(http.Response r) {
    String detail = '';
    try {
      detail = ((jsonDecode(r.body) as Map)['detail'] as String?) ?? '';
    } catch (_) {}
    return switch (r.statusCode) {
      401 => 'Sign in again to read bookings.',
      403 => "You're not in this trip any more.",
      415 => "That photo format can't be read — use a JPEG, PNG or PDF.",
      429 => detail.isNotEmpty ? detail : 'Too many bookings read this hour — try later.',
      503 => "The booking reader is switched off right now — add it by hand.",
      _   => detail.isNotEmpty && r.statusCode == 400
          ? detail
          : 'Reading failed (${r.statusCode}) — try again, or add it by hand.',
    };
  }

  // ─── Server JSON → drafts ───────────────────────────────────────────────────

  /// Maps the server's bookings to drafts. Public for tests.
  static List<ParsedBooking> fromServer(
    List raw, {
    required String tripId,
    required String userId,
  }) {
    final out = <ParsedBooking>[];
    for (var i = 0; i < raw.length; i++) {
      final b = Map<String, dynamic>.from(raw[i] as Map);
      final id = 'parsed_$i';
      final booking = switch (b['kind']) {
        'travel' => _travel(id, b),
        'stay'   => _stay(id, b, tripId: tripId, userId: userId),
        'plan'   => _plan(id, b),
        _        => null,
      };
      if (booking != null) out.add(booking);
    }
    return out;
  }

  static String? _s(Map b, String k) {
    final v = b[k];
    return v is String && v.trim().isNotEmpty ? v.trim() : null;
  }

  static DateTime? _d(Map b, String k) => DateTime.tryParse(_s(b, k) ?? '');

  static double? _n(Map b, String k) => (b[k] as num?)?.toDouble();

  static String? _price(Map b) {
    final total = _n(b, 'price_total');
    return total == null ? null : 'Total ${fmtAmount(total, _s(b, 'currency') ?? '')}';
  }

  static ParsedTravel? _travel(String id, Map<String, dynamic> b) {
    final title = _s(b, 'title');
    if (title == null) return null;
    final travellers = [
      for (final t in (b['travellers'] as List? ?? const []))
        if (t is Map)
          TravelTraveller(
            userId: t['member_id'] as String?,
            // Keep the printed name only when it isn't matched to a member.
            name: t['member_id'] == null ? t['name'] as String? : null,
            seat: t['seat'] as String?,
          ),
    ];
    final date = _d(b, 'date');
    final endDate = _d(b, 'end_date');
    return ParsedTravel(
      TravelItem(
        id: id,
        title: title,
        type: TravelItemType.values
            .firstWhere((t) => t.name == b['travel_type'], orElse: () => TravelItemType.other),
        date: date,
        endDate: endDate == null || endDate == date ? null : endDate,
        time: _s(b, 'time'),
        endTime: _s(b, 'end_time'),
        location: _s(b, 'from'),
        destination: _s(b, 'to'),
        confirmationNumber: _s(b, 'confirmation_number'),
        url: _s(b, 'url'),
        address: _s(b, 'address'),
        departureTerminal: _s(b, 'departure_terminal'),
        arrivalTerminal: _s(b, 'arrival_terminal'),
        gate: _s(b, 'gate'),
        boardingTime: _s(b, 'boarding_time'),
        // Seats live on each traveller, not the item's single seat field.
        travellers: travellers,
        notes: _notes([
          joinNonEmpty([_s(b, 'operator'), _s(b, 'cabin_class')]),
          _price(b),
          _s(b, 'notes'),
        ]),
      ),
      parsedBy: 'ai',
    );
  }

  static ParsedStay? _stay(String id, Map<String, dynamic> b,
      {required String tripId, required String userId}) {
    final name = _s(b, 'title');
    if (name == null) return null;
    final checkIn = _d(b, 'date');
    final checkOut = _d(b, 'end_date');
    final total = _n(b, 'price_total');
    final nights = checkIn != null && checkOut != null ? checkOut.difference(checkIn).inDays : 0;
    final perNight = _n(b, 'price_per_night') ??
        (total != null && nights > 0 ? (total / nights * 100).round() / 100 : null);
    final confirmation = _s(b, 'confirmation_number');
    final url = _s(b, 'url');
    return ParsedStay(
      Accommodation(
        id: id,
        tripId: tripId,
        name: name,
        city: _s(b, 'city') ?? '',
        address: _s(b, 'address'),
        url: url,
        pricePerNight: perNight,
        currency: _s(b, 'currency') ?? 'USD',
        checkIn: checkIn,
        checkOut: checkOut,
        checkInTime: _s(b, 'check_in_time'),
        checkOutTime: _s(b, 'check_out_time'),
        status: confirmation != null || total != null
            ? AccommodationStatus.booked
            : AccommodationStatus.shortlisted,
        source: url == null ? null : AccommodationSource.fromUrl(url),
        confirmationNumber: confirmation,
        notes: _notes([_price(b), _s(b, 'notes')]),
        createdBy: userId,
        createdAt: DateTime.now(),
      ),
      parsedBy: 'ai',
    );
  }

  static ParsedPlan? _plan(String id, Map<String, dynamic> b) {
    final title = _s(b, 'title');
    if (title == null) return null;
    final confirmation = _s(b, 'confirmation_number');
    return ParsedPlan(
      ItineraryItem(
        id: id,
        dayId: '',
        title: title,
        type: switch (b['plan_type']) {
          'food'     => ItineraryItemType.food,
          'activity' => ItineraryItemType.activity,
          _          => ItineraryItemType.other,
        },
        time: _s(b, 'time'),
        city: _s(b, 'city'),
        location: _s(b, 'address') ?? _s(b, 'from'),
        confirmationUrl: _s(b, 'url'),
        notes: _notes([
          if (confirmation != null) 'Confirmation: $confirmation',
          _s(b, 'notes'),
        ]),
        plannedCost: _n(b, 'price_total'),
        currency: _s(b, 'currency'),
      ),
      day: _d(b, 'date'),
      parsedBy: 'ai',
    );
  }

  static String? _notes(List<String?> parts) {
    final text = parts.where((p) => p != null && p.trim().isNotEmpty).join('\n');
    return text.isEmpty ? null : text;
  }
}
