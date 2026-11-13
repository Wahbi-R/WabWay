import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/spot_data.dart';
import 'place_search_service.dart';
import 'supabase/client.dart';

const _kServerUrl = String.fromEnvironment('AUDIO_SERVER_URL', defaultValue: '');

/// Shortcut chips on the Nearby screen. [kind] is a server-side Google type
/// group (searchNearby, ranked by popularity); [query] is free text.
class NearbyShortcut {
  const NearbyShortcut(this.label, {this.kind, this.query});
  final String label;
  final String? kind;
  final String? query;
}

const kNearbyShortcuts = <NearbyShortcut>[
  NearbyShortcut('Food', kind: 'food'),
  NearbyShortcut('Ramen', query: 'ramen'),
  NearbyShortcut('Sushi', query: 'sushi'),
  NearbyShortcut('Coffee', kind: 'coffee'),
  NearbyShortcut('Dessert', kind: 'dessert'),
  NearbyShortcut('Bars', kind: 'bar'),
  NearbyShortcut('Konbini', kind: 'convenience'),
  NearbyShortcut('ATM', kind: 'atm'),
  NearbyShortcut('Pharmacy', kind: 'pharmacy'),
  NearbyShortcut('Toilets', kind: 'toilet'),
];

enum NearbyRank { relevance, distance }

class NearbyPlace {
  const NearbyPlace({
    required this.name,
    this.placeId,
    this.address = '',
    this.city = '',
    this.area = '',
    this.country = '',
    this.category = SpotCategory.landmark,
    this.typeLabel,
    this.latitude,
    this.longitude,
    this.distanceM,
    this.rating,
    this.ratingCount,
    this.priceLevel,
    this.priceRange,
    this.openNow,
    this.closesSoon,
    this.weekdayHours = const [],
    this.mapsUrl,
    this.website,
    this.phone,
    this.summary,
    this.photoName,
  });

  final String name;
  final String? placeId;
  final String address;
  final String city;
  final String area;
  final String country;
  final SpotCategory category;
  final String? typeLabel;
  final double? latitude;
  final double? longitude;
  final int? distanceM;
  final double? rating;
  final int? ratingCount;
  /// 0 free … 4 very expensive.
  final int? priceLevel;
  /// e.g. "¥1,000–¥2,000".
  final String? priceRange;
  final bool? openNow;
  final bool? closesSoon;
  /// Monday first, "Monday: 11:00 AM – 10:00 PM".
  final List<String> weekdayHours;
  final String? mapsUrl;
  final String? website;
  final String? phone;
  final String? summary;
  final String? photoName;

  factory NearbyPlace.fromJson(Map<String, dynamic> m) {
    String s(String k) => (m[k] as String?)?.trim() ?? '';
    String? n(String k) {
      final v = s(k);
      return v.isEmpty ? null : v;
    }
    return NearbyPlace(
      name: s('name'),
      placeId: n('place_id'),
      address: s('address'),
      city: s('city'),
      area: s('area'),
      country: s('country'),
      category: PlaceSearchService.categoryFromSlug(s('category')),
      typeLabel: n('type_label'),
      latitude: (m['latitude'] as num?)?.toDouble(),
      longitude: (m['longitude'] as num?)?.toDouble(),
      distanceM: (m['distance_m'] as num?)?.toInt(),
      rating: (m['rating'] as num?)?.toDouble(),
      ratingCount: (m['rating_count'] as num?)?.toInt(),
      priceLevel: (m['price_level'] as num?)?.toInt(),
      priceRange: n('price_range'),
      openNow: m['open_now'] as bool?,
      closesSoon: m['closes_soon'] as bool?,
      weekdayHours: [for (final h in (m['weekday_hours'] as List?) ?? const []) '$h'],
      mapsUrl: n('maps_url'),
      website: n('website'),
      phone: n('phone'),
      summary: n('summary'),
      photoName: n('photo_name'),
    );
  }

