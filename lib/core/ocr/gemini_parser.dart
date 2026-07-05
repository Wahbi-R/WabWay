import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../data/travel_data.dart';
import 'parsed_booking.dart';
import 'parse_counter.dart';

abstract final class GeminiParser {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const _model  = 'gemini-1.5-flash';
  static const _url    =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static bool get isAvailable => _apiKey.isNotEmpty;

  static const _prompt = '''
You are a travel itinerary parser. Extract every booking visible in this image.

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

    final response = await http
        .post(
          Uri.parse('$_url?key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) return [];

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
        _               => 'image/jpeg',
      };
}
