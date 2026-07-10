import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/spot_data.dart';

const _kServerUrl = String.fromEnvironment('AUDIO_SERVER_URL', defaultValue: '');

abstract final class PlaceSearchService {
  static const _kTimeout = Duration(seconds: 8);

  /// Search for places by text query. Calls the wabway-server Google Places
  /// endpoint when available, falls back to Photon (OSM) otherwise.
  static Future<List<PlaceSuggestion>> search(
    String query, {
    double? latitude,
    double? longitude,
    int limit = 6,
  }) async {
    if (query.trim().isEmpty) return [];
    if (_kServerUrl.isNotEmpty) {
      final results = await _searchViaServer(
        query, lat: latitude, lng: longitude, limit: limit,
      );
      if (results != null) return results;
    }
    return searchPhoton(query, limit: limit);
  }

  static Future<List<PlaceSuggestion>?> _searchViaServer(
    String query, {
    double? lat,
    double? lng,
    int limit = 6,
  }) async {
    try {
      final body = <String, dynamic>{'query': query.trim(), 'limit': limit};
      if (lat != null && lng != null) {
        body['latitude']  = lat;
        body['longitude'] = lng;
      }
      final response = await http.post(
        Uri.parse('$_kServerUrl/places/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(_kTimeout);
      if (response.statusCode != 200) return null;
      final list = jsonDecode(response.body) as List<dynamic>;
      if (list.isEmpty) return null; // fall through to Photon
      return list.map((r) {
        final m = r as Map<String, dynamic>;
        final lat  = (m['latitude']  as num?)?.toDouble() ?? 0.0;
        final lng  = (m['longitude'] as num?)?.toDouble() ?? 0.0;
        final city = (m['city'] as String?)?.trim() ?? '';
        return PlaceSuggestion(
          name:      (m['name']    as String?)?.trim() ?? '',
          address:   (m['address'] as String?)?.trim() ?? '',
          city:      city,
          area:      '',
          country:   (m['country'] as String?)?.trim() ?? '',
          category:  _categoryFromSlug(m['category'] as String? ?? ''),
          latitude:  lat,
          longitude: lng,
          mapsUrl:   lat != 0 ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng' : '',
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  static SpotCategory _categoryFromSlug(String slug) => switch (slug) {
    'food'       => SpotCategory.food,
    'shopping'   => SpotCategory.shopping,
    'nature'     => SpotCategory.nature,
    'nightlife'  => SpotCategory.nightlife,
    'experience' => SpotCategory.experience,
    _            => SpotCategory.landmark,
  };

  static Future<List<PlaceSuggestion>> searchPhoton(
    String query, {
    int limit = 6,
    String lang = 'en',
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=$limit&lang=$lang',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final features = (json['features'] as List? ?? []);
      return features
          .map((f) => _featureToSuggestion(f as Map<String, dynamic>))
          .whereType<PlaceSuggestion>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static PlaceSuggestion? _featureToSuggestion(Map<String, dynamic> feature) {
    try {
      final props = feature['properties'] as Map<String, dynamic>? ?? {};
      final geo   = feature['geometry']  as Map<String, dynamic>? ?? {};
      final coords = (geo['coordinates'] as List?)?.cast<num>() ?? [];
      if (coords.length < 2) return null;

      final name = (props['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return null;

      final lng = coords[0].toDouble();
      final lat = coords[1].toDouble();

      final city = _str(props['city'] ?? props['county'] ?? props['state']);
      final area = _str(props['district'] ?? props['suburb'] ?? props['neighbourhood']);

      // Build address from whatever Photon provides — Japanese addresses
      // rarely have housenumber+street in OSM, so fall back through levels.
      final addrParts = <String>[];
      final housenumber = _str(props['housenumber']);
      final street      = _str(props['street']);
      final postcode    = _str(props['postcode']);

      if (housenumber.isNotEmpty) addrParts.add(housenumber);
      if (street.isNotEmpty)      addrParts.add(street);
      // If no street data, use neighbourhood/suburb as the address hint
      if (addrParts.isEmpty && area.isNotEmpty) addrParts.add(area);
      if (postcode.isNotEmpty) addrParts.add(postcode);

      final address = addrParts.join(' ');
      final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

      final country = _str(props['country']);

      return PlaceSuggestion(
        name:      name,
        address:   address,
        city:      city,
        area:      area,
        category:  _categoryFromProps(props),
        latitude:  lat,
        longitude: lng,
        mapsUrl:   mapsUrl,
        country:   country,
      );
    } catch (_) {
      return null;
    }
  }

  static String _str(dynamic v) => (v as String?)?.trim() ?? '';

  static SpotCategory _categoryFromProps(Map<String, dynamic> props) {
    final type = _str(props['type']).toLowerCase();
    final osm  = _str(props['osm_value']).toLowerCase();
    final combined = '$type $osm';
    if (combined.contains('restaurant') ||
        combined.contains('cafe') ||
        combined.contains('food') ||
        combined.contains('bar') ||
        combined.contains('bakery') ||
        combined.contains('fast_food')) return SpotCategory.food;
    if (combined.contains('shop') ||
        combined.contains('mall') ||
        combined.contains('market') ||
        combined.contains('department')) return SpotCategory.shopping;
    if (combined.contains('park') ||
        combined.contains('garden') ||
        combined.contains('forest') ||
        combined.contains('nature') ||
        combined.contains('mountain') ||
        combined.contains('beach')) return SpotCategory.nature;
    if (combined.contains('nightclub') ||
        combined.contains('pub') ||
        combined.contains('club')) return SpotCategory.nightlife;
    if (combined.contains('attraction') ||
        combined.contains('museum') ||
        combined.contains('gallery') ||
        combined.contains('theatre') ||
        combined.contains('cinema') ||
        combined.contains('theme_park') ||
        combined.contains('aquarium') ||
        combined.contains('zoo')) return SpotCategory.experience;
    return SpotCategory.landmark;
  }

  // ─── Maps URL helpers ──────────────────────────────────────────────────────

  static ({double lat, double lng})? parseLatLng(String url) {
    final match = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(url);
    if (match == null) return null;
    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }

  static bool isMapsUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('google.com/maps') ||
        lower.contains('maps.app.goo.gl') ||
        lower.contains('goo.gl/maps');
  }
}
