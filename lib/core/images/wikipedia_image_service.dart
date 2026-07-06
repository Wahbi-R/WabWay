import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches a thumbnail image URL from Wikipedia for a given place name.
///
/// Returns a URL string pointing to a ~400px wide thumbnail, or null if
/// Wikipedia has no article/image for the name. The URL itself is stored
/// in the database — we never download or store the image bytes locally.
abstract final class WikipediaImageService {
  static const _ua = 'WabWay/1.1 (travel planning app)';

  /// Try to find a Wikipedia thumbnail for [query].
  /// Returns the thumbnail source URL, or null if nothing was found.
  static Future<String?> fetchThumbnailUrl(String query) async {
    if (query.trim().isEmpty) return null;

    // Try the REST summary endpoint first — fastest, returns thumbnail directly
    final summaryUrl =
        Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/'
            '${Uri.encodeComponent(query.trim())}');
    try {
      final res = await http
          .get(summaryUrl, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final thumb = (json['thumbnail'] as Map?)?.cast<String, dynamic>();
        final src = thumb?['source'] as String?;
        if (src != null) return _resizeThumbnail(src, 600);
      }
    } catch (_) {}

    // Fallback: MediaWiki action API with pageimages, in case the name
    // doesn't match the exact article title
    try {
      final apiUrl = Uri.parse('https://en.wikipedia.org/w/api.php').replace(
        queryParameters: {
          'action':       'query',
          'titles':       query.trim(),
          'prop':         'pageimages',
          'pithumbsize':  '600',
          'format':       'json',
          'redirects':    '1',
          'pilicense':    'any',
        },
      );
      final res = await http
          .get(apiUrl, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final json  = jsonDecode(res.body) as Map<String, dynamic>;
        final pages = ((json['query'] as Map?)
                ?['pages'] as Map?)
            ?.cast<String, dynamic>() ?? {};
        for (final page in pages.values) {
          final src = (page as Map?)
              ?['thumbnail']
              ?['source'] as String?;
          if (src != null) return src;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Replaces the pixel-width segment in a Wikimedia thumbnail URL so we
  /// get a differently-sized version without an extra API call.
  static String _resizeThumbnail(String url, int width) {
    return url.replaceFirstMapped(
      RegExp(r'/(\d+)px-([^/]+)$'),
      (m) => '/${width}px-${m[2]}',
    );
  }
}
