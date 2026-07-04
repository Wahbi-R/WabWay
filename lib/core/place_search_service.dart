import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/japan_places.dart';
import '../data/spot_data.dart';

abstract final class PlaceSearchService {
  // ─── Local fallback ──────────────────────────────────────────────────────────

  static List<PlaceSuggestion> searchLocal(String query, {int limit = 8}) {
    if (query.trim().isEmpty) return [];
    return kJapanPlaces.where((p) => p.matches(query)).take(limit).toList();
  }

  // ─── Photon live search ───────────────────────────────────────────────────────

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

      final lng  = coords[0].toDouble();
      final lat  = coords[1].toDouble();
      final city = (props['city'] ?? props['county'] ?? props['state'] ?? '') as String;
      final area = (props['district'] ?? props['suburb'] ?? props['neighbourhood'] ?? '') as String;
      final street = [
        props['housenumber'],
        props['street'],
      ].whereType<String>().join(' ').trim();

      final category = _categoryFromProps(props);
      final mapsUrl  = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

      return PlaceSuggestion(
        name:      name,
        address:   street,
        city:      city,
        area:      area,
        category:  category,
        latitude:  lat,
        longitude: lng,
        mapsUrl:   mapsUrl,
      );
    } catch (_) {
      return null;
    }
  }

  static SpotCategory _categoryFromProps(Map<String, dynamic> props) {
    final type = ((props['type'] as String?) ?? '').toLowerCase();
    final osm  = ((props['osm_value'] as String?) ?? '').toLowerCase();
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
        combined.contains('bar') ||
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

  // ─── Maps URL helpers ─────────────────────────────────────────────────────────

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
