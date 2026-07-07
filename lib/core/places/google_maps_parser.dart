import 'dart:convert';
import 'dart:io' show HttpClient, HttpHeaders, SocketException;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../../data/spot_data.dart';
import 'nominatim_service.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class MapsPlace {
  const MapsPlace({
    required this.name,
    required this.lat,
    required this.lon,
    this.address,
    this.mapsUrl,
    required this.category,
    this.city = '',
    this.notes,
  });

  final String       name;
  final double       lat;
  final double       lon;
  final String?      address;
  final String?      mapsUrl;
  final SpotCategory category;
  final String       city;
  final String?      notes;

  bool get hasCoords => lat != 0 || lon != 0;

  MapsPlace copyWith({
    String? name,
    double? lat,
    double? lon,
    String? address,
    String? mapsUrl,
    SpotCategory? category,
    String? city,
    String? notes,
  }) =>
      MapsPlace(
        name:     name     ?? this.name,
        lat:      lat      ?? this.lat,
        lon:      lon      ?? this.lon,
        address:  address  ?? this.address,
        mapsUrl:  mapsUrl  ?? this.mapsUrl,
        category: category ?? this.category,
        city:     city     ?? this.city,
        notes:    notes    ?? this.notes,
      );
}

class MapsParseResult {
  const MapsParseResult({
    required this.places,
    required this.isList,
    this.listName,
    this.finalUrl,
    this.noDataReason,
  });

  final List<MapsPlace> places;
  final bool            isList;
  final String?         listName;
  final String?         finalUrl;
  /// Set when we know WHY places is empty, for a better UI message.
  final String?         noDataReason;
}

// ─── Parser ───────────────────────────────────────────────────────────────────

abstract final class GoogleMapsParser {
  static const _ua = 'Mozilla/5.0 (Linux; Android 10; SM-G975U) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Mobile Safari/537.36';

  static Future<MapsParseResult?> parse(String rawUrl) async {
    final fetched = await _fetch(rawUrl);
    if (fetched == null) return null;
    final (html, resolvedUrl) = fetched;
    final url = resolvedUrl ?? rawUrl;

    // ── My Maps — KML export ───────────────────────────────────────────────
    final mid = _myMapsId(url);
    if (mid != null) {
      final r = await _parseMyMaps(mid);
      if (r != null) return r;
    }

    // ── Single place — /maps/place/NAME_AND_ADDRESS/ ───────────────────────
    if (url.contains('/maps/place/')) {
      // First try direct coord extraction (URL has @lat,lon or !3d!4d)
      final direct = _parseSinglePlaceFromCoords(url, html, rawUrl);
      if (direct != null) return direct;
      // Fall back to Nominatim geocoding from the URL text
      final geocoded = await _parseSinglePlaceViaGeocoding(url, rawUrl);
      if (geocoded != null) return geocoded;
    }

    // ── Saved list — JS-rendered, no place data accessible ────────────────
    if (url.contains('/maps/@') || url.contains('placelists')) {
      return MapsParseResult(
        places:       [],
        isList:       true,
        noDataReason: 'saved_list',
        finalUrl:     url,
      );
    }

    // ── Generic fallback ───────────────────────────────────────────────────
    return MapsParseResult(
      places:       [],
      isList:       false,
      noDataReason: 'unknown',
      finalUrl:     url,
    );
  }

  // ── Fetch with redirect tracking ──────────────────────────────────────────

