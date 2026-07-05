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

// ─── Internal draft (two-pass parser) ────────────────────────────────────────

class _Draft {
  String flightNumber;
  String depCity;
  String arrCity;
  String depTime;
  DateTime depDate;
  String? airline;

  _Draft({
    required this.flightNumber,
    required this.depCity,
    required this.arrCity,
    required this.depTime,
    required this.depDate,
    this.airline,
  });
}

// ─── Main parser ──────────────────────────────────────────────────────────────

class ItineraryParser {
  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
    'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
    'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  // ── Shared patterns ──────────────────────────────────────────────────────

  // "November 6, 2026" or "November 6"
  static final _longDateRe = RegExp(
    r'\b(January|February|March|April|May|June|July|August|September|October|November|December)'
    r'\s+(\d{1,2})(?:,\s*(\d{4}))?\b',
    caseSensitive: false,
  );

  // "Nov 6" or "Noy 6" (handle common OCR misreads like Noy→Nov)
  static final _shortDateRe = RegExp(
    r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|Noy|Jal|Aua)\s+(\d{1,2})\b',
    caseSensitive: false,
  );

  // "6:10 a.m." or "3:25 p.m."
  static final _time12Re = RegExp(
    r'(\d{1,2}:\d{2})\s*([ap]\.?m\.?)',
    caseSensitive: false,
  );

  // "City (XXX) to City (YYY)"
  static final _routeRe = RegExp(
    r'([\w][\w\s,\-]+?)\s*\(([A-Z]{3})\)\s+to\s+([\w][\w\s,\-]+?)\s*\(([A-Z]{3})\)',
  );

  // Flight number after a pipe, tolerates garbage prefix (e.g. "9Japan Airlines | JL7815")
  static final _flightAfterPipeRe = RegExp(
    r'[|│]\s*([A-Z]{1,3}\d{1,4})\b',
  );

  // Standalone flight number line (e.g. "JL7815" alone)
  static final _standaloneFlightRe = RegExp(
    r'^\s*[^|]*([A-Z]{1,3}\d{1,4})\s*$',
  );

  // ── Public entry ──────────────────────────────────────────────────────────

  static List<ParsedFlight> parse(String text) {
    final byB = _parseBookingFormat(text);
    if (byB.isNotEmpty) return byB;
    return _parseLegacyFormat(text);
  }

  // ── Format B: Gmail / 2-column booking confirmation ──────────────────────
  //
  // OCR reads the departure column first (all flights, top to bottom) and
  // then the arrival column (all arrival times, in matching order at the end).
  // So: allTimes[0..N-1] = dep times, allTimes[N..2N-1] = arr times.

  static List<ParsedFlight> _parseBookingFormat(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .toList(); // keep blanks so line indices stay aligned

    // ── Pass 1: collect routes + dep times ───────────────────────────────
    final drafts = <_Draft>[];
    DateTime runDate = DateTime.now();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Track long-form dates ("November 6, 2026") as the running section date
      final ldm = _longDateRe.firstMatch(line);
      if (ldm != null) {
        final mon = _monthFromName(ldm.group(1)!);
        final day = int.parse(ldm.group(2)!);
        final year = ldm.group(3) != null ? int.parse(ldm.group(3)!) : _guessYear(mon);
        runDate = DateTime(year, mon, day);
        continue;
      }

      final rm = _routeRe.firstMatch(line);
      if (rm == null) continue;

      final depCity    = rm.group(1)!.trim();
      final arrCity    = rm.group(3)!.trim();

      // Scan forward up to 12 lines for flight number, then dep time+date
      String? flight, airline;
      String? depTime;
      DateTime depDate = runDate;

      for (int j = i + 1; j < lines.length && j <= i + 12; j++) {
        final jLine = lines[j];

        // Flight number: prefer "... | JL7815" form
        if (flight == null) {
          final pf = _flightAfterPipeRe.firstMatch(jLine);
          if (pf != null) {
            flight = pf.group(1);
            // Airline: text before the pipe, strip leading garbage chars
            final pipeIdx = jLine.indexOf('|');
            if (pipeIdx > 0) {
              airline = jLine
                  .substring(0, pipeIdx)
                  .replaceAll(RegExp(r'^[^A-Za-z]+'), '')
                  .replaceAll(RegExp(r'[^A-Za-z\s]'), ' ')
                  .trim();
              if (airline!.isEmpty) airline = null;
            }
            continue;
          }
        }

        // Departure time
        if (depTime == null) {
          final tm = _time12Re.firstMatch(jLine);
          if (tm != null) {
            depTime = _to24h(tm.group(1)!, tm.group(2)!);
            // Look for the accompanying short date in the next few lines
            for (int k = j + 1; k <= j + 3 && k < lines.length; k++) {
              final dm = _shortDateRe.firstMatch(lines[k]);
              if (dm != null) {
                final mon = _monthFromAbbr(dm.group(1)!);
                final day = int.parse(dm.group(2)!);
                if (mon > 0) depDate = DateTime(_guessYear(mon), mon, day);
                break;
              }
            }
            break; // found dep time — stop forward scan
          }
        }
      }

      if (flight == null) continue; // no flight number → not a real booking line

      drafts.add(_Draft(
        flightNumber: flight,
        depCity:      depCity,
        arrCity:      arrCity,
        depTime:      depTime ?? '00:00',
        depDate:      depDate,
        airline:      airline,
      ));
    }

    if (drafts.isEmpty) return [];

    // ── Pass 2: collect ALL 12h times in order of appearance ──────────────
    final allTimes = <(String time, DateTime date)>[];
    for (int i = 0; i < lines.length; i++) {
      final tm = _time12Re.firstMatch(lines[i]);
      if (tm == null) continue;
      final time = _to24h(tm.group(1)!, tm.group(2)!);
      DateTime? date;
      for (int j = i + 1; j <= i + 3 && j < lines.length; j++) {
        final dm = _shortDateRe.firstMatch(lines[j]);
        if (dm != null) {
          final mon = _monthFromAbbr(dm.group(1)!);
          final day = int.parse(dm.group(2)!);
          if (mon > 0) {
            date = DateTime(_guessYear(mon), mon, day);
            break;
          }
        }
      }
      allTimes.add((time, date ?? DateTime.now()));
    }

    final n = drafts.length;
    // If we have at least 2N times: first N = dep, next N = arr
    // Otherwise fall back to dep-only
    return List.generate(n, (i) {
      final d = drafts[i];
      String arrTime = '??:??';
      bool nextDay  = false;

      if (allTimes.length >= n * 2) {
        final arr = allTimes[n + i];
        arrTime = arr.$1;
        nextDay = arr.$2.day != d.depDate.day || arr.$2.month != d.depDate.month;
      }

      return ParsedFlight(
        flightNumber:  d.flightNumber,
        departureCity: d.depCity,
        arrivalCity:   d.arrCity,
        departureTime: d.depTime,
        arrivalTime:   arrTime,
        date:          d.depDate,
        airline:       d.airline,
        nextDay:       nextDay,
      );
    });
  }

  // ── Format A: legacy single-line "HH:MM City (XXX)  HH:MM City (XXX)" ────

  static final _dateReA = RegExp(
    r'(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)[,\s]+(\d{1,2})\s+'
    r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)',
    caseSensitive: false,
  );
  static final _flightReA = RegExp(
    r'\b([A-Z0-9]{2}\d{1,4})\b(?:\s+(?:Operated by|operated by)\s+([^\n]+))?',
  );
  static final _timeReA  = RegExp(r'\b(\d{1,2}:\d{2})\b');
  static final _cityReA  = RegExp(r'^([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s*\(');
  static final _nextDayA = RegExp(r'\+\s*\d');

  static List<ParsedFlight> _parseLegacyFormat(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();
    final results = <ParsedFlight>[];
    DateTime currentDate = DateTime.now();
    String? pendingFlight, pendingAirline, pendingCabin;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      final dm = _dateReA.firstMatch(line);
      if (dm != null) {
        final day = int.tryParse(dm.group(1)!) ?? 1;
        final mon = _months[dm.group(2)!.toLowerCase()] ?? 1;
        currentDate = DateTime(_guessYear(mon), mon, day);
        continue;
      }

      final fm = _flightReA.firstMatch(line);
      if (fm != null) {
        pendingFlight = fm.group(1)!.trim();
        final rawAirline = fm.group(2)?.trim();
        pendingAirline = (rawAirline != null && rawAirline.isNotEmpty)
            ? rawAirline.replaceAll(RegExp(r'\s{2,}.*'), '').trim()
            : null;
        pendingCabin = null;
        continue;
      }

      final cm = RegExp(r'Cabin[:\s]+([A-Za-z ]+?)(?:\s+Booking|$)', caseSensitive: false)
          .firstMatch(line);
      if (cm != null && pendingFlight != null) {
        pendingCabin = cm.group(1)?.trim();
        continue;
      }

      if (pendingFlight != null) {
        final times = _timeReA.allMatches(line).toList();
        if (times.length >= 2) {
          final depCity = _extractCityA(line, times[0].end);
          final arrCity = _extractCityA(line, times[1].end);
          if (depCity != null && arrCity != null) {
            results.add(ParsedFlight(
              flightNumber:  pendingFlight,
              departureCity: depCity,
              arrivalCity:   arrCity,
              departureTime: times[0].group(1)!,
              arrivalTime:   times[1].group(1)!,
              date:          currentDate,
              airline:       pendingAirline,
              cabinClass:    pendingCabin,
              nextDay:       _nextDayA.hasMatch(line),
            ));
            pendingFlight = pendingAirline = pendingCabin = null;
          }
        }
      }
    }

    return results;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _to24h(String time, String ampm) {
    final parts = time.split(':');
    var h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final isPm = ampm.toLowerCase().replaceAll('.', '').startsWith('p');
    if (isPm && h != 12) h += 12;
    if (!isPm && h == 12) h = 0;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String? _extractCityA(String line, int afterIndex) {
    final sub = line.substring(afterIndex).trimLeft();
    final m = _cityReA.firstMatch(sub.replaceFirst(RegExp(r'^(\+\d\s+)?'), ''));
    return m?.group(1)?.trim();
  }

  static int _monthFromName(String name) {
    return _months[name.toLowerCase().substring(0, 3)] ?? 0;
  }

  // Accepts common OCR misreads: "Noy" → Nov, "Jal" → Jan, "Aua" → Aug
  static int _monthFromAbbr(String abbr) {
    const fixes = {'noy': 'nov', 'jal': 'jan', 'aua': 'aug'};
    final key = abbr.toLowerCase();
    return _months[fixes[key] ?? key] ?? 0;
  }

  static int _guessYear(int month) {
    final now = DateTime.now();
    if (month < now.month) return now.year + 1;
    return now.year;
  }
}
