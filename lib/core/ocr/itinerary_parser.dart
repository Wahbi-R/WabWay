import '../../data/travel_data.dart';

class ParsedFlight {
  const ParsedFlight({
    required this.flightNumber,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureTime,
    required this.arrivalTime,
    required this.date,
    this.airline,
    this.cabinClass,
    this.nextDay = false,
  });

  final String flightNumber;
  final String departureCity;
  final String arrivalCity;
  final String departureTime;
  final String arrivalTime;
  final DateTime date;
  final String? airline;
  final String? cabinClass;
  final bool nextDay;

  String get title => '$flightNumber: $departureCity → $arrivalCity';

  String get notes {
    final parts = <String>[];
    if (airline != null) parts.add('Operated by $airline');
    if (cabinClass != null) parts.add('Cabin: $cabinClass');
    parts.add('Dep: $departureTime  Arr: $arrivalTime${nextDay ? ' (+1)' : ''}');
    return parts.join('\n');
  }

  TravelItemType get itemType => TravelItemType.flight;
}

class ItineraryParser {
  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
    'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
    'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static final _dateRe = RegExp(
    r'(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)[,\s]+(\d{1,2})\s+'
    r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)',
    caseSensitive: false,
  );

  static final _flightRe = RegExp(
    r'\b([A-Z0-9]{2}\d{1,4})\b(?:\s+(?:Operated by|operated by)\s+([^\n]+))?',
  );

  static final _timeRe = RegExp(r'\b(\d{1,2}:\d{2})\b');

  static final _nextDayRe = RegExp(r'\+\s*(\d)');

  static final _cityRe = RegExp(r'^([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s*\(');

  static final _cabinRe = RegExp(
    r'Cabin[:\s]+([A-Za-z ]+?)(?:\s+Booking|$)',
    caseSensitive: false,
  );

  static List<ParsedFlight> parse(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();
    final results = <ParsedFlight>[];

    DateTime currentDate = DateTime.now();
    String? pendingFlight;
    String? pendingAirline;
    String? pendingCabin;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // --- date header ---
      final dm = _dateRe.firstMatch(line);
      if (dm != null) {
        final day = int.tryParse(dm.group(1)!) ?? 1;
        final mon = _months[dm.group(2)!.toLowerCase()] ?? 1;
        final year = _guessYear(mon);
        currentDate = DateTime(year, mon, day);
        continue;
      }

      // --- flight number line ---
      final fm = _flightRe.firstMatch(line);
      if (fm != null) {
        // save previous if any
        pendingFlight = fm.group(1)!.trim();
        final rawAirline = fm.group(2)?.trim();
        pendingAirline = rawAirline != null && rawAirline.isNotEmpty
            ? rawAirline.replaceAll(RegExp(r'\s{2,}.*'), '').trim()
            : null;
        pendingCabin = null;
        continue;
      }

      // --- cabin line ---
      final cm = _cabinRe.firstMatch(line);
      if (cm != null && pendingFlight != null) {
        pendingCabin = cm.group(1)?.trim();
        continue;
      }

      // --- time line: "06:00 City Name (Airport)   07:15 City Name (Airport)" ---
      if (pendingFlight != null) {
        final times = _timeRe.allMatches(line).toList();
        if (times.length >= 2) {
          // Try to extract city names from the same line
          final depTime = times[0].group(1)!;
          final arrTime = times[1].group(1)!;
          final nextDay = _nextDayRe.hasMatch(line);

          // Extract city names: text between time and '('
          final depCity = _extractCity(line, times[0].end);
          final arrCity = _extractCity(line, times[1].end);

          if (depCity != null && arrCity != null) {
            results.add(ParsedFlight(
              flightNumber: pendingFlight,
              departureCity: depCity,
              arrivalCity: arrCity,
              departureTime: depTime,
              arrivalTime: arrTime,
              date: currentDate,
              airline: pendingAirline,
              cabinClass: pendingCabin,
              nextDay: nextDay,
            ));
            pendingFlight = null;
            pendingAirline = null;
            pendingCabin = null;
          }
        }
      }
    }

    return results;
  }

  static String? _extractCity(String line, int afterIndex) {
    final sub = line.substring(afterIndex).trimLeft();
    // remove leading time/+1 noise
    final cleaned = sub.replaceFirst(RegExp(r'^(\+\d\s+)?'), '');
    final m = _cityRe.firstMatch(cleaned);
    return m?.group(1)?.trim();
  }

  static int _guessYear(int month) {
    final now = DateTime.now();
    // if the month is earlier than now, assume next year
    if (month < now.month) return now.year + 1;
    return now.year;
  }
}
