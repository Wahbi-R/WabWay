import 'dart:convert';
import 'dart:typed_data';
import 'google_maps_parser.dart';
import 'nominatim_service.dart';
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

  /// Fast synchronous CSV parse — extracts names, notes, and URLs immediately
  /// with no network calls. All places have lat=lon=0 until geocoded.
  /// Deduplicates by URL. Returns empty list if not a valid Takeout CSV.
  static List<MapsPlace> parseCsvFast(Uint8List bytes) {
    try {
      final text    = utf8.decode(bytes);
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
        final title = titleIdx < cols.length ? cols[titleIdx].trim() : '';
        if (title.isEmpty) continue;

        final url  = urlIdx >= 0 && urlIdx < cols.length
            ? cols[urlIdx].trim() : '';
        final note = noteIdx >= 0 && noteIdx < cols.length
            ? cols[noteIdx].trim() : '';

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

    // Try Nominatim directly with the place name — faster than going through
    // GoogleMapsParser which also fetches the (JS-rendered) Maps page.
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

    // Fallback: extract name from URL path and retry (handles URL-encoded names
    // that differ from the display title)
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
