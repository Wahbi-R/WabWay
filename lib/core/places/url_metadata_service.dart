import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _kServerUrl = String.fromEnvironment('AUDIO_SERVER_URL', defaultValue: '');

/// What a link says about itself — OpenGraph + schema.org (via wabway-server
/// `/url/meta`). Used by Import, Stays "Parse listing" and Shopping previews.
class UrlMetadata {
  const UrlMetadata({
    required this.url,
    this.title,
    this.description,
    this.image,
    this.siteName,
    this.schemaType,
    this.startDate,
    this.endDate,
    this.price,
    this.currency,
    this.confirmationNumber,
    this.locality,
    this.address,
  });

  final String url;
  final String? title;
  final String? description;
  final String? image;
  final String? siteName;

  /// schema.org @type of the best structured object, e.g. "LodgingReservation".
  final String? schemaType;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? price;
  final String? currency;
  final String? confirmationNumber;
  final String? locality;
  final String? address;

  bool get isLodging => const {
        'LodgingReservation', 'Hotel', 'LodgingBusiness', 'VacationRental',
        'Accommodation', 'Apartment',
      }.contains(schemaType);

  bool get isTransport => const {
        'FlightReservation', 'TrainReservation', 'BusReservation',
      }.contains(schemaType);

  factory UrlMetadata.fromJson(Map<String, dynamic> j) => UrlMetadata(
        url: j['url'] as String? ?? '',
        title: _s(j['title']),
        description: _s(j['description']),
        image: _s(j['image']),
        siteName: _s(j['site_name']),
        schemaType: _s(j['schema_type']),
        startDate: DateTime.tryParse(j['start_date'] as String? ?? ''),
        endDate: DateTime.tryParse(j['end_date'] as String? ?? ''),
        price: (j['price'] as num?)?.toDouble(),
        currency: _s(j['currency'])?.toUpperCase(),
        confirmationNumber: _s(j['confirmation_number']),
        locality: _s(j['locality']),
        address: _s(j['address']),
      );

  static String? _s(Object? v) {
    final t = (v as String?)?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}

abstract final class UrlMetadataService {
  static const _ua = 'Mozilla/5.0 (compatible; WabWay/1.1; +https://wabway.app)';

  /// Server first (works on web — no CORS); on native, falls back to fetching
  /// the page directly and reading OpenGraph tags. Null when nothing usable.
  static Future<UrlMetadata?> fetch(String url) async {
    if (_kServerUrl.isNotEmpty) {
      try {
        final res = await http
            .post(Uri.parse('$_kServerUrl/url/meta'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'url': url}))
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          return UrlMetadata.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
        }
      } catch (_) {}
    }
    if (kIsWeb) return null; // browsers block cross-origin page fetches
    try {
      final res = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final html = res.body;
      return UrlMetadata(
        url: url,
        title: ogTag(html, 'og:title') ?? _titleTag(html),
        description: ogTag(html, 'og:description'),
        image: ogTag(html, 'og:image'),
        siteName: ogTag(html, 'og:site_name'),
      );
    } catch (_) {
      return null;
    }
  }

  /// `<meta property="og:x" content="...">` in either attribute order.
  static String? ogTag(String html, String property) {
    final re = RegExp(
      '<meta[^>]+(?:property|name)=["\']$property["\'][^>]+content=["\']([^"\']*)["\']',
      caseSensitive: false,
    );
    final m = re.firstMatch(html) ??
        RegExp(
          '<meta[^>]+content=["\']([^"\']*)["\'][^>]+(?:property|name)=["\']$property["\']',
          caseSensitive: false,
        ).firstMatch(html);
    final v = m?.group(1);
    return (v != null && v.isNotEmpty) ? decodeEntities(v) : null;
  }

  static String? _titleTag(String html) {
    final m = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(html);
    final t = m?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
    return (t == null || t.isEmpty) ? null : decodeEntities(t);
  }

  static String decodeEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&nbsp;', ' ');
}
