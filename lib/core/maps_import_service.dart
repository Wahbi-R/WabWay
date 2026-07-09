import 'dart:convert';
import 'package:http/http.dart' as http;

const _kAudioServerUrl = String.fromEnvironment(
  'AUDIO_SERVER_URL',
  defaultValue: '',
);

/// Result of resolving a Google Maps URL.
class MapsPlaceInfo {
  const MapsPlaceInfo({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.fullUrl,
    this.address,
    this.city,
    this.country,
    this.category,
    this.website,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String fullUrl;
  final String? address;
  final String? city;
  final String? country;
  /// WabWay SpotCategory slug returned by the server ('food', 'landmark', etc.)
  final String? category;
  final String? website;
}

abstract final class MapsImportService {
  static const _kTimeout = Duration(seconds: 8);

  /// Resolves any Google Maps URL (including short `maps.app.goo.gl` links)
  /// and returns enriched place info.
  ///
  /// Pipeline:
  ///   1. Follow redirects to get the full Maps URL
  ///   2. Extract place name from URL path + coordinates from @lat,lng
  ///   3. Call wabway-server /maps/enrich (Google Places API) — best data
  ///   4. Fall back to Nominatim reverse geocode if server unavailable
  static Future<MapsPlaceInfo?> resolve(String url) async {
    try {
      final resolved = await _resolveRedirects(url.trim());
      if (resolved == null) return null;

      final coords = _extractCoords(resolved);
      if (coords == null) return null;

      final nameFromUrl = _extractPlaceName(resolved);

      // Try server (Google Places API) first
      if (_kAudioServerUrl.isNotEmpty && nameFromUrl != null) {
        final serverResult = await _enrichViaServer(
          name: nameFromUrl,
          lat: coords.$1,
          lng: coords.$2,
        );
        if (serverResult != null) return serverResult.copyWithUrl(resolved);
      }

      // Fallback: Nominatim reverse geocode
      final geo = await _reverseGeocode(coords.$1, coords.$2);
      return MapsPlaceInfo(
        name:     nameFromUrl ?? geo?.displayName?.split(',').first.trim() ?? 'Unknown place',
        latitude:  coords.$1,
        longitude: coords.$2,
        fullUrl:   resolved,
        address:   geo?.address,
        city:      geo?.city,
        country:   geo?.country,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Server enrichment (Google Places API) ────────────────────────────────

  static Future<MapsPlaceInfo?> _enrichViaServer({
    required String name,
    required double lat,
    required double lng,
  }) async {
    try {
      final uri = Uri.parse('$_kAudioServerUrl/maps/enrich');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'latitude': lat, 'longitude': lng}),
      ).timeout(_kTimeout);

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      return MapsPlaceInfo(
        name:      (data['name'] as String?)?.trim() ?? name,
        latitude:  (data['latitude'] as num?)?.toDouble() ?? lat,
        longitude: (data['longitude'] as num?)?.toDouble() ?? lng,
        fullUrl:   '',
        address:   data['address'] as String?,
        city:      data['city'] as String?,
        country:   data['country'] as String?,
        category:  data['category'] as String?,
        website:   data['website'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Redirect resolution ──────────────────────────────────────────────────

  static Future<String?> _resolveRedirects(String url) async {
    var current = url;
    for (var i = 0; i < 5; i++) {
      final uri = Uri.tryParse(current);
      if (uri == null) return null;
      if (_isFullMapsUrl(current)) return current;
      final response = await http.head(uri).timeout(_kTimeout);
      final location = response.headers['location'];
      if (location == null) return current;
      current = Uri.parse(current).resolve(location).toString();
    }
    return current;
  }

  static bool _isFullMapsUrl(String url) =>
      url.contains('google.com/maps') &&
      (url.contains('/place/') || url.contains('@'));

  // ─── Place name extraction ────────────────────────────────────────────────

  static String? _extractPlaceName(String url) {
    final match = RegExp(r'/maps/place/([^/@?]+)').firstMatch(url);
    if (match == null) return null;
    return Uri.decodeComponent(match.group(1)!.replaceAll('+', ' ')).trim();
  }

  // ─── Coordinate extraction ────────────────────────────────────────────────

  static (double, double)? _extractCoords(String url) {
    final match = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(url);
    if (match == null) return null;
    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    return (lat, lng);
  }

  // ─── Nominatim reverse geocode ────────────────────────────────────────────

  static Future<_GeoResult?> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'WabwayApp/1.0 (travel planner)',
      }).timeout(_kTimeout);

      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final displayName = json['display_name'] as String?;
      final addr = json['address'] as Map<String, dynamic>? ?? {};

      final city = (_str(addr['city']) ??
              _str(addr['town']) ??
              _str(addr['village']) ??
              _str(addr['municipality']) ??
              _str(addr['county']))
          ?.trim();

      final parts = <String>[];
      final house = _str(addr['house_number']);
      final road  = _str(addr['road']) ?? _str(addr['pedestrian']);
      final post  = _str(addr['postcode']);
      if (house != null) parts.add(house);
      if (road  != null) parts.add(road);
      if (post  != null) parts.add(post);

      return _GeoResult(
        displayName: displayName,
        address:     parts.isNotEmpty ? parts.join(' ') : null,
        city:        city,
        country:     _str(addr['country'])?.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  static String? _str(dynamic v) {
    final s = v as String?;
    return (s == null || s.isEmpty) ? null : s;
  }
}

class _GeoResult {
  const _GeoResult({this.displayName, this.address, this.city, this.country});
  final String? displayName;
  final String? address;
  final String? city;
  final String? country;
}

extension _MapsPlaceInfoX on MapsPlaceInfo {
  MapsPlaceInfo copyWithUrl(String url) => MapsPlaceInfo(
        name:      name,
        latitude:  latitude,
        longitude: longitude,
        fullUrl:   url,
        address:   address,
        city:      city,
        country:   country,
        category:  category,
        website:   website,
      );
}
