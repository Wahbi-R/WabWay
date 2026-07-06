import 'nominatim_service.dart';
import 'oembed_service.dart';

class SocialPlaceResult {
  const SocialPlaceResult({
    required this.caption,
    required this.places,
  });
  final String              caption;
  final List<NominatimPlace> places;
}

abstract final class SocialPlaceExtractor {
  /// Fetches a TikTok/Instagram post caption and geocodes any place
  /// candidates found within it. Returns null if the post is unreachable.
  static Future<SocialPlaceResult?> extract(String url) async {
    final meta = await OembedService.fetch(url);
    if (meta == null) return null;

    final caption    = meta.title;
    final candidates = _candidates(caption);
    if (candidates.isEmpty) return SocialPlaceResult(caption: caption, places: []);

    final places = <NominatimPlace>[];
    for (final q in candidates) {
      final results = await NominatimService.search(q);
      if (results.isNotEmpty) {
        // Only add if not already found a very similar name
        final best = results.first;
        if (!places.any((p) =>
            p.name.toLowerCase() == best.name.toLowerCase())) {
          places.add(best);
        }
      }
      // Nominatim ToS: max 1 req/sec
      if (candidates.indexOf(q) < candidates.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
    }

    return SocialPlaceResult(caption: caption, places: places);
  }

  // ── Candidate extraction ──────────────────────────────────────────────────

  static List<String> _candidates(String text) {
    final found = <String>[];

    // 1. 📍 pin emoji — highest confidence
    final pinRe = RegExp(r'📍\s*([^\n#@]+)');
    for (final m in pinRe.allMatches(text)) {
      final v = m.group(1)!.trim().replaceAll(RegExp(r'[,.]$'), '');
      if (v.isNotEmpty) found.add(v);
    }

    // 2. Hashtags — strip # and CamelCase-split, skip generic travel tags
    final hashRe = RegExp(r'#(\w+)');
    for (final m in hashRe.allMatches(text)) {
      final tag = m.group(1)!;
      if (_isGenericTag(tag)) continue;
      // CamelCase → "Senso Ji Temple" style for better geocoding
      final spaced = tag.replaceAllMapped(
        RegExp(r'(?<=[a-z])(?=[A-Z])'),
        (_) => ' ',
      );
      found.add(spaced);
    }

    // Deduplicate, cap at 8 candidates
    final seen = <String>{};
    return found
        .where((s) => s.length > 3 && seen.add(s.toLowerCase()))
        .take(8)
        .toList();
  }

  static bool _isGenericTag(String tag) {
    const generic = {
      'fyp', 'foryou', 'foryoupage', 'viral', 'trending', 'explore',
      'travel', 'travelblogger', 'travelgram', 'instatravel', 'wanderlust',
      'adventure', 'vacation', 'holiday', 'trip', 'vlog', 'reels',
      'tiktok', 'instagram', 'youtube', 'shorts', 'content', 'creator',
      'photography', 'photo', 'video', 'life', 'lifestyle', 'daily',
      'love', 'beautiful', 'amazing', 'instagood', 'picoftheday',
    };
    return generic.contains(tag.toLowerCase());
  }
}
