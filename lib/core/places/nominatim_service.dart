import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/spot_data.dart';

class NominatimPlace {
  const NominatimPlace({
    required this.name,
    required this.city,
    required this.country,
    required this.lat,
    required this.lon,
    required this.category,
    this.displayName = '',
  });

  final String       name;
  final String       city;
  final String       country;
  final double       lat;
  final double       lon;
  final SpotCategory category;
  final String       displayName;
}

abstract final class NominatimService {
  static const _ua      = 'WabWay/1.1 (wahbi@portalprints.com)';
  static const _baseUrl = 'https://nominatim.openstreetmap.org/search';

  /// Searches for a place by name. Returns up to 3 candidates.
  /// Call with a 1-second delay between queries per Nominatim ToS.
  static Future<List<NominatimPlace>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'q':              query.trim(),
        'format':         'json',
        'limit':          '3',
        'addressdetails': '1',
      });
      final res = await http
          .get(uri, headers: {'User-Agent': _ua, 'Accept-Language': 'en'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      return list.map(_fromJson).whereType<NominatimPlace>().toList();
    } catch (_) {
      return [];
    }
  }

  static NominatimPlace? _fromJson(Map<String, dynamic> j) {
    try {
      final addr    = (j['address'] as Map<String, dynamic>?) ?? {};
      final lat     = double.tryParse(j['lat'] as String? ?? '');
      final lon     = double.tryParse(j['lon'] as String? ?? '');
      if (lat == null || lon == null) return null;

      final name = _bestName(j, addr);
      if (name.isEmpty) return null;

      final city = addr['city']         as String? ??
                   addr['town']         as String? ??
                   addr['village']      as String? ??
                   addr['municipality'] as String? ?? '';
      final country = addr['country'] as String? ?? '';

      return NominatimPlace(
        name:        name,
        city:        city,
        country:     country,
        lat:         lat,
        lon:         lon,
        category:    _category(j),
        displayName: j['display_name'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static String _bestName(
      Map<String, dynamic> j, Map<String, dynamic> addr) {
    // Prefer the most specific named field in address
    for (final key in [
      'tourism', 'amenity', 'leisure', 'historic', 'shop', 'natural',
    ]) {
      final v = addr[key] as String?;
      if (v != null && v.isNotEmpty) return v;
    }
    // Fall back to the top-level name
    return (j['name'] as String? ?? '').trim();
  }

  static SpotCategory _category(Map<String, dynamic> j) {
    final cls  = j['class']  as String? ?? '';
    final type = j['type']   as String? ?? '';
    final addr = (j['address'] as Map<String, dynamic>?) ?? {};

    // Food
    if (cls == 'amenity' &&
        const {'restaurant', 'cafe', 'bar', 'pub', 'fast_food',
                'food_court', 'biergarten', 'ice_cream'}.contains(type)) {
      return SpotCategory.food;
    }
    // Nightlife
    if (cls == 'amenity' &&
        const {'nightclub', 'casino', 'stripclub'}.contains(type)) {
      return SpotCategory.nightlife;
    }
    // Shopping
    if (cls == 'shop' ||
        (cls == 'amenity' && const {'marketplace', 'mall'}.contains(type))) {
      return SpotCategory.shopping;
    }
    // Nature
    if (cls == 'natural' ||
        cls == 'waterway' ||
        (cls == 'leisure' &&
            const {'park', 'garden', 'nature_reserve', 'beach_resort'}
                .contains(type))) {
      return SpotCategory.nature;
    }
    // Experience (museums, attractions, etc.)
    if (cls == 'tourism' &&
        const {'museum', 'gallery', 'theme_park', 'zoo', 'aquarium',
                'artwork'}.contains(type)) {
      return SpotCategory.experience;
    }
    // Default: landmark
    return SpotCategory.landmark;
  }
}
