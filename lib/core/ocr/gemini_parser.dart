import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../data/travel_data.dart';
import 'parsed_booking.dart';
import 'parse_counter.dart';

abstract final class GeminiParser {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const _model  = 'gemini-2.0-flash';
  static const _url    =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static bool get isAvailable => _apiKey.isNotEmpty;

  /// Last HTTP status from the Gemini API (0 if never called).
  static int lastHttpStatus = 0;
  /// First 400 chars of the last Gemini response body, for debug display.
  static String lastResponseSnippet = '';

  static const _prompt = '''
You are a travel itinerary parser. Extract every booking from the provided document or image.

Return a JSON array (no markdown, no explanation). Each element must have:
  "type"  : "flight" | "hotel" | "train" | "reservation"
  "title" : human-readable label (e.g. "JL7451: Toronto → Tokyo" or "Hotel Gracery Shinjuku")
  "date"  : "YYYY-MM-DD" (departure date or check-in date)
  "notes" : any extra info (cabin class, confirmation number, nights, room type, etc.)

For flights and trains also include:
  "flightNumber"   : string
  "airline"        : string or null
  "departureCity"  : string
  "arrivalCity"    : string
  "departureTime"  : "HH:MM" or null
  "arrivalTime"    : "HH:MM" or null
  "nextDay"        : true | false
  "cabinClass"     : string or null

If nothing is found return an empty array [].
''';

  static Future<List<ParsedBooking>> parse(Uint8List bytes, String ext) async {
    if (!isAvailable) return [];
    final remaining = await ParseCounter.remaining();
    if (remaining <= 0) return [];

    final mimeType = _mimeType(ext);
    final b64      = base64Encode(bytes);

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _prompt},
            {'inline_data': {'mime_type': mimeType, 'data': b64}},
          ],
        }
      ],
      'generationConfig': {'responseMimeType': 'application/json'},
    });

    // ignore: avoid_print
    print('[Gemini] sending ${bytes.length} bytes as $mimeType');
    final response = await http
        .post(
          Uri.parse('$_url?key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    lastHttpStatus = response.statusCode;
    lastResponseSnippet = response.body.substring(
        0, response.body.length.clamp(0, 400));
    // ignore: avoid_print
    print('[Gemini] status=${response.statusCode} body=$lastResponseSnippet');

    if (response.statusCode != 200) {
      throw GeminiApiException(response.statusCode, lastResponseSnippet);
    }

    await ParseCounter.increment();

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final text = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '[]';
    final list = (jsonDecode(text) as List?)?.cast<Map<String, dynamic>>() ?? [];

    return list.map(_fromJson).whereType<ParsedBooking>().toList();
  }

  static ParsedBooking? _fromJson(Map<String, dynamic> j) {
    try {
      final type  = j['type'] as String? ?? 'reservation';
      final title = j['title'] as String? ?? '';
      if (title.isEmpty) return null;

      final rawDate = j['date'] as String? ?? '';
      final date    = DateTime.tryParse(rawDate) ?? DateTime.now();
      final notes   = j['notes'] as String? ?? '';

      final itemType = switch (type) {
        'flight'      => TravelItemType.flight,
        'hotel'       => TravelItemType.hotel,
        'train'       => TravelItemType.train,
        'reservation' => TravelItemType.reservation,
        _             => TravelItemType.other,
      };

      return ParsedBooking(
        itemType:      itemType,
        title:         title,
        date:          date,
        notes:         notes,
        parsedBy:      'gemini',
        flightNumber:  j['flightNumber']  as String?,
        airline:       j['airline']       as String?,
        departureCity: j['departureCity'] as String?,
        arrivalCity:   j['arrivalCity']   as String?,
        departureTime: j['departureTime'] as String?,
        arrivalTime:   j['arrivalTime']   as String?,
        nextDay:       j['nextDay']       as bool? ?? false,
        cabinClass:    j['cabinClass']    as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static String _mimeType(String ext) => switch (ext.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png'           => 'image/png',
        'webp'          => 'image/webp',
        'heic'          => 'image/heic',
        'pdf'           => 'application/pdf',
        _               => 'image/jpeg',
      };
}

class GeminiApiException implements Exception {
  final int statusCode;
  final String body;
  const GeminiApiException(this.statusCode, this.body);
  @override
  String toString() => 'GeminiApiException($statusCode): $body';
}