  /// Today's hours ("11:00 AM – 10:00 PM"), from the phone's own weekday.
  String? hoursOn(DateTime day) {
    if (weekdayHours.length != 7) return null;
    final line = weekdayHours[day.weekday - 1];
    final i = line.indexOf(':');
    return i < 0 ? line : line.substring(i + 1).trim();
  }

  /// "$$" style price, or the range Google gives.
  String? get priceLabel {
    if (priceRange != null) return priceRange;
    final p = priceLevel;
    if (p == null) return null;
    return p == 0 ? 'Free' : r'$' * p;
  }

  /// Google Maps link: the place's own page when Google gave one.
  String get mapsLink =>
      mapsUrl ??
      (latitude != null
          ? 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
          : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}');

  /// Same shape as a Place search pick, so Add spot fills itself in.
  PlaceSuggestion toSuggestion() => PlaceSuggestion(
        name: name,
        address: address,
        city: city,
        area: area,
        country: country,
        category: category,
        latitude: latitude ?? 0,
        longitude: longitude ?? 0,
        mapsUrl: mapsLink,
        placeId: placeId,
      );
}

/// "350 m", "1.2 km".
String fmtDistance(int metres) {
  if (metres < 1000) return '${(metres / 10).round() * 10} m';
  final km = metres / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
}

/// "1.2k" style review counts.
String fmtCount(int n) {
  if (n < 1000) return '$n';
  if (n < 10000) {
    final k = (n / 100).round() / 10;
    return '${k == k.roundToDouble() ? k.toInt() : k}k';
  }
  return '${(n / 1000).round()}k';
}

/// About 80 m a minute.
String fmtWalk(int metres) {
  final min = (metres / 80).ceil().clamp(1, 999);
  return '$min min walk';
}

abstract final class NearbyService {
  static bool get available => _kServerUrl.isNotEmpty;

  /// Results around ([lat], [lng]). Throws [NearbyException] with a
  /// user-facing message.
  static Future<List<NearbyPlace>> search({
    required double lat,
    required double lng,
    String? query,
    String? kind,
    double radius = 1500,
    bool openNow = false,
    double? minRating,
    NearbyRank rank = NearbyRank.relevance,
  }) async {
    if (!available) throw const NearbyException("Nearby search isn't set up on this build.");
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null) throw const NearbyException('Sign in to search nearby.');
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_kServerUrl/places/nearby'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({
              'latitude': lat,
              'longitude': lng,
              if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
              if (kind != null) 'kind': kind,
              'radius': radius,
              'open_now': openNow,
              if (minRating != null) 'min_rating': minRating,
              'rank': rank.name,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const NearbyException("Couldn't reach the server — check your connection.");
    }
    if (res.statusCode != 200) {
      String detail = '';
      try {
        detail = ((jsonDecode(res.body) as Map)['detail'] as String?) ?? '';
      } catch (_) {}
      throw NearbyException(detail.isNotEmpty ? detail : 'Search failed — try again.');
    }
    final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    return [
      for (final r in list) NearbyPlace.fromJson(r as Map<String, dynamic>),
    ].where((p) => p.name.isNotEmpty).toList();
  }

  /// Photo URL for a result (the server redirects to Google's CDN).
  static String? photoUrl(NearbyPlace p, {int width = 400}) => p.photoName == null || !available
      ? null
      : '$_kServerUrl/places/nearby/photo?w=$width&name=${Uri.encodeQueryComponent(p.photoName!)}';

  /// Headers for loading [photoUrl] (photos cost money, so they need sign-in).
  static Map<String, String> get photoHeaders {
    final token = supabase.auth.currentSession?.accessToken;
    return token == null ? const {} : {'Authorization': 'Bearer $token'};
  }
}

class NearbyException implements Exception {
  const NearbyException(this.message);
  final String message;
  @override
  String toString() => message;
}
