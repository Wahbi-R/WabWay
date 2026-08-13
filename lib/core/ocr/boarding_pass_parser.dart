import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Data extracted from a scanned boarding pass.
class BoardingPassData {
  const BoardingPassData({
    this.flightNumber,
    this.airline,
    this.confirmationNumber,
    this.passengerName,
    this.departureAirport,
    this.arrivalAirport,
    this.departureCity,
    this.arrivalCity,
    this.date,
    this.departureTime,
    this.arrivalTime,
    this.nextDay = false,
    this.departureTerminal,
    this.arrivalTerminal,
    this.gate,
    this.seat,
    this.boardingTime,
    this.cabinClass,
  });

  final String? flightNumber;
  final String? airline;
  final String? confirmationNumber;
  final String? passengerName;
  final String? departureAirport;   // IATA code e.g. "YYZ"
  final String? arrivalAirport;     // IATA code e.g. "NRT"
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? date;
  final String? departureTime;      // "HH:MM"
  final String? arrivalTime;        // "HH:MM"
  final bool nextDay;
  final String? departureTerminal;  // e.g. "Terminal 1" or "T1"
  final String? arrivalTerminal;
  final String? gate;               // e.g. "A22"
  final String? seat;               // e.g. "14C"
  final String? boardingTime;       // "HH:MM"
  final String? cabinClass;

  bool get hasUsefulData =>
      flightNumber != null ||
      departureAirport != null ||
      departureTerminal != null;

  String buildTitle() {
    if (flightNumber != null && departureCity != null && arrivalCity != null) {
      return '$flightNumber — $departureCity → $arrivalCity';
    }
    if (flightNumber != null && departureAirport != null && arrivalAirport != null) {
      return '$flightNumber — $departureAirport → $arrivalAirport';
    }
    if (flightNumber != null) return flightNumber!;
    return '';
  }

  String buildLocationField() {
    final parts = <String>[];
    if (departureCity != null) parts.add(departureCity!);
    if (departureAirport != null) parts.add('($departureAirport)');
    return parts.join(' ');
  }

  String buildDestinationField() {
    final parts = <String>[];
    if (arrivalCity != null) parts.add(arrivalCity!);
    if (arrivalAirport != null) parts.add('($arrivalAirport)');
    return parts.join(' ');
  }
}

abstract final class BoardingPassParser {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const _model  = 'gemini-2.0-flash';
  static const _url    =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static bool get isAvailable => _apiKey.isNotEmpty;

  static const _prompt = '''
You are reading a boarding pass image. Extract every piece of information visible.

Return a single JSON object (no markdown, no explanation) with these fields — use null for anything not visible:

{
  "flightNumber":       "e.g. NH806",
  "airline":            "e.g. All Nippon Airways",
  "confirmationNumber": "PNR / booking reference, e.g. K4X7QP",
  "passengerName":      "as printed",
  "departureAirport":   "IATA code, e.g. YYZ",
  "arrivalAirport":     "IATA code, e.g. NRT",
  "departureCity":      "city name, e.g. Toronto",
  "arrivalCity":        "city name, e.g. Tokyo",
  "date":               "YYYY-MM-DD",
  "departureTime":      "HH:MM (24h)",
  "arrivalTime":        "HH:MM (24h)",
  "nextDay":            true or false — true if flight lands the day after departure,
  "departureTerminal":  "e.g. Terminal 1 or T1",
  "arrivalTerminal":    "e.g. Terminal 3 or T3",
  "gate":               "e.g. A22 or Gate 42",
  "seat":               "e.g. 14C",
  "boardingTime":       "HH:MM (24h)",
  "cabinClass":         "Economy / Business / First"
}

If this is not a boarding pass, return null.
''';

  static Future<BoardingPassData?> parse(Uint8List bytes, String ext) async {
    if (!isAvailable) return null;

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

    if (response.statusCode != 200) return null;

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final text    = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null || text.trim() == 'null') return null;
      final j = jsonDecode(text) as Map<String, dynamic>?;
      if (j == null) return null;
      return _fromJson(j);
    } catch (_) {
      return null;
    }
  }

  static BoardingPassData _fromJson(Map<String, dynamic> j) {
    return BoardingPassData(
      flightNumber:       j['flightNumber']       as String?,
      airline:            j['airline']             as String?,
      confirmationNumber: j['confirmationNumber']  as String?,
      passengerName:      j['passengerName']       as String?,
      departureAirport:   j['departureAirport']    as String?,
      arrivalAirport:     j['arrivalAirport']      as String?,
      departureCity:      j['departureCity']       as String?,
      arrivalCity:        j['arrivalCity']         as String?,
      date:               DateTime.tryParse(j['date'] as String? ?? ''),
      departureTime:      j['departureTime']       as String?,
      arrivalTime:        j['arrivalTime']         as String?,
      nextDay:            j['nextDay']             as bool? ?? false,
      departureTerminal:  j['departureTerminal']   as String?,
      arrivalTerminal:    j['arrivalTerminal']     as String?,
      gate:               j['gate']                as String?,
      seat:               j['seat']                as String?,
      boardingTime:       j['boardingTime']        as String?,
      cabinClass:         j['cabinClass']          as String?,
    );
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
