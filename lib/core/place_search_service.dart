import '../data/japan_places.dart';

abstract final class PlaceSearchService {
  static List<PlaceSuggestion> search(String query, {int limit = 8}) {
    if (query.trim().isEmpty) return [];
    final results = kJapanPlaces.where((p) => p.matches(query)).toList();
    return results.take(limit).toList();
  }

  // Parse @lat,lng out of a Google Maps URL.
  // Handles:
  //   https://www.google.com/maps/place/.../@35.7147,139.7966,...
  //   https://maps.app.goo.gl/...  (short link — can't parse coords client-side)
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
