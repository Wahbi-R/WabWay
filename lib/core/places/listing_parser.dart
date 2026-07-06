import 'package:http/http.dart' as http;
import '../../data/accommodation_data.dart';

class ListingResult {
  const ListingResult({
    required this.name,
    this.city,
    this.address,
    this.pricePerNight,
    this.currency,
    this.imageUrl,
    required this.source,
  });

  final String name;
  final String? city;
  final String? address;
  final double? pricePerNight;
  final String? currency;
  final String? imageUrl;
  final AccommodationSource source;
}

abstract final class ListingParser {
  static const _ua = 'Mozilla/5.0 (compatible; WabWay/1.1; +https://wabway.app)';

  static Future<ListingResult?> parse(String url) async {
    try {
      final source = AccommodationSource.fromUrl(url);
      final res = await http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final html = res.body;

      final rawTitle = _ogTag(html, 'og:title') ?? '';
      final rawDesc  = _ogTag(html, 'og:description') ?? '';
      final imageUrl = _ogTag(html, 'og:image');

      final name = _cleanTitle(rawTitle, source);
      if (name.isEmpty) return null;

      final priceResult = _extractPrice(rawDesc);
      final city        = _extractCity(rawTitle, rawDesc, source);

      return ListingResult(
        name:          name,
        city:          city,
        pricePerNight: priceResult?.$1,
        currency:      priceResult?.$2,
        imageUrl:      imageUrl,
        source:        source,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _ogTag(String html, String property) {
    final re = RegExp(
      '<meta[^>]+property=["\']$property["\'][^>]+content=["\']([^"\']*)["\']',
      caseSensitive: false,
    );
    final m = re.firstMatch(html) ??
        RegExp(
          '<meta[^>]+content=["\']([^"\']*)["\'][^>]+property=["\']$property["\']',
          caseSensitive: false,
        ).firstMatch(html);
    return m?.group(1)?.isNotEmpty == true ? _decodeEntities(m!.group(1)!) : null;
  }

  static String _cleanTitle(String raw, AccommodationSource source) {
    var t = raw.trim();
    final suffixes = [
      ' - Airbnb', ' | Airbnb',
      ' - Booking.com', ' | Booking.com',
      ' - Expedia', ' | Expedia',
      ' - Hotels.com', ' | Hotels.com',
      ' - VRBO', ' | VRBO',
      ' - Avion', ' | Avion',
    ];
    for (final suffix in suffixes) {
      if (t.toLowerCase().endsWith(suffix.toLowerCase())) {
        t = t.substring(0, t.length - suffix.length).trim();
        break;
      }
    }
    return t;
  }

  static (double, String)? _extractPrice(String text) {
    final patterns = [
      (RegExp(r'\$\s*([\d,]+)\s*(?:per\s*)?night', caseSensitive: false), 'USD'),
      (RegExp(r'€\s*([\d,]+)\s*(?:per\s*)?night', caseSensitive: false), 'EUR'),
      (RegExp(r'£\s*([\d,]+)\s*(?:per\s*)?night', caseSensitive: false), 'GBP'),
      (RegExp(r'¥\s*([\d,]+)\s*(?:per\s*)?night', caseSensitive: false), 'JPY'),
      (RegExp(r'([\d,]+)\s*USD\s*(?:per\s*)?night', caseSensitive: false), 'USD'),
      (RegExp(r'([\d,]+)\s*EUR\s*(?:per\s*)?night', caseSensitive: false), 'EUR'),
      (RegExp(r'([\d,]+)\s*GBP\s*(?:per\s*)?night', caseSensitive: false), 'GBP'),
      (RegExp(r'([\d,]+)\s*JPY\s*(?:per\s*)?night', caseSensitive: false), 'JPY'),
      (RegExp(r'([\d,]+)\s*CAD\s*(?:per\s*)?night', caseSensitive: false), 'CAD'),
      (RegExp(r'([\d,]+)\s*AUD\s*(?:per\s*)?night', caseSensitive: false), 'AUD'),
    ];
    for (final (re, currency) in patterns) {
      final m = re.firstMatch(text);
      if (m != null) {
        final raw = m.group(1)!.replaceAll(',', '');
        final val = double.tryParse(raw);
        if (val != null && val > 0) return (val, currency);
      }
    }
    return null;
  }

  static String? _extractCity(String title, String desc, AccommodationSource source) {
    if (source == AccommodationSource.airbnb) {
      final inMatch = RegExp(r'\bin\s+([A-Z][^,\n]+(?:,\s*[A-Z][^,\n]+)?)')
          .firstMatch(title);
      if (inMatch != null) return inMatch.group(1)?.trim();
    }
    final inDesc = RegExp(r'(?:in|near)\s+([A-Z][a-zA-Z\s]+(?:,\s*[A-Z][a-zA-Z]+)?)(?:[.,]|$)')
        .firstMatch(desc);
    if (inDesc != null) return inDesc.group(1)?.trim();
    return null;
  }

  static String _decodeEntities(String s) => s
      .replaceAll('&amp;',  '&')
      .replaceAll('&lt;',   '<')
      .replaceAll('&gt;',   '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;',  "'")
      .replaceAll('&nbsp;', ' ');
}