  static Future<(String, String?)?> _fetch(String rawUrl) async {
    if (!kIsWeb) {
      // dart:io HttpClient exposes the full redirect chain so we get the
      // final URL (which contains the place name for individual shares)
      try {
        final client = HttpClient();
        try {
          client.userAgent = _ua;
          client.connectionTimeout = const Duration(seconds: 15);
          final req = await client
              .getUrl(Uri.parse(rawUrl))
              .timeout(const Duration(seconds: 15));
          req.headers.set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');
          req.followRedirects = true;
          req.maxRedirects = 10;
          final resp = await req.close().timeout(const Duration(seconds: 15));

          // Rebuild final URL from redirect chain
          String finalUrl = rawUrl;
          if (resp.redirects.isNotEmpty) {
            final base = Uri.parse(rawUrl);
            finalUrl = base.resolveUri(resp.redirects.last.location).toString();
          }

          final html = await resp
              .transform(utf8.decoder)
              .join()
              .timeout(const Duration(seconds: 15));

          return (html, finalUrl);
        } on SocketException {
          return null;
        } finally {
          client.close();
        }
      } catch (_) {
        return null;
      }
    }

    // Web: http package (no redirect URL tracking)
    try {
      final res = await http
          .get(Uri.parse(rawUrl), headers: {
            'User-Agent': _ua,
            'Accept-Language': 'en-US,en;q=0.9',
          })
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      return (res.body, rawUrl);
    } catch (_) {
      return null;
    }
  }

  // ── My Maps / KML ──────────────────────────────────────────────────────────

  static String? _myMapsId(String url) {
    if (!url.contains('/maps/d/')) return null;
    final uri = Uri.tryParse(url);
    final mid = uri?.queryParameters['mid'];
    if (mid != null && mid.isNotEmpty) return mid;
    final m = RegExp(r'/maps/d/[^/?]+(?:\?mid=)?([A-Za-z0-9_-]{20,})').firstMatch(url);
    return m?.group(1);
  }

