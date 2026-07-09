import 'dart:convert';
import 'package:http/http.dart' as http;

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
    this.displayName,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String fullUrl;
  final String? address;
  final String? city;
  final String? country;
  final String? displayName;

  bool get hasGeo => true;
}

abstract final class MapsImportService {
  static const _kTimeout = Duration(seconds: 8);

  /// Resolves any Google Maps URL (including short `maps.app.goo.gl` links)
  /// and returns enriched place info: name, coordinates, address, city, country.
  ///
  /// Returns null if the URL cannot be resolved or is not a Maps link.
  static Future<MapsPlaceInfo?> resolve(String url) async {
    try {
      final resolved = await _resolveRedirects(url.trim());
      if (resolved == null) return null;

      final coords = _extractCoords(resolved);
      if (coords == null) return null;

      final name = _extractPlaceName(resolved);

      // Reverse-geocode with Nominatim for address/city/country
      final geo = await _reverseGeocode(coords.$1, coords.$2);

      return MapsPlaceInfo(
        name:        name ?? geo?.displayName?.split(',').first.trim() ?? 'Unknown place',
        latitude:    coords.$1,
        longitude:   coords.$2,
        fullUrl:     resolved,
        address:     geo?.address,
        city:        geo?.city,
        country:     geo?.country,
        displayName: geo?.displayName,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Redirect resolution ──────────────────────────────────────────────────

  /// Follows HTTP redirects (up to 5 hops) to get the final URL.
  /// `maps.app.goo.gl` links redirect to the full `google.com/maps/place/...` URL.
  static Future<String?> _resolveRedirects(String url) async {
    var current = url;
    for (var i = 0; i < 5; i++) {
      final uri = Uri.tryParse(current);
      if (uri == null) return null;

      // Already a full Maps URL — done
      if (_isFullMapsUrl(current)) return current;

      final response = await http.head(uri).timeout(_kTimeout);
      final location = response.headers['location'];
      if (location == null) return current;
      // Resolve relative redirects
      current = Uri.parse(current).resolve(location).toString();
    }
    return current;
  }

  static bool _isFullMapsUrl(String url) =>
      url.contains('google.com/maps') &&
      (url.contains('/place/') || url.contains('@'));

  // ─── Place name extraction ─────────────────────────────────────────────────

  /// Extracts the human-readable place name from a full Maps URL path.
  ///
  /// Full URL pattern: `.../maps/place/NAME_ENCODED/@lat,lng,...`
  static String? _extractPlaceName(String url) {
    // Match /maps/place/<name>/ or /maps/place/<name>@
    final match = RegExp(r'/maps/place/([^/@?]+)').firstMatch(url);
    if (match == null) return null;
    final encoded = match.group(1)!;
    return Uri.decodeComponent(encoded.replaceAll('+', ' ')).trim();
  }

  // ─── Coordinate extraction ────────────────────────────────────────────────

  /// Extracts (lat, lng) from `@lat,lng` in the URL.
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

      final country = _str(addr['country'])?.trim();

      // Build a short address from street + house_number + postcode
      final parts = <String>[];
      final house = _str(addr['house_number']);
      final road  = _str(addr['road']) ?? _str(addr['pedestrian']);
      final post  = _str(addr['postcode']);
      if (house != null) parts.add(house);
      if (road  != null) parts.add(road);
      if (post  != null) parts.add(post);

      final address = parts.isNotEmpty ? parts.join(' ') : null;

      return _GeoResult(
        displayName: displayName,
        address:     address,
        city:        city,
        country:     country,
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
  const _GeoResult({
    this.displayName,
    this.address,
    this.city,
    this.country,
  });
  final String? displayName;
  final String? address;
  final String? city;
  final String? country;
}
