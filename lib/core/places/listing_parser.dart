import '../../data/accommodation_data.dart';
import 'url_metadata_service.dart';

class ListingResult {
  const ListingResult({
    required this.name,
    this.city,
    this.address,
    this.pricePerNight,
    this.currency,
    this.imageUrl,
    required this.source,
    this.checkIn,
    this.checkOut,
    this.confirmationNumber,
  });

  final String name;
  final String? city;
  final String? address;
  final double? pricePerNight;
  final String? currency;
  final String? imageUrl;
  final AccommodationSource source;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String? confirmationNumber;
}

abstract final class ListingParser {
  /// Stay details from a listing / booking URL. Metadata comes from the one
  /// shared [UrlMetadataService] (server-side, schema.org-aware); this adds the
  /// stay-specific cleanup: strip "- Airbnb" suffixes, price-per-night and
  /// city heuristics when the page has no structured data.
  static Future<ListingResult?> parse(String url) async {
    try {
      final source = AccommodationSource.fromUrl(url);
      final meta = await UrlMetadataService.fetch(url);
      if (meta == null) return null;

      final rawTitle = meta.title ?? '';
      final rawDesc  = meta.description ?? '';
      final name = _cleanTitle(rawTitle, source);
      if (name.isEmpty) return null;

      final priceResult = _extractPrice(rawDesc);
      final nights = (meta.startDate != null && meta.endDate != null)
          ? meta.endDate!.difference(meta.startDate!).inDays
          : 0;
      // A structured total price is for the whole stay — convert to per night.
      final structuredPerNight = (meta.price != null && nights > 0)
          ? meta.price! / nights
          : meta.price;

      return ListingResult(
        name:               name,
        city:               meta.locality ?? _extractCity(rawTitle, rawDesc, source),
        address:            meta.address,
        pricePerNight:      structuredPerNight ?? priceResult?.$1,
        currency:           meta.price != null ? meta.currency : priceResult?.$2,
        imageUrl:           meta.image,
        source:             source,
        checkIn:            meta.startDate,
        checkOut:           meta.endDate,
        confirmationNumber: meta.confirmationNumber,
      );
    } catch (_) {
      return null;
    }
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

}
