import 'dart:convert';
import 'dart:typed_data';
import 'google_maps_parser.dart';
import 'nominatim_service.dart';
import '../place_search_service.dart';
import '../../data/spot_data.dart';

/// Parses Google Takeout exports for Google Maps / Saved data.
///
/// Two export formats are supported:
///
/// 1. **GeoJSON** — `Takeout/Maps (your places)/Saved Places.json`
///    Your default starred/saved places.
///
/// 2. **CSV** — `Takeout/Saved/{List Name}.csv`
///    Custom-named lists you created in Google Maps.
///    Columns: Title, Note, URL, Tags, Comment
///    Coordinates are not included — geocoded via Nominatim.
abstract final class TakeoutParser {
  /// Synchronously parse a GeoJSON Saved Places file.
  /// Returns null if the bytes are not a recognisable Takeout GeoJSON file.
  static List<MapsPlace>? parseJson(Uint8List bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (json['type'] != 'FeatureCollection') return null;
      final features = json['features'] as List? ?? [];
      if (features.isEmpty) return null;

      final places = <MapsPlace>[];
      for (final f in features.cast<Map<String, dynamic>>()) {
        final place = _featureToPlace(f);
        if (place != null) places.add(place);
      }
      return places.isEmpty ? null : places;
    } catch (_) {
      return null;
    }
  }

  // ── Windows-1252 codepoint → byte map for the 0x80–0x9F range ───────────────
  // (Latin-1 uses control chars there; W1252 maps them to printable glyphs.)
  static const _w1252 = <int, int>{
    0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84,
    0x2026: 0x85, 0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88,
    0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C,
    0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92, 0x201C: 0x93,
    0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97,
    0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B,
    0x0153: 0x9C, 0x017E: 0x9E, 0x0178: 0x9F,
  };

  /// Attempts to undo "mojibake" where UTF-8 bytes were decoded as Windows-1252
  /// and then re-encoded as UTF-8 (common with some Google Takeout exports).
  /// Returns the original string if it doesn't look like mojibake.
  static String _fixMojibake(String s) {
    try {
      final bytes = <int>[];
      for (final cp in s.runes) {
        if (cp <= 0xFF) {
          bytes.add(cp);
        } else {
          final b = _w1252[cp];
          if (b == null) return s; // codepoint outside W1252 → not mojibake
          bytes.add(b);
        }
      }
      final fixed = utf8.decode(bytes);
      // Only accept the fix when the result has non-Latin-1 characters
      // (i.e. the original bytes encoded a non-Western script like Japanese).
      return fixed.runes.any((c) => c > 0x00FF) ? fixed : s;
    } catch (_) {
      return s;
    }
  }

  /// Fast synchronous CSV parse — extracts names, notes, and URLs immediately
  /// with no network calls. All places have lat=lon=0 until geocoded.
  /// Deduplicates by URL. Returns empty list if not a valid Takeout CSV.
  static List<MapsPlace> parseCsvFast(Uint8List bytes) {
    try {
      final text    = utf8.decode(bytes, allowMalformed: true);
      final lines   = text.split('\n');
      if (lines.isEmpty) return [];

      final headers  = _splitCsvRow(lines.first);
      final titleIdx = headers.indexWhere((h) => h.trim().toLowerCase() == 'title');
      final noteIdx  = headers.indexWhere((h) => h.trim().toLowerCase() == 'note');
      final urlIdx   = headers.indexWhere((h) => h.trim().toLowerCase() == 'url');
      if (titleIdx < 0) return [];

      final places   = <MapsPlace>[];
      final seenUrls = <String>{};

      for (final raw in lines.skip(1)) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        final cols  = _splitCsvRow(line);
        final rawTitle = titleIdx < cols.length ? cols[titleIdx].trim() : '';
        if (rawTitle.isEmpty) continue;
        final title = _fixMojibake(rawTitle);

        final url  = urlIdx >= 0 && urlIdx < cols.length
            ? cols[urlIdx].trim() : '';
        final rawNote = noteIdx >= 0 && noteIdx < cols.length
            ? cols[noteIdx].trim() : '';
        final note = _fixMojibake(rawNote);

        // Deduplicate by Maps URL
        if (url.isNotEmpty) {
          if (seenUrls.contains(url)) continue;
          seenUrls.add(url);
        }

        places.add(MapsPlace(
          name:     title,
          lat:      0,
          lon:      0,
          mapsUrl:  url.isNotEmpty ? url : null,
          notes:    note.isNotEmpty ? note : null,
          category: SpotCategory.landmark,
        ));
      }
      return places;
    } catch (_) {
      return [];
    }
  }

  /// Geocode a single place that came from [parseCsvFast] (lat=lon=0).
  /// Returns an updated [MapsPlace] with coords, or the original if nothing
  /// was found. Callers should update their list and setState after each call.
  static Future<MapsPlace> geocodePlace(MapsPlace place) async {
    if (place.hasCoords) return place; // already resolved

    // Step 0: try Google Places (via wabway-server) — best for named businesses.
    final gpResults = await PlaceSearchService.search(place.name, limit: 1);
    if (gpResults.isNotEmpty) {
      final r = gpResults.first;
      if (r.latitude != 0 || r.longitude != 0) {
        return place.copyWith(
          lat:      r.latitude,
          lon:      r.longitude,
          city:     r.city.isNotEmpty ? r.city : null,
          category: r.category,
        );
      }
    }

    // Step 1: Nominatim directly with the place name.
    final hits = await NominatimService.search(place.name);
    if (hits.isNotEmpty) {
      final h = hits.first;
      return place.copyWith(
        lat:      h.lat,
        lon:      h.lon,
        city:     h.city,
        category: h.category,
      );
    }

    // Fallback 2: extract name from URL path and retry with Nominatim
    // (handles URL-encoded names that differ from the display title)
    if (place.mapsUrl != null && place.mapsUrl!.contains('/maps/place/')) {
      final m = RegExp(r'/maps/place/([^/?]+)').firstMatch(place.mapsUrl!);
      if (m != null) {
        final slug = Uri.decodeComponent(
            m.group(1)!.replaceAll('+', ' ')).trim();
        if (slug.isNotEmpty && slug != place.name) {
          final hits2 = await NominatimService.search(slug);
          if (hits2.isNotEmpty) {
            final h = hits2.first;
            return place.copyWith(lat: h.lat, lon: h.lon, city: h.city,
                category: h.category);
          }
        }
      }

      // Fallback 3: fetch the actual Google Maps page and extract coordinates
      // from the redirect URL or HTML. Works for many places Nominatim doesn't
      // know (local shops, restaurants, etc.) since Google's server often
      // redirects to a URL containing @lat,lon.
      final coords = await GoogleMapsParser.fetchCoordsFromUrl(place.mapsUrl!);
      if (coords != null) {
        final city = await NominatimService.reverseGeocodeCity(coords.$1, coords.$2);
        return place.copyWith(
          lat:  coords.$1,
          lon:  coords.$2,
          city: city.isNotEmpty ? city : null,
        );
      }
    }

    return place; // stays at 0,0 — flagged in UI
  }

  /// Legacy async parse that blocks until all geocoding is done.
  /// Prefer [parseCsvFast] + [geocodePlace] for large lists.
  static Future<List<MapsPlace>?> parseCsv(Uint8List bytes) async {
    final fast = parseCsvFast(bytes);
    if (fast.isEmpty) return null;
    final out = <MapsPlace>[];
    for (final p in fast) {
      out.add(await geocodePlace(p));
    }
    return out;
  }

  /// Legacy alias kept for callers that passed .json bytes.
  static List<MapsPlace>? parse(Uint8List bytes) => parseJson(bytes);

  // ── CSV helpers ─────────────────────────────────────────────────────────────

  static List<String> _splitCsvRow(String row) {
    final cols = <String>[];
    final buf  = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < row.length; i++) {
      final c = row[i];
      if (c == '"') {
        if (inQuotes && i + 1 < row.length && row[i + 1] == '"') {
          buf.write('"'); // escaped quote
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        cols.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    cols.add(buf.toString());
    return cols;
  }

  // ── GeoJSON feature parser ──────────────────────────────────────────────────

  static MapsPlace? _featureToPlace(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>? ?? {};
    final geo   = feature['geometry']  as Map<String, dynamic>? ?? {};

    // ── Coordinates ──────────────────────────────────────────────────────────
    double? lat, lon;

    final coords = geo['coordinates'];
    if (coords is List && coords.length >= 2) {
      lon = (coords[0] as num?)?.toDouble();
      lat = (coords[1] as num?)?.toDouble();
    }

    if ((lat == null || lon == null) || (lat == 0 && lon == 0)) {
      final loc       = props['Location'] as Map<String, dynamic>? ?? {};
      final geoCoords = loc['Geo Coordinates'] as Map<String, dynamic>? ?? {};
      final fLat = double.tryParse(geoCoords['Latitude']?.toString()  ?? '');
      final fLon = double.tryParse(geoCoords['Longitude']?.toString() ?? '');
      if (fLat != null && fLon != null) { lat = fLat; lon = fLon; }
    }

    if (lat == null || lon == null) return null;
    if (lat == 0 && lon == 0) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;

    // ── Name ─────────────────────────────────────────────────────────────────
    final loc   = props['Location'] as Map<String, dynamic>? ?? {};
    String name = (props['Title']  as String? ??
                   props['title']  as String? ?? '').trim();
    if (name.isEmpty) name = (loc['Business Name'] as String? ?? '').trim();
    if (name.isEmpty) {
      final mapsUrl = props['google_maps_url'] as String? ??
                      props['Google Maps URL'] as String?;
      if (mapsUrl != null) {
        final q = Uri.tryParse(mapsUrl)?.queryParameters['q'];
        if (q != null && q.isNotEmpty) name = q.split(',').first.trim();
      }
    }
    if (name.isEmpty) return null;

    final address = (loc['Address'] as String? ?? '').trim();

    String city = '';
    if (address.isNotEmpty) {
      final parts = address.split(', ');
      if (parts.length >= 2) city = parts[parts.length - 2].trim();
    }

    final mapsUrl = props['Google Maps URL'] as String? ??
                    props['google_maps_url'] as String?;

    return MapsPlace(
      name:     name,
      lat:      lat,
      lon:      lon,
      address:  address.isEmpty ? null : address,
      mapsUrl:  mapsUrl,
      category: SpotCategory.landmark,
      city:     city,
    );
  }
}