  static Future<MapsParseResult?> _parseMyMaps(String mid) async {
    try {
      final kmlUrl = 'https://www.google.com/maps/d/kml?mid=$mid&forcekml=1';
      final res    = await http
          .get(Uri.parse(kmlUrl), headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final kml    = res.body;
      final places = _parseKmlString(kml);
      if (places.isEmpty) return null;
      final nameM  = RegExp(r'<Document>\s*<name>(.*?)</name>', dotAll: true)
          .firstMatch(kml);
      final listName = nameM != null ? _decodeXml(nameM.group(1)!.trim()) : null;
      return MapsParseResult(places: places, isList: true, listName: listName);
    } catch (_) {
      return null;
    }
  }

  static List<MapsPlace> _parseKmlString(String kml) {
    final places = <MapsPlace>[];
    final pmRe   = RegExp(r'<Placemark>.*?</Placemark>', dotAll: true);
    for (final m in pmRe.allMatches(kml)) {
      final block  = m.group(0)!;
      final nameM  = RegExp(r'<name>(.*?)</name>', dotAll: true).firstMatch(block);
      if (nameM == null) continue;
      final name   = _decodeXml(nameM.group(1)!.trim());
      if (name.isEmpty) continue;
      // KML: lon,lat[,elevation]
      final coordM = RegExp(r'<coordinates>\s*([-\d.]+),([-\d.]+)').firstMatch(block);
      if (coordM == null) continue;
      final lon    = double.tryParse(coordM.group(1)!);
      final lat    = double.tryParse(coordM.group(2)!);
      if (!_valid(lat, lon)) continue;
      final descM  = RegExp(r'<description>(.*?)</description>', dotAll: true)
          .firstMatch(block);
      final address = descM != null
          ? _decodeXml(descM.group(1)!.trim())
              .replaceAll(RegExp(r'<[^>]+>'), '')
              .trim()
          : null;
      places.add(MapsPlace(
        name:    name,
        lat:     lat!,
        lon:     lon!,
        address: address?.isEmpty == true ? null : address,
        category: SpotCategory.landmark,
      ));
    }
    return places;
  }

  // ── Single place — coordinate extraction ──────────────────────────────────

  static MapsParseResult? _parseSinglePlaceFromCoords(
      String url, String html, String originalUrl) {
    final coords = _extractCoords(url) ?? _extractCoords(html);
    if (coords == null) return null;
    final (lat, lon) = coords;

    final name = _nameFromPlaceUrl(url) ?? 'Google Maps Place';
    return MapsParseResult(
      places: [
        MapsPlace(
          name:     name,
          lat:      lat,
          lon:      lon,
          mapsUrl:  url,
          category: SpotCategory.landmark,
        ),
      ],
      isList:   false,
      finalUrl: url,
    );
  }

  // ── Single place — Nominatim geocoding fallback ────────────────────────────
  // Used when the Maps URL has no coords (uses place ID instead):
  // e.g. /maps/place/Kotoku-in,+4+Chome-2-28+Hase,+Kamakura,.../data=!4m2...

  static Future<MapsParseResult?> _parseSinglePlaceViaGeocoding(
      String url, String originalUrl) async {
    final pathM = RegExp(r'/maps/place/([^/?]+)').firstMatch(url);
    if (pathM == null) return null;

    final decoded = Uri.decodeComponent(
      pathM.group(1)!.replaceAll('+', ' '),
    ).trim();
    if (decoded.isEmpty) return null;

    // Split into name vs address parts
    final parts   = decoded.split(RegExp(r',\s*'));
    final name    = parts.first.trim();
    final address = parts.length > 1 ? parts.skip(1).join(', ') : null;

    // Try full text first (name + address = most specific query for Nominatim)
    List<NominatimPlace> results = await NominatimService.search(decoded);

    // Fall back to just the place name
    if (results.isEmpty && name.isNotEmpty) {
      results = await NominatimService.search(name);
    }

    if (results.isEmpty) return null;

    final p = results.first;
    return MapsParseResult(
      places: [
        MapsPlace(
          name:     name.isNotEmpty ? name : p.name,
          lat:      p.lat,
          lon:      p.lon,
          address:  address ?? p.displayName,
          mapsUrl:  originalUrl,
          category: p.category,
          city:     p.city,
        ),
      ],
      isList:   false,
      finalUrl: url,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Extracts (lat, lon) trying several patterns in priority order.
  static (double, double)? _extractCoords(String text) {
    // @lat,lon in URL path
    var m = RegExp(r'/@([-\d.]+),([-\d.]+)').firstMatch(text);
    if (m != null) {
      final lat = double.tryParse(m.group(1)!);
      final lon = double.tryParse(m.group(2)!);
      if (_valid(lat, lon)) return (lat!, lon!);
    }
    // !3d{lat}!4d{lon} in data= parameter
    m = RegExp(r'!3d([-\d.]+)!4d([-\d.]+)').firstMatch(text);
    if (m != null) {
      final lat = double.tryParse(m.group(1)!);
      final lon = double.tryParse(m.group(2)!);
      if (_valid(lat, lon)) return (lat!, lon!);
    }
    // JSON lat/lon
    m = RegExp(r'"latitude"\s*:\s*([-\d.]+).*?"longitude"\s*:\s*([-\d.]+)',
        dotAll: true).firstMatch(text);
    if (m != null) {
      final lat = double.tryParse(m.group(1)!);
      final lon = double.tryParse(m.group(2)!);
      if (_valid(lat, lon)) return (lat!, lon!);
    }
    return null;
  }

  static String? _nameFromPlaceUrl(String url) {
    final m = RegExp(r'/maps/place/([^/@?+,]+)').firstMatch(url);
    if (m == null) return null;
    return Uri.decodeComponent(m.group(1)!.replaceAll('+', ' ')).trim();
  }

  static bool _valid(double? lat, double? lon) =>
      lat != null && lon != null && lat.abs() <= 90 && lon.abs() <= 180;

  static String _decodeXml(String s) {
    String out = s
        .replaceAll('&amp;',  '&')
        .replaceAll('&lt;',   '<')
        .replaceAll('&gt;',   '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;',  "'")
        .replaceAll('&apos;', "'");
    final cdataM = RegExp(r'<!\[CDATA\[(.*?)\]\]>', dotAll: true).firstMatch(out);
    if (cdataM != null) out = cdataM.group(1)!;
    return out.trim();
  }
}
